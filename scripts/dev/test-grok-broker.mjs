import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import fs from 'node:fs/promises';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import test from 'node:test';
import { gzipSync } from 'node:zlib';

const wrapper = await fs.readFile(new URL('./agent-call-grok.sh', import.meta.url), 'utf8');
const source = wrapper.split('cat >"$broker_script" <<\'NODE\'\n')[1].split('\nNODE\n')[0];

// Mirrors the broker's own derivation so the cap is not restated as a literal:
// raising the turn budget must not read as a regression here.
function expectedProviderRequests(maxTurns) {
  return maxTurns + Math.ceil(maxTurns / 2) + 4;
}

async function broker(t, options = {}) {
  const { accelerated = false, maxTurns = 8, lifetimeMs = 1_800_000,
    upstreamBase = null } = options;
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'grok-broker-test-'));
  const socket = path.join(dir, 'broker.sock');
  const ready = path.join(dir, 'ready');
  // Accelerate only the fixture's clock, without production test-only deadlines.
  const clock = accelerated ? `
const realNow = Date.now;
const epoch = realNow();
Date.now = () => epoch + (realNow() - epoch) * 1000;
const realTimeout = globalThis.setTimeout;
globalThis.setTimeout = (fn, ms, ...args) => realTimeout(fn, ms / 1000, ...args);
` : '';
  const brokerSource = upstreamBase === null ? source
    : source.replace('https://cli-chat-proxy.grok.com/', `${upstreamBase}/`);
  if (upstreamBase !== null) assert.notEqual(brokerSource, source);
  await fs.writeFile(path.join(dir, 'broker.mjs'), clock + brokerSource);
  await fs.writeFile(path.join(dir, 'auth.json'), '{"key":"fixture-credential"}');
  const child = spawn(process.execPath, [path.join(dir, 'broker.mjs')], {
    env: { PATH: process.env.PATH, PROVIDER_AUTH_FILE: path.join(dir, 'auth.json'),
      BROKER_SOCKET_PATH: socket, BROKER_READY_FILE: ready,
      BROKER_AUDIT_FILE: path.join(dir, 'audit'), BROKER_TEST_MODE: upstreamBase === null ? '1' : '0',
      BROKER_LIFETIME_MS: String(lifetimeMs), BROKER_MAX_TURNS: String(maxTurns) },
    stdio: ['ignore', 'ignore', 'pipe'],
  });
  let stderr = '';
  child.stderr.on('data', chunk => { stderr += chunk; });
  async function stop() {
    if (child.exitCode === null && child.signalCode === null) {
      const exited = once(child, 'exit'); child.kill('SIGTERM'); await exited;
    }
  }
  async function audit() {
    return (await fs.readFile(path.join(dir, 'audit'), 'utf8')).trim().split('\n').filter(Boolean).map(JSON.parse);
  }
  t.after(async () => {
    await stop();
    assert.equal(stderr, '');
    await fs.rm(dir, { recursive: true, force: true });
  });
  for (let i = 0; i < 100; i++) {
    if (await fs.stat(ready).catch(() => false)) return { child, socket, dir, stop, audit };
    if (child.exitCode !== null) throw new Error(`broker exited: ${stderr}`);
    await sleep(10);
  }
  throw new Error('broker readiness timeout');
}

function request(socket, body, route = '/provider/v1/chat/completions') {
  return new Promise((resolve, reject) => {
    const req = http.request({ socketPath: socket, path: route, method: body === undefined ? 'GET' : 'POST', agent: false }, res => {
      let text = '';
      res.on('data', chunk => { text += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, text }));
      res.on('aborted', () => reject(new Error('response aborted')));
      res.on('error', reject);
    });
    req.on('error', reject);
    req.end(body);
  });
}

function observeRequest(socket, body, route = '/provider/v1/chat/completions') {
  return new Promise(resolve => {
    let settled = false;
    const finish = value => { if (!settled) { settled = true; resolve(value); } };
    const req = http.request({ socketPath: socket, path: route,
      method: body === undefined ? 'GET' : 'POST', agent: false }, res => {
      const chunks = [];
      const base = () => ({ status: res.statusCode, headers: res.headers,
        body: Buffer.concat(chunks) });
      res.on('data', chunk => { chunks.push(chunk); });
      res.on('end', () => finish({ ...base(), outcome: 'complete' }));
      res.on('aborted', () => finish({ ...base(), outcome: 'aborted' }));
      res.on('error', error => finish({ ...base(), outcome: 'error', error: error.code || error.name }));
    });
    req.on('error', error => finish({ status: null, headers: {}, body: Buffer.alloc(0),
      outcome: 'request_error', error: error.code || error.name }));
    req.end(body);
  });
}

function abortAfterFirstChunk(socket, body) {
  return new Promise((resolve, reject) => {
    const req = http.request({ socketPath: socket, path: '/provider/v1/chat/completions',
      method: 'POST', agent: false }, res => {
      res.once('data', chunk => {
        const result = { status: res.statusCode, bytes: chunk.length };
        res.destroy();
        resolve(result);
      });
      res.on('error', () => {});
    });
    req.on('error', reject);
    req.end(body);
  });
}

async function httpUpstream(t, handler) {
  const server = http.createServer(handler);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

async function rawUpstream(t, responder) {
  const server = net.createServer(socket => {
    let received = Buffer.alloc(0);
    socket.on('data', chunk => {
      received = Buffer.concat([received, chunk]);
      if (!received.includes(Buffer.from('\r\n\r\n'))) return;
      socket.removeAllListeners('data');
      responder(socket);
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

function providerBody(bytes) {
  const prefix = '{"model":"grok-4.6","prompt":"';
  const suffix = '"}';
  assert.ok(bytes >= Buffer.byteLength(prefix + suffix));
  const body = prefix + 'x'.repeat(bytes - Buffer.byteLength(prefix + suffix)) + suffix;
  assert.equal(Buffer.byteLength(body), bytes);
  return body;
}

function toolBody(id = 1) {
  return JSON.stringify({ jsonrpc: '2.0', id, method: 'tools/call',
    params: { name: 'web_fetch', arguments: { url: 'https://example.invalid' } } });
}

test('single oversized request is rejected, fully accounted, and does not poison later admission', async t => {
  const instance = await broker(t, { maxTurns: 1 });
  const start = (await instance.audit()).find(event => event.event === 'start');
  const oversized = providerBody(start.limits.requestBody + 1);
  const rejected = await request(instance.socket, oversized);
  assert.equal(rejected.status, 413);
  assert.match(rejected.text, /request body limit exceeded/);
  const small = providerBody(1024);
  assert.equal((await request(instance.socket, small)).status, 200);
  assert.equal(instance.child.exitCode, null);
  await instance.stop();
  const stopped = (await instance.audit()).find(event => event.event === 'stop');
  assert.equal(stopped.usage.request, oversized.length + small.length);
  assert.equal(stopped.usage.requestRejected, oversized.length);
  assert.equal(stopped.usage.requestAccepted, small.length);
  assert.equal(stopped.usage.providerRequest, small.length);
});

test('bounded repeated-context growth is admitted for nine selected rounds', async t => {
  const instance = await broker(t, { maxTurns: 9 });
  const sizes = Array.from({ length: 9 }, (_, index) => (128 + index * 64) * 1024);
  for (const size of sizes) assert.equal((await request(instance.socket, providerBody(size))).status, 200);
  await instance.stop();
  const events = await instance.audit();
  const start = events.find(event => event.event === 'start');
  const stopped = events.find(event => event.event === 'stop');
  assert.equal(start.limits.providerRequestBytes, 6656 * 1024);
  assert.equal(stopped.usage.providerRequest, sizes.reduce((sum, size) => sum + size, 0));
  assert.ok(stopped.usage.providerRequest < start.limits.providerRequestBytes);
  assert.equal(stopped.usage.requestRejected, 0);
});

test('exact per-request and cumulative boundaries are accepted and the next body is rejected', async t => {
  const perRequest = await broker(t, { maxTurns: 1 });
  assert.equal((await request(perRequest.socket, providerBody(2 * 1024 * 1024))).status, 200);
  await perRequest.stop();
  const exactPerStop = (await perRequest.audit()).find(event => event.event === 'stop');
  assert.equal(exactPerStop.usage.providerRequest, 2 * 1024 * 1024);

  const cumulative = await broker(t, { maxTurns: 2 });
  assert.equal((await request(cumulative.socket, providerBody(1024 * 1024))).status, 200);
  assert.equal((await request(cumulative.socket, providerBody(2 * 1024 * 1024))).status, 200);
  const rejected = await request(cumulative.socket, providerBody(1024));
  assert.equal(rejected.status, 413);
  assert.match(rejected.text, /provider cumulative request budget exceeded/);
  await cumulative.stop();
  const exactCumulativeStop = (await cumulative.audit()).find(event => event.event === 'stop');
  assert.equal(exactCumulativeStop.usage.providerRequest, 3 * 1024 * 1024);
  assert.equal(exactCumulativeStop.usage.requestRejected, 1024);
});

test('concurrent bodies cannot multiply the cumulative provider allowance', async t => {
  const instance = await broker(t, { maxTurns: 1 });
  const body = providerBody(768 * 1024);
  const results = await Promise.all(Array.from({ length: 4 }, () => request(instance.socket, body)));
  assert.deepEqual(results.map(result => result.status).sort(), [200, 200, 200, 413]);
  await instance.stop();
  const stopped = (await instance.audit()).find(event => event.event === 'stop');
  assert.equal(stopped.usage.providerRequest, 2304 * 1024);
  assert.equal(stopped.usage.requestAccepted, 2304 * 1024);
  assert.equal(stopped.usage.requestRejected, 768 * 1024);
});

test('configured lifetime survives former five-minute cutoff and still expires', async t => {
  const { socket, child } = await broker(t, { accelerated: true });
  await sleep(500);
  assert.equal((await request(socket, undefined, '/provider/v1/models')).status, 200);
  const exited = once(child, 'exit');
  const result = await Promise.race([exited, sleep(2500).then(() => { throw new Error('deadline not enforced'); })]);
  assert.equal(result[0], 0);
  await assert.rejects(request(socket));
});

test('model and route admission remain fail closed', async t => {
  const { socket } = await broker(t);
  assert.equal((await request(socket, '{"model":"other"}')).status, 403);
  assert.equal((await request(socket, undefined, '/unavailable')).status, 404);
  assert.equal((await request(socket, '{"model":"grok-4.6"}')).status, 200);
});

test('provider count, MCP tool count, response, and tool-output ceilings are independent', async t => {
  const count = await broker(t);
  const providerCap = expectedProviderRequests(8);
  for (let i = 0; i < providerCap; i++) {
    assert.equal((await request(count.socket, undefined, '/provider/v1/models')).status, 200);
  }
  const providerRejected = await request(count.socket, undefined, '/provider/v1/models');
  assert.equal(providerRejected.status, 429);
  assert.match(providerRejected.text, /provider request budget exceeded/);

  const tools = await broker(t);
  for (let i = 0; i < 8; i++) assert.equal((await request(tools.socket, toolBody(i), '/parallel')).status, 200);
  const toolRejected = await request(tools.socket, toolBody(9), '/parallel');
  assert.equal(toolRejected.status, 429);
  assert.match(toolRejected.text, /MCP tool budget exceeded/);
  assert.equal((await request(tools.socket,
    JSON.stringify({ jsonrpc: '2.0', id: 10, method: 'ping' }), '/parallel')).status, 200);

  const response = await broker(t);
  assert.equal((await request(response.socket, providerBody(64),
    '/provider/v1/chat/completions?test_response_bytes=20971520')).status, 200);
  await assert.rejects(request(response.socket, providerBody(64),
    '/provider/v1/chat/completions?test_response_bytes=1'), /response aborted|socket hang up/);
  const responseEvents = await response.audit();
  assert.equal(responseEvents.find(event => event.event === 'response_rejected').reason,
    'response budget exceeded');

  const toolOutput = await broker(t);
  await assert.rejects(request(toolOutput.socket,
    JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize' }),
    '/parallel?test_response_bytes=1048577'), /response aborted|socket hang up/);
  const toolEvents = await toolOutput.audit();
  assert.equal(toolEvents.find(event => event.event === 'response_rejected').reason,
    'remote response body limit exceeded');

  const remoteCumulative = await broker(t);
  const initialize = JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize' });
  for (let i = 0; i < 4; i++) {
    assert.equal((await request(remoteCumulative.socket, initialize,
      '/parallel?test_response_bytes=1048576')).status, 200);
  }
  await assert.rejects(request(remoteCumulative.socket, initialize,
    '/parallel?test_response_bytes=1'), /response aborted|socket hang up/);
  const remoteEvents = await remoteCumulative.audit();
  assert.equal(remoteEvents.find(event => event.event === 'response_rejected').reason,
    'remote response budget exceeded');
});

test('fake upstream streams successful chunked SSE with exact terminal evidence', async t => {
  const sse = 'data: {"delta":"one"}\n\ndata: [DONE]\n\n';
  const upstreamBase = await httpUpstream(t, (req, res) => {
    req.resume();
    req.on('end', () => {
      res.writeHead(200, { 'content-type': 'text/event-stream' });
      res.write(sse.slice(0, 17));
      res.end(sse.slice(17));
    });
  });
  const instance = await broker(t, { upstreamBase });
  const result = await request(instance.socket, providerBody(64));
  assert.equal(result.status, 200);
  assert.equal(result.text, sse);
  await instance.stop();
  const events = await instance.audit();
  const upstream = events.find(event => event.event === 'upstream');
  const terminal = events.find(event => event.event === 'request_terminal');
  assert.equal(upstream.status, 200);
  assert.ok(upstream.headerNames.includes('transfer-encoding'));
  assert.equal(terminal.outcome, 'completed');
  assert.equal(Number.isSafeInteger(terminal.elapsedMs), true);
  assert.equal(terminal.responseBytes, Buffer.byteLength(sse));
  assert.equal(terminal.downstreamHeadersSent, true);
});

test('fetch-decoded gzip omits transformed encoding and length downstream', async t => {
  const sse = 'data: {"delta":"compressed"}\n\ndata: [DONE]\n\n';
  const compressed = gzipSync(Buffer.from(sse));
  const upstreamBase = await httpUpstream(t, (req, res) => {
    req.resume();
    req.on('end', () => {
      res.writeHead(200, { 'content-type': 'text/event-stream',
        'content-encoding': 'gzip', 'content-length': compressed.length });
      res.end(compressed);
    });
  });
  const instance = await broker(t, { upstreamBase });
  const result = await request(instance.socket, providerBody(64));
  assert.equal(result.status, 200);
  assert.equal(result.text, sse);
  assert.equal(result.headers['content-encoding'], undefined);
  assert.equal(result.headers['content-length'], undefined);
  await instance.stop();
  const terminal = (await instance.audit()).find(event => event.event === 'request_terminal');
  assert.equal(terminal.contentCoding, 'gzip');
  assert.ok(terminal.upstreamHeaderNames.includes('content-encoding'));
  assert.ok(terminal.upstreamHeaderNames.includes('content-length'));
  assert.deepEqual(terminal.forwardedHeaderNames, ['content-type']);
  assert.equal(terminal.responseBytes, Buffer.byteLength(sse));
});

test('truncated compressed upstream body fails after HTTP 200 without a second response', async t => {
  const compressed = gzipSync(Buffer.from(`data: ${'x'.repeat(4096)}\n\n`));
  const upstreamBase = await rawUpstream(t, socket => {
    const partial = compressed.subarray(0, Math.max(1, Math.floor(compressed.length / 2)));
    socket.write('HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nContent-Encoding: gzip\r\n' +
      `Content-Length: ${compressed.length}\r\n\r\n`);
    socket.end(partial);
  });
  const instance = await broker(t, { upstreamBase });
  const result = await observeRequest(instance.socket, providerBody(64));
  assert.equal(result.status, 200);
  assert.notEqual(result.outcome, 'complete');
  assert.doesNotMatch(result.body.toString(), /"error"/);
  await instance.stop();
  const events = await instance.audit();
  const terminal = events.find(event => event.event === 'request_terminal');
  assert.equal(terminal.terminalReason, 'upstream_response_stream_failed');
  assert.equal(terminal.transportCategory, 'upstream_socket_closed');
  assert.equal(terminal.contentCoding, 'gzip');
  assert.equal(terminal.status, 200);
  assert.equal(terminal.downstreamHeadersSent, true);
  assert.equal(events.filter(event => event.event === 'request_terminal').length, 1);
  assert.equal(events.some(event => event.event === 'rejected' && event.requestId === terminal.requestId), false);
});

test('corrupt compressed body is classified as upstream response decoding failure', async t => {
  const corrupt = Buffer.from('not-a-valid-gzip-stream');
  const upstreamBase = await httpUpstream(t, (req, res) => {
    req.resume();
    req.on('end', () => {
      res.writeHead(200, { 'content-type': 'text/event-stream',
        'content-encoding': 'gzip', 'content-length': corrupt.length });
      res.end(corrupt);
    });
  });
  const instance = await broker(t, { upstreamBase });
  const result = await observeRequest(instance.socket, providerBody(64));
  assert.equal(result.status, 200);
  assert.notEqual(result.outcome, 'complete');
  await instance.stop();
  const terminal = (await instance.audit()).find(event => event.event === 'request_terminal');
  assert.equal(terminal.terminalReason, 'upstream_response_decode_failed');
  assert.equal(terminal.transportCategory, 'compressed_body_decode');
  assert.equal(terminal.phase, 'upstream_response_stream');
});

test('upstream reset is distinguished before headers and after response streaming begins', async t => {
  const beforeBase = await rawUpstream(t, socket => socket.destroy());
  const before = await broker(t, { upstreamBase: beforeBase });
  const beforeResult = await request(before.socket, providerBody(64));
  assert.equal(beforeResult.status, 502);
  assert.match(beforeResult.text, /upstream response headers failed/);
  await before.stop();
  const beforeTerminal = (await before.audit()).find(event => event.event === 'request_terminal');
  assert.equal(beforeTerminal.terminalReason, 'upstream_response_headers_failed');
  assert.equal(beforeTerminal.phase, 'upstream_response_headers');
  assert.equal(beforeTerminal.upstreamStatus, null);
  assert.equal(beforeTerminal.downstreamHeadersSent, false);

  const afterBase = await rawUpstream(t, socket => {
    socket.write('HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n' +
      'f\r\ndata: partial\n\n\r\n');
    setTimeout(() => socket.destroy(), 10);
  });
  const after = await broker(t, { upstreamBase: afterBase });
  const afterResult = await observeRequest(after.socket, providerBody(64));
  assert.equal(afterResult.status, 200);
  assert.notEqual(afterResult.outcome, 'complete');
  assert.doesNotMatch(afterResult.body.toString(), /"error"/);
  await after.stop();
  const afterEvents = await after.audit();
  const afterTerminal = afterEvents.find(event => event.event === 'request_terminal');
  assert.equal(afterTerminal.terminalReason, 'upstream_response_stream_failed');
  assert.equal(afterTerminal.transportCategory, 'upstream_socket_closed');
  assert.equal(afterTerminal.upstreamStatus, 200);
  assert.equal(afterTerminal.downstreamHeadersSent, true);
  assert.equal(afterEvents.filter(event => event.requestId === afterTerminal.requestId &&
    event.event === 'request_failed').length, 1);
  assert.equal(afterEvents.some(event => event.requestId === afterTerminal.requestId &&
    event.event === 'rejected'), false);
});

test('downstream bridge closure aborts upstream work and receives its own terminal reason', async t => {
  const upstreamBase = await httpUpstream(t, (req, res) => {
    req.resume();
    req.on('end', () => {
      res.writeHead(200, { 'content-type': 'text/event-stream' });
      res.write('data: first\n\n');
      setTimeout(() => res.end('data: late\n\n'), 500);
    });
  });
  const instance = await broker(t, { upstreamBase });
  const result = await abortAfterFirstChunk(instance.socket, providerBody(64));
  assert.equal(result.status, 200);
  assert.ok(result.bytes > 0);
  let terminal = null;
  for (let i = 0; i < 100 && !terminal; i++) {
    terminal = (await instance.audit()).find(event => event.event === 'request_terminal');
    if (!terminal) await sleep(10);
  }
  assert.ok(terminal);
  assert.equal(terminal.terminalReason, 'downstream_response_closed');
  assert.equal(terminal.transportCategory, 'downstream_socket_closed');
  assert.equal(terminal.downstreamClosed, true);
  assert.ok(terminal.downstreamClosePhase);
});

test('malformed chunk framing is classified and correlated after an expected route probe', async t => {
  const upstreamBase = await rawUpstream(t, socket => {
    socket.end('HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n' +
      'Z\r\ndata: malformed\n\n\r\n0\r\n\r\n');
  });
  const instance = await broker(t, { upstreamBase });
  const probe = await request(instance.socket, undefined, '/unavailable');
  assert.equal(probe.status, 404);
  const failed = await observeRequest(instance.socket, providerBody(64));
  assert.equal(failed.status, 200);
  assert.notEqual(failed.outcome, 'complete');
  await instance.stop();
  const terminals = (await instance.audit()).filter(event => event.event === 'request_terminal');
  assert.equal(terminals.length, 2);
  assert.deepEqual(terminals.map(event => event.requestId), [1, 2]);
  assert.equal(terminals[0].terminalReason, 'broker_probe_rejected');
  assert.equal(terminals[0].route, null);
  assert.equal(terminals[1].terminalReason, 'upstream_response_stream_failed');
  assert.equal(terminals[1].transportCategory, 'upstream_http_framing');
  assert.equal(terminals[1].route, 'provider');
  assert.equal(terminals[1].status, 200);
});


test('isolated TCP/Unix bridge delivers a response and reaps its namespace', async t => {
  const { socket } = await broker(t);
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'grok-bridge-test-'));
  const launcher = wrapper.split('cat >"$namespace_launcher" <<\'SH\'\n')[1].split('\nSH\n')[0];
  await fs.writeFile(path.join(dir, 'launch.sh'), launcher);
  const probe = `import http.client
c = http.client.HTTPConnection('127.0.0.1', 38117, timeout=5)
c.request('POST', '/provider/v1/chat/completions', '{"model":"grok-4.6"}')
r = c.getresponse()
assert r.status == 200, r.status
assert b'grok-4.6' in r.read()
c.close()
`;
  const child = spawn('bwrap', ['--unshare-net', '--unshare-pid', '--die-with-parent',
    '--ro-bind', '/usr', '/usr', '--symlink', 'usr/bin', '/bin',
    '--symlink', 'usr/lib', '/lib', '--symlink', 'usr/lib64', '/lib64',
    '--proc', '/proc', '--dev', '/dev', '--dir', '/run',
    '--ro-bind', socket, '/run/grok-broker.sock',
    '--ro-bind', path.join(dir, 'launch.sh'), '/launch.sh',
    '/bin/sh', '/launch.sh', '/usr/bin/python3', '-c', probe],
    { stdio: ['ignore', 'pipe', 'pipe'] });
  let stderr = '';
  child.stderr.on('data', chunk => { stderr += chunk; });
  t.after(async () => {
    if (child.exitCode === null && child.signalCode === null) {
      const exited = once(child, 'exit'); child.kill(); await exited;
    }
    await fs.rm(dir, { recursive: true, force: true });
  });
  const [code] = await once(child, 'exit');
  assert.equal(code, 0, stderr);
  assert.throws(() => process.kill(child.pid, 0), { code: 'ESRCH' });
});
