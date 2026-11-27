import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const source = await fs.readFile(new URL('./agent-call-grok.sh', import.meta.url), 'utf8');
const fixtureGrokVersion = 'grok 99.0.0 (synthetic) [alpha]';
const fixtureCapabilities = '--cwd --model --output-format --verbatim --always-approve --max-turns --prompt-file --session-id --resume --reasoning-effort --tools --no-subagents --disable-web-search';
// Budget policy is read from the wrapper, not restated here. The previous
// tests pinned the literal 8 and 9, so raising the budget looked like a
// regression instead of a policy change.
const defaultMaxTurns = Number(source.match(/^max_turns="\$\{AGENT_CALL_GROK_MAX_TURNS:-(\d+)\}"$/m)?.[1]);
const maxTurnsCeiling = Number(source.match(/"\$max_turns" -gt (\d+) \]\]/)?.[1]);
assert.ok(Number.isInteger(defaultMaxTurns) && defaultMaxTurns > 0, 'wrapper must declare a default turn budget');
assert.ok(Number.isInteger(maxTurnsCeiling) && maxTurnsCeiling >= defaultMaxTurns, 'ceiling must be at least the default');
const fake = `#!/usr/bin/python3
import http.client, json, os, pathlib, sys
args = sys.argv[1:]
if args == ['--version']:
 print('${fixtureGrokVersion}'); sys.exit(0)
if '--help' in args:
 print('${fixtureCapabilities}'); sys.exit(0)
capture = pathlib.Path(os.environ['FAKE_CAPTURE_DIR'])
index = os.environ['FAKE_CALL_INDEX']
scenario = json.loads((capture / ('scenario-' + index + '.json')).read_text())
def arg(name): return args[args.index(name)+1]
session = arg('--session-id') if '--session-id' in args else arg('--resume')
prompt = pathlib.Path(arg('--prompt-file')).read_text()
config = (pathlib.Path(os.environ['GROK_HOME']) / 'config.toml').read_text()
assert os.environ.get('GROK_TURN_TRANSIENT_RETRY') == '0', 'whole-turn retries must be disabled'
broker_status = None
probe_status = None
stream_status = None
stream_error = None
success_after_stream_status = None
if scenario.get('broker_oversized'):
 conn = http.client.HTTPConnection('127.0.0.1', 38117, timeout=10)
 conn.request('POST', '/provider/v1/chat/completions', json.dumps({'model':'grok-4.6','prompt':'x' * 2097152}))
 response = conn.getresponse()
 broker_status = response.status
 response.read()
 conn.close()
if scenario.get('broker_probe_then_stream'):
 conn = http.client.HTTPConnection('127.0.0.1', 38117, timeout=10)
 conn.request('GET', '/unavailable')
 response = conn.getresponse()
 probe_status = response.status
 response.read()
 conn.close()
 conn = http.client.HTTPConnection('127.0.0.1', 38117, timeout=10)
 conn.request('POST', '/provider/v1/chat/completions?test_stream_failure=1', json.dumps({'model':'grok-4.6'}))
 response = conn.getresponse()
 stream_status = response.status
 try: response.read()
 except Exception as error: stream_error = type(error).__name__
 conn.close()
 if scenario.get('success_after_stream'):
  conn = http.client.HTTPConnection('127.0.0.1', 38117, timeout=10)
  conn.request('GET', '/provider/v1/models')
  response = conn.getresponse()
  success_after_stream_status = response.status
  response.read()
  conn.close()
(capture / ('call-' + index + '.json')).write_text(json.dumps({'args': args, 'session': session, 'prompt': prompt, 'config': config, 'broker_status': broker_status, 'probe_status': probe_status, 'stream_status': stream_status, 'stream_error': stream_error, 'success_after_stream_status': success_after_stream_status}))
folder = pathlib.Path(os.environ['GROK_HOME']) / 'sessions' / '%2Fworkspace' / session
if scenario.get('session', True):
 folder.mkdir(parents=True, exist_ok=True)
 (folder / 'updates.jsonl').write_text(json.dumps({'session':session,'prompt':prompt})+'\\n')
 (folder / 'summary.json').write_text(json.dumps({'info':{'id':session},'current_model_id':'grok-4.6'}))
 (folder / 'chat_history.jsonl').write_text(
  json.dumps({'type':'assistant','content':'SYNTHETIC_ASSISTANT_TEXT','tool_calls':[]})+'\\n'+
  json.dumps({'type':'assistant','content':'','tool_calls':[{'id':'c1','name':'grep'}]})+'\\n'+
  json.dumps({'type':'reasoning','summary':[{'type':'summary_text','text':'SYNTHETIC_REASONING_TEXT'}]})+'\\n')
 (folder / 'usage.json').write_text(json.dumps({'sessionId':session,'session':{'modelCalls':int(arg('--max-turns')),'costUsdTicks':120000000,'primaryModelId':'grok-4.6-build','modelUsage':{'grok-4.6-build':{'modelCalls':int(arg('--max-turns')),'costUsdTicks':120000000}}},'turns':[]}))
 if scenario.get('unsafe') == 'secret': (folder / 'updates.jsonl').write_text('test-broker-secret-value\\n')
 if scenario.get('unsafe') == 'symlink': (folder / 'link').symlink_to('/etc/passwd')
 if scenario.get('unsafe') == 'fifo': os.mkfifo(folder / 'pipe')
 if scenario.get('unsafe') == 'bad_usage': (folder / 'usage.json').write_text('{invalid')
if scenario.get('write'): pathlib.Path('/workspace/not-transferred.txt').write_text('private failed change\\n')
print('SYNTHETIC_PARTIAL' if scenario.get('exit', 1) else 'SYNTHETIC_COMPLETE')
if scenario.get('exit', 1):
 if scenario.get('broker_oversized'): print('Error: broker rejected synthetic request', file=sys.stderr)
 elif scenario.get('broker_probe_then_stream'): print('Error: reqwest error stream: Transport error: error decoding response body', file=sys.stderr)
 else: print('Max turns reached\\nError: max turns reached', file=sys.stderr)
sys.exit(scenario.get('exit', 1))
`;

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: 'utf8', timeout: 60_000, ...options });
  assert.ifError(result.error);
  return result;
}

async function setup(t, { deepCheckout = false } = {}) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'grok-wrapper-test-'));
  t.after(async () => { await fs.rm(dir, { recursive: true, force: true }); });
  const repo = path.join(dir, deepCheckout ? 'deep-checkout-'.repeat(8) : 'repo');
  // Copy existing objects only. No source checkout changes or new commits.
  const cloned = run('git', ['clone', '--quiet', '--no-local', '--depth', '1', pathToFileURL(root).href, repo]);
  assert.equal(cloned.status, 0, cloned.stderr);
  const binary = path.join(dir, 'grok');
  await fs.writeFile(binary, fake, { mode: 0o700 });
  // The fixture must pass the same capability checks as an installed CLI.
  // The test broker has no provider transport in test mode.
  const wrapper = path.join(dir, 'agent-call-grok.sh');
  await fs.writeFile(wrapper, source, { mode: 0o700 });
  const home = path.join(dir, 'home');
  const capture = path.join(dir, 'capture');
  const outputDir = path.join(repo, 'tmp', 'results');
  await Promise.all([fs.mkdir(home), fs.mkdir(capture), fs.mkdir(outputDir, { recursive: true })]);
  await fs.writeFile(path.join(home, 'auth.json'), '{"key":"test-broker-secret-value"}');
  const prompt = path.join(dir, 'prompt.md');
  const context = path.join(dir, 'inline.md');
  await fs.writeFile(prompt, 'SYNTHETIC_ASSIGNMENT\n');
  await fs.writeFile(context, 'COMMON_CONTEXT_INLINE_SENTINEL\n');
  const env = { PATH: process.env.PATH, HOME: dir, GROK_HOME: home,
    AGENT_CALL_GROK_BIN: binary, AGENT_CALL_GROK_TEST_MODE: '1',
    PARALLEL_SEARCH_API_TOKEN: 'test-parallel-secret', CONTEXT7_API_KEY: 'test-context7-secret', // pragma: allowlist secret (synthetic fixtures)
    FAKE_CAPTURE_DIR: capture, LANG: 'C.UTF-8' };
  let index = 0;
  async function call(scenario = {}, extra = []) {
    const id = String(++index);
    const output = path.join(outputDir, `call-${id}.md`);
    await fs.writeFile(path.join(capture, `scenario-${id}.json`), JSON.stringify(scenario));
    const result = run(wrapper, ['--prompt-file', prompt, '--context-file', context,
      '--model', 'grok-4.6', '--output', output, '--timeout-sec', '30', ...extra],
    { cwd: repo, env: { ...env, FAKE_CALL_INDEX: id } });
    assert.equal(await exists(path.join(capture, `call-${id}.json`)), true, result.stderr + await fs.readFile(output.replace(/\.md$/, '.stderr.log'), 'utf8').catch(() => ''));
    const observed = JSON.parse(await fs.readFile(path.join(capture, `call-${id}.json`), 'utf8'));
    assert.deepEqual((await fs.readdir(path.join(repo, 'tmp/codex-claude/state'))).filter(p => p.startsWith('.grok-run.')), []);
    const brokerPid = Number(await fs.readFile(path.join(capture, `broker-host-pid-${id}`), 'utf8'));
    assert.throws(() => process.kill(brokerPid, 0), { code: 'ESRCH' });
    return { result, observed, output, failure: `${output}.failed` };
  }
  return { dir, repo, wrapper, binary, env, prompt, context, call };
}

test('deep worktree paths do not exceed the broker Unix socket address limit', async t => {
  const fixture = await setup(t, { deepCheckout: true });
  const previousSocketPath = path.join(fixture.repo, 'tmp/codex-claude/state/.grok-run.123456/broker.sock');
  assert.ok(Buffer.byteLength(previousSocketPath) > 107, 'fixture must exceed the Linux sun_path limit');
  const { result } = await fixture.call({ exit: 0 }, ['--role', 'none', '--answer-only', '--max-turns', '1']);
  assert.equal(result.status, 0, result.stderr);
});

test('new CLI releases pass without repinning, but missing flags and within-run changes fail', async t => {
  const fixture = await setup(t);
  const check = () => run(fixture.wrapper, ['--check'], { cwd: fixture.repo, env: fixture.env });
  let result = check();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).version, fixtureGrokVersion);
  await fs.writeFile(fixture.binary, fake.replace(fixtureGrokVersion, 'grok 100.2.3 (next) [stable]'));
  result = check();
  assert.equal(result.status, 0, result.stderr);
  assert.match(JSON.parse(result.stdout).version, /100\.2\.3/);
  await fs.writeFile(fixture.binary, fake.replace('--session-id --resume', '--session-id-extra --resume'));
  result = check();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /lacks required capability: --session-id/);
  await fs.writeFile(fixture.binary, fake.replace("if '--help' in args:",
    "if '--help' in args:\n pathlib.Path(sys.argv[0]).write_text(pathlib.Path(sys.argv[0]).read_text() + '# changed\\n')"));
  result = check();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /binary changed during capability preflight/);
});

test('a successful wrapper-owned session can continue after a capability-compatible CLI update', async t => {
  const fixture = await setup(t);
  const first = await fixture.call({ exit: 0 }, ['--session-alias', 'upgrade-fixture']);
  assert.equal(first.result.status, 0, first.result.stderr);
  await fs.writeFile(fixture.binary, fake.replace(fixtureGrokVersion, 'grok 99.1.0 (upgraded)'));
  const next = await fixture.call({ exit: 0 }, ['--session-alias', 'upgrade-fixture']);
  assert.equal(next.result.status, 0, next.result.stderr);
  assert.equal(next.observed.session, first.observed.session);
});

async function exists(file) { return Boolean(await fs.lstat(file).catch(() => false)); }
async function manifest(failure) { return JSON.parse(await fs.readFile(path.join(failure, 'result.json'), 'utf8')); }

test('turn limit is passed once unchanged and failed contributor evidence survives without transfer', async t => {
  const fixture = await setup(t);
  const target = path.join(fixture.dir, 'contributor');
  const added = run('git', ['-C', fixture.repo, 'worktree', 'add', '--quiet', '--detach', target, 'HEAD']);
  assert.equal(added.status, 0, added.stderr);
  const { result, observed, output, failure } = await fixture.call({ write: true },
    ['--role', 'contributor', '--allow-write', '--worktree-existing', target, '--max-turns', '3', '--session-alias', 'failed-fixture']);
  assert.equal(result.status, 1, result.stderr);
  assert.equal(observed.args.filter(a => a === '--max-turns').length, 1);
  assert.equal(observed.args[observed.args.indexOf('--max-turns') + 1], '3');
  assert.match(observed.prompt, /SYNTHETIC_ASSIGNMENT/);
  assert.match(observed.prompt, /COMMON_CONTEXT_INLINE_SENTINEL/);
  assert.match(observed.config, /max_retries = 0/);
  assert.match(observed.config, /inference_idle_timeout_secs = 30/);
  assert.match(observed.config, /title_refresh = false/);
  assert.match(observed.config, /turn_summary = false/);
  assert.match(observed.config, /session_recap = false/);
  assert.match(observed.config, /\[mcp\]\nmax_output_bytes = 1048576/);
  assert.match(observed.config, /\[toolset\.bash\]\noutput_byte_limit = 1048576/);
  assert.equal(await exists(path.join(target, 'not-transferred.txt')), false);
  const retained = await manifest(failure);
  assert.equal(retained.session, observed.session);
  assert.equal(retained.status, 'failed');
  assert.equal(retained.exit_code, 1);
  assert.equal(retained.terminal_reason, 'max_turns_reached');
  assert.equal(retained.max_turns, 3);
  assert.equal(retained.requested_model, 'grok-4.6');
  assert.equal(retained.session_evidence, 'retained');
  assert.equal(retained.broker_evidence, 'retained');
  assert.equal(retained.broker_limits.maxTurns, 3);
  assert.equal(retained.broker_limits.providerRequestBytes, 3584 * 1024);
  assert.equal(retained.broker_limits.requestBody, 2 * 1024 * 1024);
  assert.equal(retained.broker_terminal_reason, 'SIGTERM');
  assert.equal(await exists(path.join(failure, 'broker.jsonl')), true);
  assert.equal(retained.resume_ready, false);
  assert.deepEqual(retained.effective_models, ['grok-4.6-build']);
  assert.equal(retained.reported_cost_usd_ticks, 120000000);
  assert.equal((await fs.stat(failure)).mode & 0o777, 0o700);
  assert.equal((await fs.stat(path.join(failure, 'result.json'))).mode & 0o777, 0o600);
  const state = path.join(fixture.repo, 'tmp/codex-claude/state');
  for (const name of ['grok-session-failed-fixture', 'grok-latest-session-id', `grok-session-${observed.session}.json`]) {
    assert.equal(await exists(path.join(state, name)), false);
  }
  assert.match(await fs.readFile(output, 'utf8'), /SYNTHETIC_PARTIAL/);
  const resume = run(fixture.wrapper, ['--resume', observed.session, '--prompt-file', fixture.prompt],
    { cwd: fixture.repo, env: fixture.env });
  assert.equal(resume.status, 1);
  assert.match(resume.stderr, /No wrapper-owned metadata exists/);
});

test('the wrapper default turn budget is passed through and absent evidence is never fabricated', async t => {
  const fixture = await setup(t);
  const missing = await fixture.call({ session: false });
  assert.equal(missing.result.status, 1);
  assert.equal(missing.observed.args[missing.observed.args.indexOf('--max-turns') + 1],
    String(defaultMaxTurns));
  const record = await manifest(missing.failure);
  assert.equal(record.session_evidence, 'missing');
  assert.equal(record.usage_evidence, 'missing');
  assert.equal(record.reported_cost_usd_ticks, null);
  assert.equal(record.effective_models, null);
  const invalid = await fixture.call({ unsafe: 'bad_usage' }, ['--max-turns', '2']);
  const record2 = await manifest(invalid.failure);
  assert.equal(record2.session_evidence, 'retained');
  assert.equal(record2.usage_evidence, 'invalid');
  assert.equal(record2.reported_cost_usd_ticks, null);
});

test('turn limit above the provider admission envelope fails before execution', async t => {
  const fixture = await setup(t);
  const result = run(fixture.wrapper,
    ['--prompt-file', fixture.prompt, '--max-turns', String(maxTurnsCeiling + 1)],
    { cwd: fixture.repo, env: fixture.env });
  assert.equal(result.status, 1);
  assert.match(result.stderr,
    new RegExp(`--max-turns must be an integer from 1 through ${maxTurnsCeiling}`));
});

test('failed evidence retains the broker rejection reason and effective limits', async t => {
  const fixture = await setup(t);
  const failed = await fixture.call({ broker_oversized: true });
  assert.equal(failed.result.status, 1);
  assert.equal(failed.observed.broker_status, 413);
  const record = await manifest(failed.failure);
  assert.equal(record.terminal_reason, 'broker_rejected');
  assert.equal(record.broker_last_rejection.status, 413);
  assert.equal(record.broker_last_rejection.reason, 'request body limit exceeded');
  assert.equal(record.broker_last_rejection.limit, 2 * 1024 * 1024);
  assert.equal(record.broker_limits.providerRequestBytes,
    2 * 1024 * 1024 + defaultMaxTurns * 512 * 1024);
});

test('terminal classification ignores an earlier route probe and retains the later stream failure', async t => {
  const fixture = await setup(t);
  const target = path.join(fixture.dir, 'stream-contributor');
  const added = run('git', ['-C', fixture.repo, 'worktree', 'add', '--quiet', '--detach', target, 'HEAD']);
  assert.equal(added.status, 0, added.stderr);
  const failed = await fixture.call({ broker_probe_then_stream: true, write: true },
    ['--role', 'contributor', '--allow-write', '--worktree-existing', target]);
  assert.equal(failed.result.status, 1);
  assert.equal(failed.observed.probe_status, 404);
  assert.equal(failed.observed.stream_status, 200);
  assert.ok(failed.observed.stream_error);
  assert.equal(await exists(path.join(target, 'not-transferred.txt')), false);
  const record = await manifest(failed.failure);
  assert.equal(record.terminal_reason, 'upstream_response_stream_failed');
  assert.equal(record.broker_last_rejection.reason, 'route unavailable');
  assert.equal(record.broker_last_rejection.requestId, 1);
  assert.equal(record.broker_last_rejection.route, null);
  assert.equal(record.broker_terminal_event.requestId, 2);
  assert.equal(record.broker_terminal_event.route, 'provider');
  assert.equal(record.broker_terminal_event.path, '/provider/v1/chat/completions');
  assert.equal(record.broker_terminal_event.phase, 'upstream_response_stream');
  assert.equal(record.broker_terminal_event.status, 200);
  assert.equal(record.broker_terminal_event.upstreamStatus, 200);
  assert.ok(record.broker_terminal_event.responseBytes > 0);
  assert.equal(record.broker_terminal_event.downstreamHeadersSent, true);
  assert.deepEqual(record.broker_terminal_event.upstreamHeaderNames,
    ['content-type', 'transfer-encoding']);
  assert.deepEqual(record.broker_terminal_event.forwardedHeaderNames, ['content-type']);
  const retainedAudit = path.join(failed.failure, 'broker.jsonl');
  assert.equal((await fs.stat(retainedAudit)).mode & 0o777, 0o600);
  const auditText = await fs.readFile(retainedAudit, 'utf8');
  assert.doesNotMatch(auditText, /test-broker-secret-value|test-parallel-secret|test-context7-secret/);
});

test('a later completed routed request prevents an older failure from becoming terminal', async t => {
  const fixture = await setup(t);
  const failed = await fixture.call({ broker_probe_then_stream: true, success_after_stream: true });
  assert.equal(failed.result.status, 1);
  assert.equal(failed.observed.success_after_stream_status, 200);
  const record = await manifest(failed.failure);
  assert.equal(record.terminal_reason, 'cli_exit_nonzero');
  assert.equal(record.broker_terminal_event.outcome, 'completed');
  assert.equal(record.broker_terminal_event.requestId, 3);
  assert.equal(record.broker_terminal_event.route, 'provider');
});

test('failed session retention refuses secrets, symlinks, and special files', async t => {
  const fixture = await setup(t);
  for (const unsafe of ['secret', 'symlink', 'fifo']) {
    const failed = await fixture.call({ unsafe });
    assert.equal(failed.result.status, 1);
    const record = await manifest(failed.failure);
    assert.equal(record.session_evidence, 'refused');
    assert.equal(record.resume_ready, false);
    assert.equal(await exists(path.join(failed.failure, 'session')), false);
    assert.doesNotMatch(await fs.readFile(path.join(failed.failure, 'result.json'), 'utf8'), /test-broker-secret-value/);
  }
});

test('success checkpoints survive a later failed continuation unchanged', async t => {
  const fixture = await setup(t);
  const success = await fixture.call({ exit: 0 }, ['--session-alias', 'successful-fixture']);
  assert.equal(success.result.status, 0, success.result.stderr);
  assert.equal(await exists(success.failure), false);
  const state = path.join(fixture.repo, 'tmp/codex-claude/state');
  const metadata = JSON.parse(await fs.readFile(path.join(state, `grok-session-${success.observed.session}.json`), 'utf8'));
  assert.equal(metadata.session, success.observed.session);
  assert.equal((await fs.readFile(path.join(state, 'grok-session-successful-fixture'), 'utf8')).trim(), success.observed.session);
  const checkpoint = path.join(state, `grok-session-data-${success.observed.session}`, 'usage.json');
  const previous = await fs.readFile(checkpoint, 'utf8');
  const failure = await fixture.call({}, ['--resume', success.observed.session, '--max-turns', '2']);
  assert.equal(failure.result.status, 1);
  assert.equal((await manifest(failure.failure)).session, success.observed.session);
  assert.equal(await fs.readFile(checkpoint, 'utf8'), previous);
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(state, `grok-session-${success.observed.session}.json`), 'utf8')), metadata);
});

test('answer-only removes every built-in tool surface and states the turn budget', async t => {
  const fixture = await setup(t);
  const { observed } = await fixture.call({ exit: 0 },
    ['--role', 'critic', '--max-turns', '4', '--answer-only']);
  // Enforcement, not persuasion: an empty built-in allowlist also closes the
  // `use_tool` gateway to the selected MCP servers.
  assert.equal(observed.args.filter(a => a === '--tools').length, 1);
  assert.equal(observed.args[observed.args.indexOf('--tools') + 1], '');
  assert.ok(observed.args.includes('--no-subagents'));
  assert.ok(observed.args.includes('--disable-web-search'));
  assert.match(observed.prompt, /Answer-only mode/);
  assert.match(observed.prompt, /at most 4 main-agent tool-loop turns/);
  assert.match(observed.prompt, /reserve your final turn/);
});

test('the turn budget is stated for reviewing roles without answer-only', async t => {
  const fixture = await setup(t);
  const { observed } = await fixture.call({ exit: 0 }, ['--role', 'reviewer', '--max-turns', '7']);
  assert.match(observed.prompt, /at most 7 main-agent tool-loop turns/);
  assert.doesNotMatch(observed.prompt, /Answer-only mode/);
  assert.equal(observed.args.includes('--tools'), false);
  assert.equal(observed.args.includes('--no-subagents'), false);
  assert.equal(observed.args.includes('--disable-web-search'), false);
});

test('answer-only is refused for the writing contributor role', async t => {
  const fixture = await setup(t);
  const target = path.join(fixture.dir, 'contributor-answer-only');
  const added = run('git', ['-C', fixture.repo, 'worktree', 'add', '--quiet', '--detach', target, 'HEAD']);
  assert.equal(added.status, 0, added.stderr);
  const result = run(fixture.wrapper, ['--prompt-file', fixture.prompt, '--model', 'grok-4.6',
    '--output', path.join(fixture.repo, 'tmp', 'results', 'answer-only-contributor.md'),
    '--timeout-sec', '30', '--role', 'contributor', '--allow-write',
    '--worktree-existing', target, '--answer-only'],
  { cwd: fixture.repo, env: { ...fixture.env, FAKE_CALL_INDEX: '99' } });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /--answer-only is unavailable for --role contributor/);
});

test('a turn-capped failure salvages model text instead of leaving no artifact', async t => {
  const fixture = await setup(t);
  const { result, output, failure } = await fixture.call({}, ['--role', 'critic', '--max-turns', '2']);
  assert.equal(result.status, 1, result.stderr);
  const retained = await manifest(failure);
  assert.equal(retained.terminal_reason, 'max_turns_reached');
  assert.equal(retained.session_evidence, 'retained');
  assert.equal(retained.partial_output, 'retained');
  const salvaged = await fs.readFile(`${output}.partial`, 'utf8');
  assert.match(salvaged, /SYNTHETIC_ASSISTANT_TEXT/);
  assert.match(salvaged, /SYNTHETIC_REASONING_TEXT/);
  // The empty assistant turn that only carried tool calls must not be emitted.
  assert.doesNotMatch(salvaged, /## assistant\n\n## /);
  assert.equal((await fs.stat(`${output}.partial`)).mode & 0o077, 0);
});

test('a refused session never salvages partial text', async t => {
  const fixture = await setup(t);
  const { result, output, failure } = await fixture.call({ unsafe: 'secret' }, ['--role', 'critic']);
  assert.equal(result.status, 1, result.stderr);
  const retained = await manifest(failure);
  assert.equal(retained.session_evidence, 'refused');
  assert.equal(retained.partial_output, 'none');
  assert.equal(await exists(`${output}.partial`), false);
});
