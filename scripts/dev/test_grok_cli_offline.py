"""Installed Grok semantics against a synthetic backend in a network namespace."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

# The fixture and CLI share only isolated loopback. No host credentials, home,
# repository contents, or outward network interface enter the namespace.
FIXTURE = r'''
import http.server, json, pathlib, socket, struct, subprocess, threading, uuid
home = pathlib.Path('/grok-home')
(home / 'config.toml').write_text("""[cli]
use_leader = false
[endpoints]
models_base_url = "http://127.0.0.1:38117/v1"
models_list_url = "http://127.0.0.1:38117/v1/models"
[model.fixture]
model = "grok-4.6"
base_url = "http://127.0.0.1:38117/v1"
api_key = "synthetic-no-provider-credential" # pragma: allowlist secret
api_backend = "chat_completions"
max_retries = 0
inference_idle_timeout_secs = 30
[features]
title_refresh = false
turn_summary = false
session_recap = false
[mcp]
max_output_bytes = 1048576
[toolset.bash]
output_byte_limit = 1048576
[plugins]
paths = []
[compat.claude]
skills = false
rules = false
agents = false
mcps = false
hooks = false
sessions = false
[compat.cursor]
skills = false
rules = false
agents = false
mcps = false
hooks = false
""")
(home / 'prompt.md').write_text('Synthetic fixture: inspect fixture.txt.\n')
pathlib.Path('/workspace/fixture.txt').write_text('SYNTHETIC_SOURCE_ONLY\n')
mode = 'loop'
sequence = 0
chat_requests = 0
main_requests = 0
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass
    def reply(self, status, data, stream=False):
        self.send_response(status)
        self.send_header('Content-Type', 'text/event-stream' if stream else 'application/json')
        self.end_headers()
        self.wfile.write(data.encode())
        self.wfile.flush()
    def do_GET(self):
        self.reply(200, json.dumps({'object':'list','data':[{'id':'grok-4.6','object':'model'}]}))
    def do_POST(self):
        global sequence, chat_requests, main_requests
        body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))) or b'{}')
        if not self.path.endswith('/chat/completions'):
            self.reply(404, '{}')
            return
        sequence += 1
        chat_requests += 1
        main = any(t.get('function', {}).get('name') == 'read_file' for t in body.get('tools', []))
        if main:
            main_requests += 1
        if main and mode == 'abort':
            aborted = {'id':'chatcmpl-abort','object':'chat.completion.chunk','created':1,
                       'model':'grok-4.6-build',
                       'choices':[{'index':0,'delta':{'role':'assistant','content':'partial'},
                                   'finish_reason':None}]}
            self.reply(200, 'data: ' + json.dumps(aborted) + '\n\n', True)
            self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
            self.connection.close()
            self.close_connection = True
            return
        delta = {'role':'assistant','content':'SYNTHETIC_FINAL'}
        finish = 'stop'
        if main and mode == 'loop':
            delta = {'role':'assistant','content':'Inspecting fixture.', 'tool_calls':[
                {'index':i,'id':f'call_{sequence}_{i}','type':'function','function':{
                    'name':'read_file','arguments':json.dumps({'target_file':'/workspace/fixture.txt'})}}
                for i in range(2)]}
            finish = 'tool_calls'
        def chunk(delta, reason=None, usage=None):
            data = {'id':f'chatcmpl-{sequence}','object':'chat.completion.chunk','created':1,
                    'model':'grok-4.6-build','choices':[{'index':0,'delta':delta,'finish_reason':reason}]}
            if usage:
                data['usage'] = usage
            return 'data: ' + json.dumps(data) + '\n\n'
        usage = {'prompt_tokens':10,'completion_tokens':2,'total_tokens':12,'cost_in_usd_ticks':100000000}
        self.reply(200, chunk(delta) + chunk({}, finish, usage) + 'data: [DONE]\n\n', True)
server = http.server.ThreadingHTTPServer(('127.0.0.1', 38117), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
session = str(uuid.uuid4())
args = ['/grok-bin/grok','--cwd','/workspace','--model','fixture','--output-format','plain',
        '--verbatim','--always-approve','--no-leader','--no-auto-update','--tools','read_file',
        '--max-turns','8','--session-id',session,'--prompt-file',str(home / 'prompt.md')]
try:
    failure = subprocess.run(args, capture_output=True, text=True, timeout=30)
    folder = next((home / 'sessions').glob('*/' + session))
    failed_usage = json.loads((folder / 'usage.json').read_text())
    events = [json.loads(line) for line in (folder / 'events.jsonl').read_text().splitlines()]
    updates = [json.loads(line)['params']['update'] for line in (folder / 'updates.jsonl').read_text().splitlines()]
    mode = 'final'
    args[args.index('--session-id')] = '--resume'
    args[args.index('--max-turns') + 1] = '1'
    args[args.index('--output-format') + 1] = 'json'
    resumed = subprocess.run(args, capture_output=True, text=True, timeout=30)
    mode = 'abort'
    retry_probe_start = main_requests
    retry_session = str(uuid.uuid4())
    args[args.index('--resume')] = '--session-id'
    args[args.index('--session-id') + 1] = retry_session
    args[args.index('--output-format') + 1] = 'plain'
    retry_probe = subprocess.run(args, capture_output=True, text=True, timeout=30)
    retry_probe_requests = main_requests - retry_probe_start
    config_path = home / 'config.toml'
    config_path.write_text(config_path.read_text().replace('max_retries = 0', 'max_retries = 2'))
    retry_control_start = main_requests
    args[args.index('--session-id') + 1] = str(uuid.uuid4())
    retry_control = subprocess.run(args, capture_output=True, text=True, timeout=30)
    result = {'session':session,'failed_exit':failure.returncode,'failed_stderr':failure.stderr,
              'failed_usage':failed_usage,'events':events,'updates':updates,
              'resume_exit':resumed.returncode,'resume_stdout':resumed.stdout,'resume_stderr':resumed.stderr,
              'retry_probe_exit':retry_probe.returncode,
              'retry_probe_requests':retry_probe_requests,
              'retry_probe_stderr':retry_probe.stderr,
              'retry_control_exit':retry_control.returncode,
              'retry_control_requests':main_requests - retry_control_start,
              'retry_control_stderr':retry_control.stderr}
    (home / 'result.json').write_text(json.dumps(result))
finally:
    server.shutdown()
'''


class GrokOfflineTest(unittest.TestCase):
    def test_turn_limit_persistence_and_resume(self):
        binary = shutil.which('grok')
        if not binary or not shutil.which('bwrap'):
            self.skipTest('installed Grok and Bubblewrap required for offline CLI proof')
        check = subprocess.run([str(ROOT / 'scripts/dev/agent-call-grok.sh'), '--check'],
                               capture_output=True, text=True, timeout=45)
        self.assertEqual(check.returncode, 0, check.stderr)
        with tempfile.TemporaryDirectory(prefix='grok-cli-offline-') as temp:
            base = Path(temp)
            (base / 'home').mkdir()
            (base / 'workspace').mkdir()
            (base / 'fixture.py').write_text(FIXTURE)
            command = ['bwrap','--die-with-parent','--new-session','--unshare-net','--unshare-pid',
                       '--unshare-uts','--unshare-ipc','--ro-bind','/usr','/usr',
                       '--symlink','usr/bin','/bin','--symlink','usr/lib','/lib',
                       '--symlink','usr/lib64','/lib64','--proc','/proc','--dev','/dev',
                       '--dir','/etc','--ro-bind','/etc/passwd','/etc/passwd',
                       '--ro-bind','/etc/group','/etc/group',
                       '--ro-bind',str(Path(binary).resolve()),'/grok-bin/grok',
                       '--bind',str(base / 'home'),'/grok-home',
                       '--bind',str(base / 'workspace'),'/workspace',
                       '--ro-bind',str(base / 'fixture.py'),'/fixture.py','--tmpfs','/tmp',
                       '--clearenv','--setenv','HOME','/grok-home','--setenv','GROK_HOME','/grok-home',
                       # Separate from model.max_retries in current Grok releases.
                       '--setenv','GROK_TURN_TRANSIENT_RETRY','0',
                       '--setenv','PATH','/usr/bin:/bin',
                       '--setenv','XAI_API_KEY','synthetic-no-provider-credential',
                       '--setenv','GROK_MODELS_BASE_URL','http://127.0.0.1:38117/v1',
                       '--setenv','GROK_MODELS_LIST_URL','http://127.0.0.1:38117/v1/models',
                       '--chdir','/workspace','/usr/bin/python3','/fixture.py']
            with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                  env={'PATH':os.environ['PATH']}) as process:
                try:
                    stdout, stderr = process.communicate(timeout=65)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.communicate()
                    self.fail('offline CLI fixture timed out')
                self.assertEqual(process.returncode, 0, stdout + stderr)
                self.assertFalse(Path(f'/proc/{process.pid}').exists())
            result = json.loads((base / 'home/result.json').read_text())
            self.assertEqual(result['failed_exit'], 1)
            self.assertIn('Error: max turns reached', result['failed_stderr'])
            self.assertEqual([e['loop_index'] for e in result['events'] if e['type'] == 'loop_started'], list(range(8)))
            self.assertEqual(result['events'][-1]['cancellation_context'], {'reason':'max_turns_reached','limit':8})
            self.assertEqual(sum(u['sessionUpdate'] == 'tool_call' for u in result['updates']), 16)
            self.assertEqual(sum(e['type'] == 'tool_completed' and e.get('outcome') == 'success'
                                 for e in result['events']), 16)
            usage = result['failed_usage']['session']
            self.assertEqual(usage['modelCalls'], 8)
            self.assertEqual(usage['turnCount'], 1)
            self.assertEqual(usage['primaryModelId'], 'grok-4.6-build')
            self.assertEqual(usage['costUsdTicks'], 800000000)
            self.assertEqual(result['resume_exit'], 0, result['resume_stderr'])
            resumed = json.loads(result['resume_stdout'])
            self.assertEqual(resumed['sessionId'], result['session'])
            self.assertEqual(resumed['text'], 'SYNTHETIC_FINAL')
            self.assertEqual(resumed['num_turns'], 1)
            self.assertEqual(resumed['total_cost_usd'], .01)
            self.assertEqual(resumed['total_cost_usd_ticks'], 100000000)
            self.assertNotEqual(result['retry_probe_exit'], 0)
            self.assertEqual(result['retry_probe_requests'], 1, result['retry_probe_stderr'])
            self.assertNotEqual(result['retry_control_exit'], 0)
            self.assertEqual(result['retry_control_requests'], 2, result['retry_control_stderr'])


if __name__ == '__main__':
    unittest.main()
