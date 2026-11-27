"""Untrusted-side launcher. The outer controller validates every exported byte."""
import base64
import json
import os
from pathlib import Path
import resource
import selectors
import shutil
import signal
import subprocess
import time


def capture(command, policy):
    process = subprocess.Popen(command, stdin=open('/control/prompt', 'rb'),
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ, 'stdout')
    selector.register(process.stderr, selectors.EVENT_READ, 'stderr')
    output = {'stdout': bytearray(), 'stderr': bytearray()}
    deadline = time.monotonic() + policy['timeout_sec']
    timed_out = False
    while selector.get_map():
        if time.monotonic() >= deadline:
            process.terminate()
            timed_out = True
            break
        for key, _ in selector.select(.1):
            data = os.read(key.fileobj.fileno(), 65536)
            if not data:
                selector.unregister(key.fileobj)
                continue
            output[key.data].extend(data)
            if sum(map(len, output.values())) > policy['max_output_bytes']:
                raise RuntimeError('output-limit')
    if timed_out:
        return 124, {
            key: bytes(value).decode('utf-8', errors='replace')
            for key, value in output.items()
        }
    return process.wait(timeout=1), {k: bytes(v).decode('utf-8') for k, v in output.items()}


def stop_descendants():
    # Private PID namespace: all other processes are owned by this run.
    for entry in Path('/proc').iterdir():
        if entry.name.isdecimal() and int(entry.name) not in (1, os.getpid()):
            try:
                os.kill(int(entry.name), signal.SIGKILL)
            except ProcessLookupError:
                pass
    while True:
        try:
            os.waitpid(-1, 0)
        except ChildProcessError:
            break


def files(root, policy):
    result = {}
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root).as_posix()
        if relative == '.git' or relative.startswith('.git/'):
            continue
        if path.is_symlink() or not (path.is_dir() or path.is_file()):
            raise RuntimeError('special-file')
        if path.is_file():
            if path.stat().st_size > policy['max_file_bytes']:
                raise RuntimeError('file-limit')
            result[relative] = base64.b64encode(path.read_bytes()).decode('ascii')
            if len(result) > policy['max_files']:
                raise RuntimeError('file-count')
    return result


def main():
    config = json.loads(Path('/control/config.json').read_text())
    policy = config['policy']
    for limit, value in ((resource.RLIMIT_AS, policy['address_space_bytes']),
                         (resource.RLIMIT_NPROC, policy['processes']),
                         (resource.RLIMIT_CPU, policy['cpu_seconds']),
                         (resource.RLIMIT_FSIZE, policy['max_output_bytes']),
                         (resource.RLIMIT_NOFILE, 96), (resource.RLIMIT_CORE, 0)):
        resource.setrlimit(limit, (value, value))
    if config['role'] == 'contributor':
        shutil.copytree('/source', '/workspace', dirs_exist_ok=True)
    Path('/home/agent/.pi/agent').mkdir(parents=True)
    Path('/home/agent/.pi/agent/settings.json').write_text(json.dumps({
        'transport': 'sse', 'retry': {'enabled': False, 'maxRetries': 0},
        'provider': {'maxRetries': 0}, 'compaction': {'enabled': False}}))
    if Path('/control/session.jsonl').exists():
        shutil.copyfile('/control/session.jsonl', '/state/session.jsonl')
    forwarder_log = open('/tmp/forwarder.log', 'w+b')
    forwarder = subprocess.Popen(['/usr/bin/socat', 'TCP-LISTEN:38117,bind=127.0.0.1,reuseaddr,fork',
                                  'UNIX-CONNECT:/broker/socket'], stdout=subprocess.DEVNULL,
                                 stderr=forwarder_log)
    try:
        if config.get('probe'):
            command = ['/usr/bin/python3', '/control/probe.py']
        else:
            tools = ('read,bash,edit,write,grep,ls'
                     if config['role'] == 'contributor' else 'read,grep,ls')
            command = ['/runtime/node', '--disable-wasm-trap-handler',
                       '--max-old-space-size=128', '/runtime/pi/dist/bundle/cli.js',
                       '--offline', '--no-extensions', '--no-skills', '--no-prompt-templates',
                       '--no-themes', '--no-context-files', '--no-approve',
                       '-e', '/control/pi-provider.ts', '--provider', 'openai-codex',
                       '--model', config['model'], '--thinking', config['effort'], '--mode', 'json',
                       '--session-dir', '/state', '--tools', tools, '-p']
            if Path('/state/session.jsonl').exists():
                command += ['--session', '/state/session.jsonl']
            else:
                command += ['--session-id', config['session_id']]
        code, output = capture(command, policy)
    finally:
        stop_descendants()
        forwarder.wait()
    forwarder_log.seek(0)
    output['forwarder_stderr'] = forwarder_log.read(8192).decode('utf-8')
    forwarder_log.close()
    result = {'exit_code': code, **output, 'files': files(Path('/workspace'), policy),
              'sessions': files(Path('/state'), policy)}
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except Exception:
        stop_descendants()
        print('{"error":"sandbox-failed"}')
        raise SystemExit(1)
