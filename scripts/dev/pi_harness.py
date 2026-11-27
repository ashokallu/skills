"""Opt-in Pi candidate: private snapshots, credential broker, bounded patch return."""
import argparse
import base64
import contextlib
import ctypes
import difflib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import selectors
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import time
import uuid

HERE = Path(__file__).resolve().parent
POLICY_PATH = HERE / 'pi-harness-policy.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    temporary = path.with_suffix('.new')
    with open(temporary, 'w') as output:
        output.write(json.dumps(value, indent=2) + '\n')
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, path)
    directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


def parent_death_signal():
    if ctypes.CDLL(None, use_errno=True).prctl(1, signal.SIGKILL, 0, 0, 0) != 0:
        os._exit(1)
    if os.getppid() == 1:
        os._exit(1)


def safe_path(name):
    path = PurePosixPath(name)
    parts = path.parts
    if not parts or path.is_absolute() or path.as_posix() != name or any(
            part in ('..', '.', '.git', '.pi', '.ssh', '.aws', '.netrc', '.npmrc', 'auth.json') or part.startswith('.env') or
            any(word in part.lower() for word in ('credential', 'secret', 'token', 'cookie')) or
            part.lower().endswith(('.pem', '.key', '.p12', '.pfx')) for part in parts):
        raise ValueError('unsafe snapshot path')
    if any(ord(char) < 32 or char in '\\' for char in name):
        raise ValueError('unsafe path characters')
    return path


def git(source, *args):
    return subprocess.check_output(['git', '-C', str(source), *args], stderr=subprocess.DEVNULL)


def open_beneath(root_fd, name, directory=False):
    """Walk every component without following links; the caller owns the result."""
    current = os.dup(root_fd)
    try:
        parts = PurePosixPath(name).parts
        for index, part in enumerate(parts):
            flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
            if directory or index < len(parts) - 1:
                flags |= os.O_DIRECTORY
            child = os.open(part, flags, dir_fd=current)
            os.close(current)
            current = child
        return current
    except BaseException:
        os.close(current)
        raise


def file_identity(info):
    return (info.st_dev, info.st_ino, info.st_mode, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def read_selected(fd, limit):
    os.lseek(fd, 0, os.SEEK_SET)
    chunks = []
    size = 0
    while chunk := os.read(fd, min(65536, limit + 1 - size)):
        size += len(chunk)
        if size > limit:
            raise ValueError('snapshot file too large')
        chunks.append(chunk)
    return b''.join(chunks)


def snapshot(source, names, policy, write_paths=()):
    head = git(source, 'rev-parse', 'HEAD')
    if not names:
        names = git(source, 'ls-files', '-z').decode().rstrip('\0').split('\0')
    names = list(dict.fromkeys(names))
    for name in (*names, *write_paths):
        safe_path(name)
    if len(names) > policy['max_files']:
        raise ValueError('snapshot too large; select a smaller --read-path surface')
    try:
        with contextlib.ExitStack() as stack:
            def owned(fd):
                stack.callback(os.close, fd)
                return fd
            anchor = owned(os.open('/', os.O_RDONLY | os.O_DIRECTORY))
            root = owned(open_beneath(anchor, str(source.absolute()).lstrip('/'), directory=True))
            root_identity = file_identity(os.fstat(root))[:2]
            opened = {}
            absent = []
            total = 0
            # Capture all identities before reading any content, so earlier files
            # cannot silently drift while later files are copied.
            for name in dict.fromkeys((*names, *write_paths)):
                try:
                    fd = owned(open_beneath(root, name))
                except FileNotFoundError:
                    if name in names:
                        raise
                    absent.append(name)
                    continue
                if name not in names:
                    raise ValueError('existing --write-path must also be selected by --read-path')
                info = os.fstat(fd)
                if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o7000:
                    raise ValueError('snapshot special file or mode')
                total += info.st_size
                if info.st_size > policy['max_file_bytes'] or total > policy['max_snapshot_bytes']:
                    raise ValueError('snapshot too large; select a smaller --read-path surface')
                opened[name] = (fd, file_identity(info))
            result = {name: read_selected(fd, policy['max_file_bytes']) for name, (fd, _) in opened.items()}
            fresh_root = owned(open_beneath(anchor, str(source.absolute()).lstrip('/'), directory=True))
            if file_identity(os.fstat(fresh_root))[:2] != root_identity:
                raise ValueError('snapshot source directory changed')
            for name, (fd, initial) in opened.items():
                fresh = owned(open_beneath(fresh_root, name))
                if (file_identity(os.fstat(fd)) != initial or file_identity(os.fstat(fresh)) != initial or
                        read_selected(fresh, policy['max_file_bytes']) != result[name] or
                        file_identity(os.fstat(fresh)) != initial):
                    raise ValueError('selected source changed during snapshot')
            for name in absent:
                try:
                    owned(open_beneath(fresh_root, name))
                except FileNotFoundError:
                    continue
                raise ValueError('new write path appeared during snapshot')
            if git(source, 'rev-parse', 'HEAD') != head:
                raise ValueError('HEAD changed during snapshot')
            if any(file_identity(os.fstat(fd)) != initial for fd, initial in opened.values()):
                raise ValueError('selected source changed during snapshot')
            return result
    except OSError as error:
        raise ValueError('snapshot path changed or is not a safe regular file') from error


def read_prompt(path, roots, policy):
    absolute = path.absolute()
    for root in roots:
        if absolute.is_relative_to(root):
            name = absolute.relative_to(root).as_posix()
            data = snapshot(root, [name], {**policy, 'max_file_bytes': 32768})[name]
            if not data:
                raise ValueError('empty prompt')
            return data
    raise ValueError('prompt must be a non-secret regular file in the caller or selected repository')



def resolve_pi_install(command=None):
    selected_text = command or os.environ.get('AGENT_CALL_PI_BIN') or shutil.which('pi')
    if not selected_text:
        raise ValueError('Pi CLI not found on PATH')
    selected = Path(selected_text).absolute()
    selected.resolve(strict=True)
    launch_path = selected
    resolved = selected.resolve(strict=True)

    if resolved.name != 'cli.js':
        try:
            wrapper_text = selected.read_text()
        except (OSError, UnicodeError) as exc:
            raise ValueError('Pi launcher is neither the bundled CLI nor a readable wrapper') from exc
        if len(wrapper_text.encode()) > 16384:
            raise ValueError('Pi launcher wrapper is unexpectedly large')
        targets = []
        for line in wrapper_text.splitlines():
            if not line.startswith('exec '):
                continue
            try:
                words = shlex.split(line)
            except ValueError:
                continue
            if '--' in words:
                index = words.index('--')
                if index + 1 < len(words):
                    # The host checklist's two-line launcher names its target
                    # through ~ or $HOME; both still denote one exact path.
                    candidate = Path(os.path.expandvars(os.path.expanduser(words[index + 1])))
                    if candidate.is_absolute() and candidate.name == 'pi':
                        targets.append(candidate)
        unique_targets = {path.resolve(strict=True): path for path in targets}
        if len(unique_targets) != 1:
            raise ValueError('Pi launcher wrapper must contain one exact absolute Pi target')
        resolved, launch_path = next(iter(unique_targets.items()))

    if resolved.name != 'cli.js' or resolved.parts[-3:] != ('dist', 'bundle', 'cli.js'):
        raise ValueError('Pi launcher does not resolve to the bundled CLI')
    runtime = next((parent for parent in resolved.parents if (parent / 'package.json').is_file()), None)
    if runtime is None:
        raise ValueError('Pi package root could not be resolved')

    node_override = os.environ.get('AGENT_CALL_PI_NODE')
    if node_override:
        node = Path(node_override).resolve(strict=True)
    else:
        candidates = [launch_path.parent / 'node']
        candidates.extend(parent / 'bin/node' for parent in resolved.parents)
        node = next((candidate.resolve(strict=True) for candidate in candidates
                     if candidate.is_file() and os.access(candidate, os.X_OK)), None)
        if node is None:
            raise ValueError('Pi companion Node binary could not be resolved')
    return runtime, node

def runtime_identity(runtime, node):
    metadata = json.loads((runtime / 'package.json').read_text())
    version = metadata.get('version')
    if not isinstance(version, str) or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?', version):
        raise ValueError('Pi runtime version is malformed')
    digest = hashlib.sha256()
    for path in sorted(runtime.rglob('*')):
        name = path.relative_to(runtime).as_posix()
        if path.is_symlink():
            if not path.resolve().is_relative_to(runtime):
                raise ValueError('runtime symlink escapes package')
            digest.update(f'link:{name}:{path.readlink()}\n'.encode())
        elif path.is_file():
            digest.update(f'{name}\0{sha(path.read_bytes())}\n'.encode())
    return {'pi_version': version, 'runtime_sha256': digest.hexdigest(),
            'node_sha256': sha(node.read_bytes())}


def runtime_capabilities(runtime, node):
    # Help runs with no host home, credentials, extensions, or outward network.
    # A new CLI is eligible by behavior rather than a checked-in release hash.
    command = ['bwrap', '--die-with-parent', '--new-session', '--unshare-net', '--unshare-pid',
               '--unshare-uts', '--unshare-ipc', '--ro-bind', '/usr', '/usr',
               '--symlink', 'usr/bin', '/bin', '--symlink', 'usr/lib', '/lib',
               '--symlink', 'usr/lib64', '/lib64', '--proc', '/proc', '--dev', '/dev',
               '--ro-bind', str(runtime), '/runtime/pi', '--ro-bind', str(node), '/runtime/node',
               '--tmpfs', '/tmp', '--chdir', '/tmp', '--clearenv',
               '--setenv', 'PATH', '/runtime:/usr/bin:/bin', '--setenv', 'HOME', '/tmp/pi-home',
               '--setenv', 'PI_OFFLINE', '1', '--setenv', 'PI_TELEMETRY', '0',
               '/runtime/node', '--disable-wasm-trap-handler', '--max-old-space-size=128',
               '/runtime/pi/dist/bundle/cli.js', '--offline', '--no-extensions', '--no-skills',
               '--no-prompt-templates', '--no-themes', '--no-context-files', '--no-approve', '--help']
    code, output = bounded_process(command, 10, 65536)
    if code:
        raise ValueError('Pi CLI capability probe failed')
    help_text = output['stdout'].decode('utf-8')
    for capability in ('--offline', '--no-extensions', '--no-skills', '--no-prompt-templates',
                       '--no-themes', '--no-context-files', '--no-approve', '--extension',
                       '--provider', '--model', '--thinking', '--mode', '--session-dir',
                       '--tools', '--print', '--session', '--session-id'):
        if not re.search(r'(^|[\s,])' + re.escape(capability) + r'([\s,=<]|$)', help_text, re.M):
            raise ValueError(f'Pi CLI lacks required capability: {capability}')


def sandbox_command(attempt, runtime, node, config):
    policy = config['policy']
    command = ['bwrap', '--die-with-parent', '--new-session', '--unshare-user', '--disable-userns',
               '--uid', str(os.getuid()), '--gid', str(os.getgid()), '--unshare-pid', '--unshare-net',
               '--unshare-uts', '--unshare-ipc', '--cap-drop', 'ALL',
               '--ro-bind', '/usr', '/usr', '--symlink', 'usr/bin', '/bin',
               '--symlink', 'usr/lib', '/lib', '--symlink', 'usr/lib64', '/lib64',
               '--proc', '/proc', '--dev', '/dev', '--size', str(policy['scratch_bytes']),
               '--tmpfs', '/dev/shm', '--remount-ro', '/dev',
               '--ro-bind', str(attempt / 'control'), '/control',
               '--ro-bind', str(attempt / 'source'), '/source',
               '--ro-bind', str(runtime), '/runtime/pi', '--ro-bind', str(node), '/runtime/node',
               '--ro-bind', str(attempt / 'broker'), '/broker']
    for target in ('/tmp', '/home', '/state'):
        command += ['--size', str(policy['scratch_bytes']), '--tmpfs', target]
    if config['role'] == 'contributor':
        command += ['--size', str(policy['workspace_bytes']), '--tmpfs', '/workspace']
    else:
        command += ['--ro-bind', str(attempt / 'source'), '/workspace']
    command += ['--ro-bind', str(attempt / 'empty-git'), '/workspace/.git',
                '--remount-ro', '/', '--clearenv', '--setenv', 'PATH', '/runtime:/usr/bin:/bin',
                '--setenv', 'HOME', '/home/agent', '--setenv', 'PI_OFFLINE', '1',
                '--setenv', 'PI_TELEMETRY', '0', '--setenv', 'PI_HARNESS_MODEL', config['model'],
                '--setenv', 'MALLOC_ARENA_MAX', '2', '--setenv', 'UV_THREADPOOL_SIZE', '2',
                '--setenv', 'LANG', 'C.UTF-8', '--chdir', '/workspace',
                '/usr/bin/python3', '/control/pi-sandbox.py']
    return command


def bounded_process(command, timeout, limit, cleanup_receipt=None):
    # Adopt sandbox orphans so timeout does not leave reaping to host init.
    if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
        raise ValueError('subreaper unavailable')
    def children(pid):
        result = set()
        for path in Path(f'/proc/{pid}/task').glob('*/children'):
            try:
                result.update(map(int, path.read_text().split()))
            except FileNotFoundError:
                pass
        return result
    def identity(pid):
        try:
            return Path(f'/proc/{pid}/stat').read_text().rpartition(')')[2].split()[19]
        except OSError:
            return None
    baseline = children(os.getpid())
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               env={'PATH': '/usr/bin:/bin'}, start_new_session=True)
    owned = {process.pid: identity(process.pid)}
    def collect():
        pending = [process.pid, *(children(os.getpid()) - baseline)]
        seen = set()
        while pending:
            pid = pending.pop()
            if pid in seen:
                continue
            seen.add(pid)
            stamp = identity(pid)
            if stamp is not None:
                owned.setdefault(pid, stamp)
                pending.extend(children(pid))
    streams = selectors.DefaultSelector()
    streams.register(process.stdout, selectors.EVENT_READ, 'stdout')
    streams.register(process.stderr, selectors.EVENT_READ, 'stderr')
    output = {'stdout': bytearray(), 'stderr': bytearray()}
    deadline = time.monotonic() + timeout
    try:
        while streams.get_map():
            collect()
            if time.monotonic() >= deadline:
                raise ValueError('outer timeout')
            for key, _ in streams.select(.1):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if not chunk:
                    streams.unregister(key.fileobj)
                    continue
                output[key.data].extend(chunk)
                if sum(map(len, output.values())) > limit:
                    raise ValueError('outer output limit')
        return process.wait(timeout=2), {key: bytes(value) for key, value in output.items()}
    finally:
        collect()
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        process.wait()
        deadline = time.monotonic() + 5
        while True:
            collect()
            remaining = []
            for pid, stamp in owned.items():
                if pid == process.pid or identity(pid) != stamp:
                    continue
                try:
                    os.kill(pid, signal.SIGKILL)
                    os.waitpid(pid, os.WNOHANG)
                except (ChildProcessError, ProcessLookupError):
                    pass
                if identity(pid) == stamp:
                    remaining.append(pid)
            if not remaining:
                break
            if time.monotonic() >= deadline:
                raise ValueError('owned sandbox descendants not reaped')
            time.sleep(.01)
        streams.close()
        process.stdout.close()
        process.stderr.close()
        if cleanup_receipt is not None:
            cleanup_receipt.update(status='complete', owned_processes_reaped=len(owned))


def extract(result, before, writes, policy):
    if result.get('exit_code') != 0:
        raise ValueError('Pi returned a failed exit')
    after = {}
    for name, encoded in result['files'].items():
        safe_path(name)
        data = base64.b64decode(encoded, validate=True)
        if len(data) > policy['max_file_bytes']:
            raise ValueError('returned file too large')
        after[name] = data
    if len(after) > policy['max_files'] or sum(map(len, after.values())) > policy['max_snapshot_bytes']:
        raise ValueError('returned snapshot too large')
    changed = sorted(name for name in before.keys() | after.keys() if before.get(name) != after.get(name))
    if any(name not in writes for name in changed):
        raise ValueError('write outside exact allowlist')
    patch = []
    for name in changed:
        old = before.get(name, b'').decode('utf-8')
        new = after.get(name, b'').decode('utf-8')
        if '\0' in old + new or (old and not old.endswith('\n')) or (new and not new.endswith('\n')):
            raise ValueError('patch requires newline-terminated text')
        old_name = json.dumps(f'a/{name}', ensure_ascii=False)
        new_name = json.dumps(f'b/{name}', ensure_ascii=False)
        patch.append(f'diff --git {old_name} {new_name}\n')
        if name not in before:
            patch.append('new file mode 100644\n')
        elif name not in after:
            patch.append('deleted file mode 100644\n')
        patch.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
                     fromfile=old_name if name in before else '/dev/null',
                     tofile=new_name if name in after else '/dev/null'))
    return ''.join(patch), changed


def validate_terminal(result, audit, session_id):
    if audit.get('status') != 'ready' or not audit.get('attempts'):
        raise ValueError('broker did not complete')
    events = [json.loads(line) for line in result['stdout'].splitlines() if line.strip()]
    messages = [event['message'] for event in events if event.get('type') == 'message_end'
                and event.get('message', {}).get('role') == 'assistant']
    if not messages or any(message.get('stopReason') in ('error', 'aborted', 'pending') for message in messages):
        raise ValueError('Pi lifecycle failed')
    final = messages[-1]
    if final.get('stopReason') != 'stop':
        raise ValueError('Pi has no successful final response')
    text = ''.join(block['text'] for block in final['content'] if block.get('type') == 'text')
    if not text.strip():
        raise ValueError('Pi final response is empty or whitespace')
    if sha(text.encode()) != audit['attempts'][-1]['text_sha256']:
        raise ValueError('Pi text differs from broker response')
    if len(result['sessions']) != 1:
        raise ValueError('ambiguous session')
    session = base64.b64decode(next(iter(result['sessions'].values())), validate=True)
    if len(session) > 2 * 1024 * 1024:
        raise ValueError('session too large')
    header = json.loads(session.splitlines()[0])
    if header.get('type') != 'session' or header.get('id') != session_id or header.get('cwd') != '/workspace':
        raise ValueError('session identity mismatch')
    return text, session


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model')
    parser.add_argument('--check', action='store_true', help='Check the installed CLI without a model call')
    parser.add_argument('--effort', choices=('minimal', 'low', 'medium', 'high', 'xhigh', 'max'),
                        default='minimal', help='Pi thinking effort; minimal maps to provider low')
    parser.add_argument('--role', choices=('reviewer', 'critic', 'contributor'), default='reviewer')
    parser.add_argument('--prompt-file', type=Path)
    parser.add_argument('--read-path', action='append', default=[], help='Exact relative regular file; repeatable')
    parser.add_argument('--write-path', action='append', default=[], help='Exact returned patch path; existing files must be in the read selection; repeatable')
    parser.add_argument('--allow-write', action='store_true')
    parser.add_argument('--worktree-existing', type=Path)
    parser.add_argument('--resume', help='Exact wrapper-owned UUID; successful sessions only')
    parser.add_argument('--max-requests', type=int, default=4)
    parser.add_argument('--max-tokens', type=int, default=8000, help='Post-response cumulative admission threshold, not billing cap')
    parser.add_argument('--timeout-sec', type=int, default=120)
    args = parser.parse_args()
    os.umask(0o077)
    policy = json.loads(POLICY_PATH.read_text())
    if not args.check and (not args.model or not args.prompt_file):
        parser.error('--model and --prompt-file are required unless --check is selected')
    if args.check:
        runtime, node = resolve_pi_install()
        identity = runtime_identity(runtime, node)
        runtime_capabilities(runtime, node)
        if runtime_identity(runtime, node) != identity:
            raise ValueError('Pi runtime changed during capability preflight')
        print(json.dumps({'status': 'ready', 'cli_policy': 'current-with-capability-probes', **identity}))
        return
    if args.model not in policy['models']:
        raise ValueError('model not allowlisted')
    for key in ('max_requests', 'max_tokens', 'timeout_sec'):
        value = getattr(args, key)
        if not 1 <= value <= policy[key]:
            raise ValueError(f'invalid {key}')
        policy[key] = value
    source = Path(git(Path.cwd(), 'rev-parse', '--show-toplevel').decode().strip()).resolve()
    caller_root = source
    if args.role == 'contributor':
        if not args.allow_write or not args.worktree_existing or not args.write_path:
            raise ValueError('contributor requires --allow-write, --worktree-existing and --write-path')
        source = args.worktree_existing.resolve(strict=True)
        registered = git(source, 'worktree', 'list', '--porcelain').decode().splitlines()
        if f'worktree {source}' not in registered or not (source / '.git').is_file():
            raise ValueError('contributor target is not a registered linked worktree')
    elif args.allow_write or args.write_path or args.worktree_existing:
        raise ValueError('write authority requires contributor role')
    for name in args.write_path:
        safe_path(name)
    snapshot_head = git(source, 'rev-parse', 'HEAD')
    before = snapshot(source, args.read_path, policy, args.write_path)
    prompt = read_prompt(args.prompt_file, (caller_root, source), policy)
    runtime, node = resolve_pi_install()
    identity = runtime_identity(runtime, node)
    runtime_capabilities(runtime, node)
    if runtime_identity(runtime, node) != identity:
        raise ValueError('Pi runtime changed during capability preflight')
    if git(source, 'rev-parse', 'HEAD') != snapshot_head:
        raise ValueError('HEAD changed before snapshot binding')
    binding = {'source': str(source), 'head': snapshot_head.decode().strip(),
               'role': args.role, 'model': args.model, 'effort': args.effort,
               'write_paths': sorted(args.write_path),
               'snapshot': {key: sha(value) for key, value in sorted(before.items())}, 'policy': policy,
               'adapter': {name: sha((HERE / name).read_bytes()) for name in (
                   'pi_harness.py', 'pi-sandbox.py', 'pi-broker.mjs', 'pi-provider.ts')}}
    binding_hash = sha(json.dumps(binding, sort_keys=True).encode())
    session_id = str(uuid.UUID(args.resume)) if args.resume else str(uuid.uuid4())
    root = source / 'tmp/pi-harness'
    if (source / 'tmp').is_symlink() or root.is_symlink():
        raise ValueError('unsafe artifact directory')
    if subprocess.run(['git', '-C', str(source), 'check-ignore', '-q', '--', 'tmp/pi-harness/probe'],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        raise ValueError('artifact directory must be Git-ignored')
    root.mkdir(parents=True, exist_ok=True)
    session_root = root / session_id
    if session_root.is_symlink():
        raise ValueError('unsafe session directory')
    if not args.resume:
        session_root.mkdir()
    with open(session_root / 'lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if not args.resume:
            write_json(session_root / 'manifest.json', {**binding, 'runtime': identity})
        run_session(args, policy, source, before, prompt, runtime, node,
                    binding_hash, session_id, session_root, identity)


def run_session(args, policy, source, before, prompt, runtime, node,
                binding_hash, session_id, session_root, identity):
    state_path = session_root / 'state.json'
    prior = json.loads(state_path.read_text()) if args.resume else {}
    if args.resume and (prior.get('status') != 'success' or prior.get('binding') != binding_hash or
                        sha((session_root / 'session.jsonl').read_bytes()) != prior.get('session_sha256') or
                        sha((session_root / 'snapshot.json').read_bytes()) != prior.get('snapshot_sha256')):
        raise ValueError('resume identity, status or state mismatch')
    continuing = {name: base64.b64decode(value, validate=True) for name, value in
                  json.loads((session_root / 'snapshot.json').read_text()).items()} if args.resume else before
    attempt = session_root / str(len(list(session_root.glob('attempt-*'))) + 1)
    attempt = attempt.with_name('attempt-' + attempt.name)
    attempt.mkdir()
    for name in ('control', 'source', 'broker', 'empty-git'):
        (attempt / name).mkdir()
    if args.role != 'contributor':
        (attempt / 'source/.git').mkdir()
    for name, data in continuing.items():
        path = attempt / 'source' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    for name in ('pi-provider.ts', 'pi-sandbox.py'):
        shutil.copyfile(HERE / name, attempt / 'control' / name)
    (attempt / 'control/prompt').write_bytes(prompt)
    if args.resume:
        shutil.copyfile(session_root / 'session.jsonl', attempt / 'control/session.jsonl')
    provider_effort = 'low' if args.effort == 'minimal' else args.effort
    config = {'model': args.model, 'effort': args.effort, 'role': args.role,
              'session_id': session_id, 'policy': policy, 'runtime': identity}
    write_json(attempt / 'control/config.json', config)
    broker_config = {**policy, 'model': args.model, 'effort': args.effort,
                     'provider_effort': provider_effort, 'role': args.role,
                     'session_id': session_id, 'runtime': str(runtime),
                     'auth_path': str(Path.home() / '.pi/agent/auth.json'),
                     'socket': 'broker/socket', 'audit': str(attempt / 'broker-audit.json'),
                     'prior_requests': prior.get('requests', 0), 'prior_tokens': prior.get('total_tokens', 0)}
    write_json(attempt / 'broker-config.json', broker_config)
    state = {'status': 'running', 'binding': binding_hash, 'attempt': attempt.name, 'runtime': identity}
    write_json(state_path, state)
    broker = None
    sandbox_cleanup = {}
    try:
        broker = subprocess.Popen([str(node), str(HERE / 'pi-broker.mjs'), str(attempt / 'broker-config.json')],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                  env={'HOME': str(Path.home()), 'PATH': '/usr/bin:/bin'},
                                  cwd=attempt, start_new_session=True, preexec_fn=parent_death_signal)
        deadline = time.monotonic() + 10
        while not (attempt / 'broker/socket').exists():
            if broker.poll() is not None or time.monotonic() > deadline:
                raise ValueError('broker not ready; no login or refresh is performed')
            time.sleep(.05)
        code, output = bounded_process(sandbox_command(attempt, runtime, node, config),
                                       policy['timeout_sec'] + 5, policy['max_output_bytes'], sandbox_cleanup)
        # The namespace is gone and descendants are reaped before any extraction.
        broker.terminate()
        broker.wait(timeout=5)
        if runtime_identity(runtime, node) != identity:
            raise ValueError('Pi runtime changed during the run')
        if code:
            raise ValueError('sandbox failed')
        result = json.loads(output['stdout'])
        # Child logs contain only selected source and broker-sanitized responses.
        (attempt / 'pi-events.jsonl').write_text(result.get('stdout', ''))
        (attempt / 'pi-stderr.txt').write_text(result.get('stderr', ''))
        (attempt / 'forwarder-stderr.txt').write_text(result.get('forwarder_stderr', ''))
        audit = json.loads((attempt / 'broker-audit.json').read_text())
        if (audit.get('requested_effort') != args.effort or
                any(item.get('effective_effort') != provider_effort for item in audit.get('attempts', []))):
            raise ValueError('broker effort identity mismatch')
        patch, changed = extract(result, before, args.write_path, policy)
        text, session = validate_terminal(result, audit, session_id)
        (attempt / 'result.txt').write_text(text)
        (attempt / 'changes.patch').write_text(patch)
        (session_root / 'session.jsonl').write_bytes(session)
        write_json(session_root / 'snapshot.json', result['files'])
        state.update(status='success', effort=args.effort, provider_effort=provider_effort,
                     requests=audit['requests'], total_tokens=audit['total_tokens'],
                     session_sha256=sha(session), snapshot_sha256=sha((session_root / 'snapshot.json').read_bytes()),
                     changed_files=changed, cleanup='namespace-exited-and-broker-reaped')
    except Exception as error:
        state.update(status='failed', reason=str(error), resumable=False)
        raise
    finally:
        if broker and broker.poll() is None:
            try:
                os.killpg(broker.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            broker.wait()
        state['cleanup_evidence'] = {'sandbox': sandbox_cleanup, 'broker_reaped': broker is None or broker.poll() is not None}
        write_json(state_path, state)
    print(f'Pi candidate completed. Artifacts: {attempt}')


if __name__ == '__main__':
    def interrupted(_signum, _frame):
        raise InterruptedError('cancelled')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        main()
    except Exception as error:
        print(f'Pi candidate failed: {error}', file=sys.stderr)
        raise SystemExit(1)
