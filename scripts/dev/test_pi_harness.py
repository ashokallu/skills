"""Model-free boundary and artifact tests. No auth reads or provider calls."""
import base64
import contextlib
import fcntl
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import time
import unittest
from unittest import mock
import uuid

import pi_harness as pi


PROBE = r'''
import json, os, pathlib, resource, socket, subprocess
p = pathlib.Path
r = {}
r['host_home_absent'] = all(child.name == 'agent' for child in p('/home').glob('*'))
r['host_proc_absent'] = all(child.name == 'agent' for child in p('/proc/1/root/home').glob('*'))
r['host_sys_absent'] = not p('/sys').exists()
local = socket.socket(); local.settimeout(.2)
try: local.connect(('127.0.0.1',38117)); r['loopback_ready'] = True
except OSError: r['loopback_ready'] = False
local.close()
r['no_credentials'] = not p('/home/agent/.pi/agent/auth.json').exists() and not any(
    word in key.lower() for key in os.environ for word in ('token','secret','api_key'))
for name in ['/outside.txt', '/dev/outside.txt', '/workspace/.git/config']:
    try: p(name).write_text('BAD'); r[name] = False
    except OSError: r[name] = True
s = socket.socket(); s.settimeout(.2)
try: s.connect(('1.1.1.1',443)); r['network_blocked'] = False
except OSError: r['network_blocked'] = True
s.close()
r['userns_disabled'] = subprocess.run(['unshare','-Ur','true'],capture_output=True).returncode != 0
children=[]
try:
    for i in range(40): children.append(subprocess.Popen(['sleep','10']))
    r['process_bound'] = False
except OSError: r['process_bound'] = len(children) < 24
finally:
    for child in children: child.terminate(); child.wait()
try:
    resource.setrlimit(resource.RLIMIT_AS, (2**40,2**40)); r['memory_limit_hard'] = False
except ValueError: r['memory_limit_hard'] = True
for directory in ['/tmp','/home','/state','/dev/shm']:
    r['size_'+directory] = os.statvfs(directory).f_blocks * os.statvfs(directory).f_frsize <= 16777216
try:
    for i in range(20): p('/tmp/fill'+str(i)).write_bytes(b'x' * 1048576)
    r['disk_bound'] = False
except OSError as error: r['disk_bound'] = error.errno == 28
finally:
    for file in p('/tmp').glob('fill*'): file.unlink()
expected_version = json.loads(p('/control/config.json').read_text())['runtime']['pi_version']
r['runtime'] = subprocess.run(['/runtime/node','--disable-wasm-trap-handler',
    '--max-old-space-size=128','/runtime/pi/dist/bundle/cli.js','--offline','--no-extensions',
    '--no-skills','--no-prompt-templates','--no-themes','--no-context-files','--version'],
    capture_output=True,text=True).stdout.strip() == expected_version
native = """
import { createReadToolDefinition } from '/runtime/pi/dist/core/tools/read.js';
import { createWriteToolDefinition } from '/runtime/pi/dist/core/tools/write.js';
const checks = {};
try { await createReadToolDefinition('/workspace').execute('public', {path:'../outside.txt'});
  checks.native_read = false; } catch { checks.native_read = true; }
try { await createWriteToolDefinition('/workspace').execute('public', {path:'../outside.txt',content:'BAD'});
  checks.native_write = false; } catch { checks.native_write = true; }
console.log(JSON.stringify(checks));
"""
nr = subprocess.run(['/runtime/node','--disable-wasm-trap-handler','--max-old-space-size=128',
    '--input-type=module','-e',native],capture_output=True,text=True)
r['native_tools'] = nr.returncode == 0 and all(json.loads(nr.stdout).values())
p('/workspace/fixture.txt').read_text()
try: p('/workspace/fixture.txt').write_text('after\n'); r['writable'] = True
except OSError: r['writable'] = False
print(json.dumps(r))
'''


class PiHarnessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.policy = json.loads(pi.POLICY_PATH.read_text())
        cls.runtime, cls.node = pi.resolve_pi_install()
        cls.identity = pi.runtime_identity(cls.runtime, cls.node)
        cls.temp_root = pi.HERE.parents[1] / 'tmp/pi-deterministic'
        cls.temp_root.mkdir(parents=True, exist_ok=True)

    def test_installed_runtime_capabilities(self):
        pi.runtime_capabilities(self.runtime, self.node)
        self.assertEqual(pi.runtime_identity(self.runtime, self.node), self.identity)

    def test_new_versions_are_measured_without_repins_and_mutations_change_identity(self):
        with tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
            runtime = Path(folder) / 'runtime'
            runtime.mkdir()
            node = Path(folder) / 'node'
            node.write_bytes(b'synthetic-node')
            (runtime / 'package.json').write_text(json.dumps({'version': '99.1.0'}))
            before = pi.runtime_identity(runtime, node)
            self.assertEqual(before['pi_version'], '99.1.0')
            (runtime / 'package.json').write_text(json.dumps({'version': '100.0.0'}))
            upgraded = pi.runtime_identity(runtime, node)
            self.assertEqual(upgraded['pi_version'], '100.0.0')
            self.assertNotEqual(upgraded, before)
            node.write_bytes(b'changed-node')
            self.assertNotEqual(pi.runtime_identity(runtime, node), upgraded)
            (runtime / 'escape').symlink_to(node)
            with self.assertRaisesRegex(ValueError, 'symlink escapes'):
                pi.runtime_identity(runtime, node)

    def test_missing_cli_capabilities_fail_before_model_execution(self):
        with mock.patch.object(pi, 'bounded_process', return_value=(0, {'stdout': b'--session-id-extra'})):
            with self.assertRaisesRegex(ValueError, 'lacks required capability'):
                pi.runtime_capabilities(self.runtime, self.node)

    def test_paths(self):
        for name in ('../outside', '/home/sandbox-agent', 'a/../../outside', '.git/config',
                     '.env', 'a/credentials.json', 'a\\b', 'a\nb', 'a//b'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                pi.safe_path(name)

    def test_prompt_rejects_secret_paths_symlinks_and_external_files(self):
        with tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
            root = Path(folder)
            prompt = root / 'prompt.txt'
            prompt.write_text('public prompt')
            self.assertEqual(pi.read_prompt(prompt, [root], self.policy), b'public prompt')
            (root / 'link.txt').symlink_to(prompt)
            (root / '.env').write_text('public secret-path canary')
            for path in (root / 'link.txt', root / '.env', root.parent / 'outside.txt'):
                with self.subTest(path=path), self.assertRaises(ValueError):
                    pi.read_prompt(path, [root], self.policy)

    def test_patch_exact_authority(self):
        result = {'exit_code': 0, 'files': {'fixture.txt': base64.b64encode(b'after\n').decode()}}
        with self.assertRaises(ValueError):
            pi.extract(result, {'fixture.txt': b'before\n'}, [], self.policy)
        patch, paths = pi.extract(result, {'fixture.txt': b'before\n'}, ['fixture.txt'], self.policy)
        self.assertEqual(paths, ['fixture.txt'])
        self.assertIn('-before\n+after\n', patch)
        result['files']['../outside'] = ''
        with self.assertRaises(ValueError):
            pi.extract(result, {}, ['../outside'], self.policy)
        patch, _ = pi.extract({'exit_code': 0, 'files': {'empty': ''}}, {}, ['empty'], self.policy)
        self.assertIn('new file mode 100644\n', patch)
        patch, _ = pi.extract({'exit_code': 0, 'files': {}}, {'empty': b''}, ['empty'], self.policy)
        self.assertIn('deleted file mode 100644\n', patch)

    def test_snapshot_rejects_file_and_component_swaps(self):
        for component in (False, True):
            with self.subTest(component=component), tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
                root = Path(folder)
                (root / 'selected').mkdir()
                (root / 'outside').mkdir()
                (root / 'selected/file.txt').write_text('selected')
                (root / 'outside/file.txt').write_text('outside canary')
                original = os.open
                swapped = False
                def swapping_open(path, flags, *args, **kwargs):
                    nonlocal swapped
                    if path == ('selected' if component else 'file.txt') and kwargs.get('dir_fd') is not None and not swapped:
                        swapped = True
                        if component:
                            (root / 'selected').rename(root / 'saved')
                            (root / 'selected').symlink_to(root / 'outside', target_is_directory=True)
                        else:
                            (root / 'selected/file.txt').unlink()
                            (root / 'selected/file.txt').symlink_to(root / 'outside/file.txt')
                    return original(path, flags, *args, **kwargs)
                with mock.patch.object(pi.os, 'open', side_effect=swapping_open), self.assertRaises(ValueError):
                    pi.snapshot(root, ['selected/file.txt'], self.policy)
                self.assertTrue(swapped)

    def test_snapshot_rejects_content_and_head_drift(self):
        with tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
            root = Path(folder)
            (root / 'first.txt').write_text('before')
            (root / 'second.txt').write_text('second')
            original = pi.read_selected
            reads = 0
            def mutate_after_read(fd, limit):
                nonlocal reads
                data = original(fd, limit)
                reads += 1
                if reads == 2:
                    (root / 'first.txt').write_text('changed')
                return data
            with mock.patch.object(pi, 'read_selected', side_effect=mutate_after_read), self.assertRaisesRegex(ValueError, 'selected source changed'):
                pi.snapshot(root, ['first.txt', 'second.txt'], self.policy)
            with mock.patch.object(pi, 'git', side_effect=[b'head-before', b'head-after']), self.assertRaisesRegex(ValueError, 'HEAD changed'):
                pi.snapshot(root, ['first.txt'], self.policy)

    def test_existing_write_requires_read_baseline_but_new_path_is_allowed(self):
        with tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
            root = Path(folder)
            (root / 'read.txt').write_text('read\n')
            (root / 'existing.txt').write_text('existing\n')
            with self.assertRaisesRegex(ValueError, 'existing --write-path'):
                pi.snapshot(root, ['read.txt'], self.policy, ['existing.txt'])
            before = pi.snapshot(root, ['read.txt'], self.policy, ['new/file.txt'])
            self.assertNotIn('new/file.txt', before)
            result = {'exit_code': 0, 'files': {name: base64.b64encode(data).decode() for name, data in before.items()}}
            result['files']['new/file.txt'] = base64.b64encode(b'new\n').decode()
            patch, changed = pi.extract(result, before, ['new/file.txt'], self.policy)
            self.assertEqual(changed, ['new/file.txt'])
            self.assertIn('new file mode 100644', patch)

    def test_final_text_rejects_blank_but_allows_intermediate_tool_response(self):
        session_id = str(uuid.uuid4())
        session = base64.b64encode(json.dumps({'type': 'session', 'id': session_id, 'cwd': '/workspace'}).encode()).decode()
        for text in ('', ' \t\n', 'finished'):
            with self.subTest(text=text):
                events = [{'type': 'message_end', 'message': {'role': 'assistant', 'stopReason': 'toolUse', 'content': []}},
                          {'type': 'message_end', 'message': {'role': 'assistant', 'stopReason': 'stop', 'content': [{'type': 'text', 'text': text}]}}]
                result = {'stdout': '\n'.join(map(json.dumps, events)), 'sessions': {'session.jsonl': session}}
                audit = {'status': 'ready', 'attempts': [{'text_sha256': pi.sha(text.encode())}]}
                if text.strip():
                    self.assertEqual(pi.validate_terminal(result, audit, session_id)[0], text)
                else:
                    with self.assertRaisesRegex(ValueError, 'empty or whitespace'):
                        pi.validate_terminal(result, audit, session_id)

    def test_real_namespaces_both_roles(self):
        for role in ('reviewer', 'contributor'):
            with self.subTest(role=role), tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
                attempt = Path(folder)
                for name in ('control', 'source', 'broker', 'empty-git'):
                    (attempt / name).mkdir()
                if role != 'contributor':
                    (attempt / 'source/.git').mkdir()
                (attempt / 'source/fixture.txt').write_text('before\n')
                (attempt / 'control/prompt').write_text('public fixture')
                (attempt / 'control/probe.py').write_text(PROBE)
                shutil.copyfile(pi.HERE / 'pi-sandbox.py', attempt / 'control/pi-sandbox.py')
                config = {'model': 'gpt-5.6-luna', 'role': role, 'policy': self.policy,
                          'runtime': self.identity, 'probe': True}
                pi.write_json(attempt / 'control/config.json', config)
                code, output = pi.bounded_process(pi.sandbox_command(attempt, self.runtime, self.node, config),
                                                  30, self.policy['max_output_bytes'])
                self.assertEqual(code, 0, output)
                result = json.loads(output['stdout'])
                self.assertEqual(result['exit_code'], 0, result)
                checks = json.loads(result['stdout'])
                self.assertEqual(checks.pop('writable'), role == 'contributor')
                self.assertTrue(all(checks.values()), checks)
                self.assertEqual((attempt / 'source/fixture.txt').read_text(), 'before\n')
                self.assertEqual(result['sessions'], {})

    def test_real_pi_fake_provider_and_continuation(self):
        for role in ('reviewer', 'contributor'):
            with self.subTest(role=role), tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
                attempt = Path(folder)
                for name in ('control', 'source', 'broker', 'empty-git'):
                    (attempt / name).mkdir()
                if role != 'contributor':
                    (attempt / 'source/.git').mkdir()
                (attempt / 'source/fixture.txt').write_text('before\n')
                (attempt / 'control/prompt').write_text('Use the fixture, then return public-result.')
                for name in ('pi-sandbox.py', 'pi-provider.ts'):
                    shutil.copyfile(pi.HERE / name, attempt / 'control' / name)
                config = {'model': 'gpt-5.6-luna', 'effort': 'medium', 'provider_effort': 'medium',
                          'role': role, 'policy': self.policy,
                          'session_id': str(uuid.uuid4())}
                pi.write_json(attempt / 'control/config.json', config)
                broker_config = {**self.policy, **config, 'socket': 'broker/socket',
                                 'audit': str(attempt / 'audit.json')}
                pi.write_json(attempt / 'broker-config.json', broker_config)
                broker = subprocess.Popen([str(self.node), str(pi.HERE / 'pi-fake-broker-fixture.mjs'),
                                           str(attempt / 'broker-config.json')], cwd=attempt,
                                          stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                try:
                    for _ in range(100):
                        if (attempt / 'broker/socket').exists():
                            break
                        if broker.poll() is not None:
                            self.fail(broker.stderr.read().decode())
                        time.sleep(.02)
                    for resume in (False, True):
                        code, output = pi.bounded_process(
                            pi.sandbox_command(attempt, self.runtime, self.node, config),
                            30, self.policy['max_output_bytes'])
                        self.assertEqual(code, 0, output)
                        result = json.loads(output['stdout'])
                        audit = json.loads((attempt / 'audit.json').read_text())
                        self.assertTrue(audit.get('attempts'), {'audit': audit,
                            'result': {k: v for k, v in result.items() if k != 'sessions'}})
                        text, session = pi.validate_terminal(result, audit, config['session_id'])
                        self.assertEqual(text, 'public-result')
                        patch, changed = pi.extract(result, {'fixture.txt': b'before\n'},
                                                    ['fixture.txt'] if role == 'contributor' else [], self.policy)
                        if role == 'contributor' and not resume:
                            self.assertEqual(changed, ['fixture.txt'])
                            self.assertIn('+after', patch)
                        (attempt / 'control/session.jsonl').write_bytes(session)
                    self.assertEqual(audit['requests'], 3)
                    self.assertEqual(audit['total_tokens'], 9)
                finally:
                    broker.terminate()
                    broker.wait(timeout=5)
                    broker.stderr.close()

    def test_controller_lifecycle_and_exact_resume(self):
        source = pi.HERE.parents[1]
        original_popen = subprocess.Popen
        for role in ('reviewer', 'contributor'):
            with self.subTest(role=role), tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
                folder = Path(folder)
                selected_source = source
                fixture_root = folder
                if role == 'contributor':
                    repository = folder / 'repository'
                    selected_source = folder / 'worktree'
                    repository.mkdir()
                    subprocess.run(['git', 'init', '-q', str(repository)], check=True)
                    (repository / '.gitignore').write_text('tmp/\n')
                    subprocess.run(['git', '-C', str(repository), 'add', '.gitignore'], check=True)
                    subprocess.run([
                        'git', '-C', str(repository), '-c', 'core.hooksPath=/dev/null',
                        '-c', 'user.name=Pi Harness Tests',
                        '-c', 'user.email=pi-harness-tests@example.invalid',
                        'commit', '-qm', 'fixture'], check=True)
                    subprocess.run([
                        'git', '-C', str(repository), 'worktree', 'add', '--detach', '--quiet',
                        str(selected_source), 'HEAD'], check=True)
                    fixture_root = selected_source / 'tmp/pi-deterministic'
                    fixture_root.mkdir(parents=True)
                root = selected_source / 'tmp/pi-harness'
                session_id = uuid.uuid4()
                session_root = root / str(session_id)
                fixture = fixture_root / 'fixture.txt'
                fixture.write_text('before\n')
                prompt = fixture_root / 'prompt.txt'
                prompt.write_text('Use the public fixture then return public-result.')
                relative = fixture.relative_to(selected_source).as_posix()
                def launch(command, *args, **kwargs):
                    if len(command) > 1 and command[1] == str(pi.HERE / 'pi-broker.mjs'):
                        config_path = Path(command[2])
                        config = json.loads(config_path.read_text())
                        config['fixture_path'] = relative
                        pi.write_json(config_path, config)
                        command = [command[0], str(pi.HERE / 'pi-fake-broker-fixture.mjs'), command[2]]
                    return original_popen(command, *args, **kwargs)
                argv = ['pi-harness', '--model', 'gpt-6.1-sol', '--effort', 'medium', '--role', role,
                        '--prompt-file', str(prompt), '--read-path', relative]
                if role == 'contributor':
                    argv += ['--allow-write', '--worktree-existing', str(selected_source),
                             '--write-path', relative]
                with mock.patch.object(pi.subprocess, 'Popen', side_effect=launch), \
                        mock.patch.object(pi.uuid, 'uuid4', return_value=session_id), \
                        contextlib.redirect_stdout(io.StringIO()):
                    try:
                        with mock.patch('sys.argv', argv):
                            pi.main()
                        resume_argv = argv + ['--resume', session_root.name]
                        state_path = session_root / 'state.json'
                        initial = json.loads(state_path.read_text())
                        self.assertEqual(initial['status'], 'success')
                        self.assertEqual(initial['requests'], 2)
                        with open(session_root / 'lock', 'a') as held:
                            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
                            with mock.patch('sys.argv', resume_argv), self.assertRaises(BlockingIOError):
                                pi.main()
                        self.assertEqual(json.loads(state_path.read_text()), initial)
                        session_file = session_root / 'session.jsonl'
                        original = session_file.read_bytes()
                        session_file.write_bytes(original + b'\n')
                        with mock.patch('sys.argv', resume_argv), self.assertRaises(ValueError):
                            pi.main()
                        session_file.write_bytes(original)
                        with mock.patch('sys.argv', resume_argv):
                            pi.main()
                        resumed = json.loads(state_path.read_text())
                        self.assertEqual(resumed['status'], 'success')
                        self.assertEqual(resumed['requests'], 4)
                        self.assertEqual(resumed['total_tokens'], 12)
                        self.assertEqual(fixture.read_text(), 'before\n')
                        if role == 'contributor':
                            self.assertIn('+after', (session_root / 'attempt-2/changes.patch').read_text())
                        with mock.patch('sys.argv', resume_argv), self.assertRaises(ValueError):
                            pi.main()
                        failed = json.loads(state_path.read_text())
                        self.assertEqual(failed['status'], 'failed')
                        self.assertFalse(failed['resumable'])
                        with mock.patch('sys.argv', resume_argv), self.assertRaises(ValueError):
                            pi.main()
                    finally:
                        if session_root.exists():
                            shutil.rmtree(session_root)

    def test_timeout_reaps_detached_namespace_children(self):
        with tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
            attempt = Path(folder)
            for name in ('control', 'source', 'broker', 'empty-git'):
                (attempt / name).mkdir()
            (attempt / 'control/prompt').write_text('public timeout fixture')
            (attempt / 'control/probe.py').write_text(
                'import subprocess,time\nsubprocess.Popen(["sleep","30"],start_new_session=True)\ntime.sleep(30)\n')
            shutil.copyfile(pi.HERE / 'pi-sandbox.py', attempt / 'control/pi-sandbox.py')
            config = {'model': 'gpt-5.6-luna', 'role': 'contributor', 'policy': self.policy, 'probe': True}
            pi.write_json(attempt / 'control/config.json', config)
            launched = []
            original = subprocess.Popen
            def launch(*args, **kwargs):
                process = original(*args, **kwargs)
                launched.append(process.pid)
                return process
            errors = []
            def run():
                try:
                    pi.bounded_process(pi.sandbox_command(attempt, self.runtime, self.node, config), 2, 1048576)
                except ValueError as error:
                    errors.append(str(error))
            with mock.patch.object(pi.subprocess, 'Popen', side_effect=launch):
                worker = threading.Thread(target=run)
                worker.start()
                descendants = set()
                for _ in range(40):
                    if launched:
                        pending = [launched[0]]
                        while pending:
                            pid = pending.pop()
                            try:
                                children = Path(f'/proc/{pid}/task/{pid}/children').read_text().split()
                            except FileNotFoundError:
                                continue
                            for child in map(int, children):
                                descendants.add(child)
                                pending.append(child)
                    if len(descendants) >= 5:
                        break
                    time.sleep(.025)
                worker.join(timeout=5)
            self.assertFalse(worker.is_alive())
            self.assertEqual(errors, ['outer timeout'])
            self.assertGreaterEqual(len(descendants), 5)
            for pid in descendants:
                path = Path(f'/proc/{pid}/stat')
                if path.exists():
                    self.assertEqual(path.read_text().split()[2], 'Z', f'owned child {pid} still running')

    def test_inner_timeout_preserves_partial_child_output(self):
        with tempfile.TemporaryDirectory(dir=self.temp_root) as folder:
            attempt = Path(folder)
            for name in ('control', 'source', 'broker', 'empty-git'):
                (attempt / name).mkdir()
            (attempt / 'control/prompt').write_text('public timeout fixture')
            (attempt / 'control/probe.py').write_text(
                'import time\nprint("partial-timeout-evidence", flush=True)\ntime.sleep(30)\n')
            shutil.copyfile(pi.HERE / 'pi-sandbox.py', attempt / 'control/pi-sandbox.py')
            policy = {**self.policy, 'timeout_sec': 1}
            config = {'model': 'gpt-5.6-luna', 'role': 'contributor',
                      'policy': policy, 'probe': True}
            pi.write_json(attempt / 'control/config.json', config)

            code, output = pi.bounded_process(
                pi.sandbox_command(attempt, self.runtime, self.node, config), 4, 1048576)
            self.assertEqual(code, 0)
            result = json.loads(output['stdout'])
            self.assertEqual(result['exit_code'], 124)
            self.assertIn('partial-timeout-evidence', result['stdout'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
