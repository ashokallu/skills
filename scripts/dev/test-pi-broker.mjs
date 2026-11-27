// Fake transport only. The production controller has no transport override.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import test from 'node:test';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { startBroker, validateBody, validateResponse } from './pi-broker.mjs';

const model = 'gpt-5.6-luna';
const body = { model, store: false, stream: true, input: [], reasoning: { effort: 'medium' } };
const event = (overrides = {}) => ({ type: 'response.completed', response: {
  model, status: 'completed', usage: { input_tokens: 2, output_tokens: 1, total_tokens: 3 },
  output: [{ type: 'message', content: [{ type: 'output_text', text: 'public-result' }] }], ...overrides
} });
const sse = value => Buffer.from(`data: ${JSON.stringify(value)}\n\n`);

test('request decompression and exact allowlist', () => {
  const raw = Buffer.from(JSON.stringify(body));
  assert.deepEqual(validateBody(raw, undefined, model, 'medium', 1024), body);
  assert.deepEqual(validateBody(zlib.zstdCompressSync(raw), 'zstd', model, 'medium', 1024), body);
  assert.throws(() => validateBody(raw, undefined, model, undefined, 1024));
  for (const override of [{ model: 'other' }, { store: true }, { stream: false },
    { tools: [{ type: 'web_search' }] }, { previous_response_id: 'other' }, { background: true },
    { arbitrary_field: true }, { reasoning: { effort: 'low' } }, { reasoning: {} }]) {
    assert.throws(() => validateBody(Buffer.from(JSON.stringify({ ...body, ...override })),
      undefined, model, 'medium', 1024));
  }
  assert.throws(() => validateBody(zlib.zstdCompressSync(Buffer.alloc(2048)), 'zstd', model, 'medium', 1024));
  assert.throws(() => validateBody(raw, 'gzip', model, 'medium', 1024));
  assert.throws(() => validateBody(Buffer.from('{'), undefined, model, 'medium', 1024));
});

test('SSE terminal identity and usage fail closed', () => {
  assert.equal(validateResponse(sse(event()), model).text_sha256,
    crypto.createHash('sha256').update('public-result').digest('hex'));
  for (const overrides of [{ model: 'other' }, { status: 'incomplete' },
    { usage: {} }, { usage: { input_tokens: -1, output_tokens: 1, total_tokens: 0 } },
    { usage: { input_tokens: 1, output_tokens: 1, total_tokens: 9 } }]) {
    assert.throws(() => validateResponse(sse(event(overrides)), model));
  }
  assert.throws(() => validateResponse(Buffer.concat([sse(event()), sse(event())]), model));
  assert.throws(() => validateResponse(sse({ type: 'error' }), model));
  assert.throws(() => validateResponse(Buffer.from('data: {\n\n'), model));
  assert.throws(() => validateResponse(Buffer.concat([
    sse({ type: 'response.created', response: { model: 'other' } }), sse(event())]), model));
  const done = { type: 'response.output_item.done', output_index: 0,
    item: { type: 'message', content: [{ type: 'output_text', text: 'public-result' }] } };
  assert.equal(validateResponse(Buffer.concat([sse(done), sse(event({ output: [] }))]), model).text_sha256,
    validateResponse(sse(event()), model).text_sha256);
  assert.throws(() => validateResponse(Buffer.concat([sse(done), sse(done), sse(event())]), model));
  assert.throws(() => validateResponse(Buffer.concat([sse(done), sse(event({ output: [
    { type: 'message', content: [{ type: 'output_text', text: 'different' }] }
  ] }))]), model));
});

function request(socketPath, value, route = '/codex/responses', headers = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({ socketPath, path: route, method: 'POST', headers, agent: false }, res => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }));
    });
    req.on('error', reject); req.end(JSON.stringify(value));
  });
}

async function fixture(callback, options = {}) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../tmp/pi-broker-tests');
  fs.mkdirSync(root, { recursive: true });
  const directory = fs.mkdtempSync(`${root}/case-`);
  // Linux unix paths are limited to 108 bytes; bind relative to this process cwd.
  const original = process.cwd(); process.chdir(directory);
  const config = { model, effort: 'medium', provider_effort: 'medium',
    max_requests: 2, max_tokens: 10, max_request_bytes: 1024,
    max_response_bytes: 4096, timeout_sec: 5, socket: 'socket', audit: path.join(directory, 'audit.json'),
    session_id: crypto.randomUUID(), ...options };
  const publicToken = `public.${Buffer.from(JSON.stringify({
    'https://api.openai.com/auth': { chatgpt_account_id: 'public-account-canary' }
  })).toString('base64url')}.fixture`;
  let calls = 0;
  const transport = async (url, init) => {
    calls++;
    assert.equal(JSON.parse(fs.readFileSync(config.audit)).status, 'inflight');
    assert.equal(url, 'https://chatgpt.com/backend-api/codex/responses');
    assert.equal(init.redirect, 'error');
    assert.equal(init.headers.authorization, `Bearer ${publicToken}`);
    assert.equal(init.headers['chatgpt-account-id'], 'public-account-canary');
    assert.equal(init.headers['session-id'], config.session_id);
    if (options.delay) await new Promise(resolve => setTimeout(resolve, 50));
    return new Response(options.response || sse(event()), { status: options.status || 200 });
  };
  const server = startBroker(config, { type: 'oauth', access: publicToken, expires: Date.now() + 60000 }, transport);
  await new Promise(resolve => server.once('listening', resolve));
  try { await callback({ config, calls: () => calls, read: () => JSON.parse(fs.readFileSync(config.audit)) }); }
  finally {
    await new Promise(resolve => server.close(resolve));
    process.chdir(original); fs.rmSync(directory, { recursive: true });
  }
}

test('broker replaces caller credentials and reserves requests before forwarding', async () => {
  await fixture(async ({ calls, read }) => {
    assert.equal((await request('socket', body, '/codex/responses', {
      authorization: 'Bearer child-value', 'chatgpt-account-id': 'child-account'
    })).status, 200);
    assert.equal(read().total_tokens, 3);
    assert.equal(read().requested_effort, 'medium');
    assert.equal(read().attempts[0].effective_effort, 'medium');
    assert.equal((await request('socket', body)).status, 200);
    assert.equal((await request('socket', body)).status, 403);
    assert.equal(calls(), 2); assert.equal(read().status, 'failed');
  });
});

test('invalid routes, model mismatch and upstream failure poison the session', async () => {
  for (const options of [{ route: '/wrong' }, { value: { ...body, model: 'other' } },
    { response: sse(event({ model: 'other' })) }, { status: 429 },
    { response: Buffer.alloc(5000) }]) {
    await fixture(async ({ read }) => {
      assert.equal((await request('socket', options.value || body, options.route)).status, 403);
      assert.equal(read().status, 'failed');
      assert.equal((await request('socket', body)).status, 403);
      assert.equal(read().requests, 1);
    }, options);
  }
});

test('concurrency and cumulative admission cannot multiply request budget', async () => {
  await fixture(async ({ calls, read }) => {
    const results = await Promise.all([request('socket', body), request('socket', body)]);
    assert.deepEqual(results.map(result => result.status), [403, 403]);
    assert.equal(calls(), 1); assert.equal(read().status, 'failed');
  }, { delay: true });
  await fixture(async ({ calls }) => {
    assert.equal((await request('socket', body)).status, 403);
    assert.equal(calls(), 0);
  }, { prior_requests: 2 });
  await fixture(async ({ calls }) => {
    assert.equal((await request('socket', body)).status, 200);
    assert.equal((await request('socket', body)).status, 403);
    assert.equal(calls(), 1);
  }, { prior_tokens: 9 });
});

test('upstream credential echoes never reach the child or audit', async () => {
  await fixture(async ({ read }) => {
    const response = await request('socket', body);
    assert.equal(response.status, 403);
    assert.equal(read().reason, 'credential-echo');
    assert.ok(!response.body.includes('public-account-canary'));
    assert.ok(!JSON.stringify(read()).includes('public-account-canary'));
  }, { response: Buffer.from('public-account-canary') });
});
