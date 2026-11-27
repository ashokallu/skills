import test from 'node:test';
import assert from 'node:assert/strict';
import { createMuseAcpMspTransport } from '../acp-msp-transport.mjs';

const pause = () => new Promise(resolve => setImmediate(resolve));
function fixture(handler = () => false, options = {}) {
  const queue = [], frames = [], output = [], pending = new Map();
  let wake, ended = false, id = 0, cursor = 0;
  const push = frame => { queue.push(JSON.stringify(frame) + '\n'); wake?.(); };
  const response = (frame, result) => push({ jsonrpc: '2.0', id: frame.id, result });
  const notify = (method, params) => push({ jsonrpc: '2.0', method,
    params: { sessionId: 'msp-session', viewCursor: `c${++cursor}`, ...params } });
  const transport = {
    incoming: { async *[Symbol.asyncIterator]() {
      while (!ended) {
        if (queue.length) {
          const chunk = queue.shift(); // Split Unicode and JSON across chunks.
          for (let i = 0; i < chunk.length; i += 7) yield chunk.slice(i, i + 7);
        } else await new Promise(resolve => { wake = resolve; });
      }
    } },
    async write(chunk) {
      const frame = JSON.parse(chunk); frames.push(frame);
      if (handler(frame, { response, notify, push, transport })) return;
      if (frame.method === 'initialize') {
        assert.match(frame.params.clientInfo.name, /^[a-z0-9_]+$/);
        assert.equal(frame.params.clientInfo.name, 'codex_desktop_muse_acp');
        response(frame, { schema: 'fixture', sessionDurability: 'durable' });
      }
      if (frame.method === 'session/start') response(frame, { session: { sessionId: 'msp-session',
        workspaceRoot: '/workspace', modelId: 'muse-spark-1.3-contributor', providerId: 'meta', status: 'idle' }, viewCursor: 'start' });
      if (frame.method === 'turn/start') response(frame, { commandId: frame.params.commandId,
        status: 'accepted', disposition: 'started', startedNewTurn: true, turnId: frame.params.commandId });
      if (frame.method === 'turn/cancel') response(frame, { commandId: frame.params.commandId,
        status: 'accepted', turnId: frame.params.turnId });
    },
    close() { ended = true; wake?.(); },
  };
  const bridge = createMuseAcpMspTransport({ transport, target: { workspaceRoot: '/workspace',
    modelId: 'muse-spark-1.3-contributor', effort: 'max' }, acceptInitialize: value => value.schema === 'fixture', ...options });
  bridge.onMessage(frame => {
    output.push(frame);
    const p = pending.get(frame.id);
    if (p) { pending.delete(frame.id); frame.error
      ? p.reject(Object.assign(Error(frame.error.message), { data: frame.error.data }))
      : p.resolve(frame.result); }
  });
  bridge.onClose(event => { for(const p of pending.values())p.reject(Error(event.reason)); pending.clear(); });
  const rpc = (method, params = {}) => new Promise((resolve, reject) => {
    const requestId = ++id; pending.set(requestId, { resolve, reject });
    bridge.send({ jsonrpc: '2.0', id: requestId, method, params });
  });
  const open = async () => { await rpc('initialize'); return (await rpc('session/new', { cwd: '/workspace', mcpServers: [] })).sessionId; };
  const prompt = sessionId => rpc('session/prompt', { sessionId, prompt: [{ type: 'text', text: 'fixture' }] });
  const text = () => output.filter(f => f.method === 'session/update').map(f => f.params.update.content.text).join('');
  return { bridge, frames, output, rpc, open, prompt, notify, push, transport, text };
}
function item(turnId, text, revision = 1, status = 'completed') {
  return { itemId: `i-${turnId}`, turnId, kind: 'agentMessage', revision, status, text };
}
async function activeTurn(f) {
  for (let i = 0; i < 20; i++) { await pause(); if (f.frames.some(x => x.method === 'turn/start')) break; }
  return f.frames.filter(x => x.method === 'turn/start').at(-1).params.commandId;
}
test('persistent connection preserves sequential turns and revision/delta text once', async t => {
  const f = fixture(); t.after(() => f.bridge.close()); const sid = await f.open();
  for (let n = 0; n < 2; n++) {
    const done = f.prompt(sid), tid = await activeTurn(f);
    f.notify('item/started', { item: item(tid, '', 1, 'inProgress') });
    f.notify('item/delta', { itemId: `i-${tid}`, delta: 'héllo 🌍' });
    f.notify('item/updated', { item: item(tid, 'héllo 🌍', 2, 'inProgress') });
    f.notify('item/completed', { item: item(tid, 'héllo 🌍', 3) });
    f.notify('turn/completed', { turnId: tid, terminal: 'completed' });
    assert.equal((await done).stopReason, 'end_turn');
  }
  assert.equal(f.text(), 'héllo 🌍héllo 🌍');
  assert.equal(f.frames.filter(x => x.method === 'session/start').length, 1);
});
test('durable host broadcasts and a failed turn preserve the session for a follow-up', async t => {
  const f = fixture((frame, io) => {
    if (frame.method !== 'session/start') return false;
    io.push({ jsonrpc: '2.0', method: 'session/started', params: {
      session: { sessionId: 'msp-session', status: 'idle' } } });
    io.notify('session/approvalModeChanged', { mode: 'denyUnmatched' });
    io.response(frame, { session: { sessionId: 'msp-session', workspaceRoot: '/workspace',
      modelId: 'muse-spark-1.3-contributor', providerId: 'meta', status: 'idle' },
    viewCursor: 'start' });
    return true;
  });
  t.after(() => f.bridge.close());
  const sid = await f.open();
  const failed = assert.rejects(f.prompt(sid), error => {
    assert.match(error.message, /Muse turn failed: authRequired/);
    assert.deepEqual(error.data, { completion: 'failed', kind: 'authRequired',
      retryable: false, sessionRetained: true });
    return true;
  });
  const first = await activeTurn(f);
  f.notify('session/statusChanged', { status: 'running', viewCursor: 'shared-running' });
  f.notify('turn/started', { turnId: first, commandId: first, viewCursor: 'shared-running' });
  f.notify('item/completed', { item: item(first, 'partial') });
  f.notify('session/statusChanged', { status: 'idle', viewCursor: 'shared-failed' });
  f.notify('turn/completed', { turnId: first, terminal: 'failed',
    error: { kind: 'authRequired', message: 'not logged in', retryable: false },
    viewCursor: 'shared-failed' });
  f.notify('session/statusChanged', { status: 'idle', viewCursor: 'shared-failed' });
  await failed;
  assert.equal(f.bridge.closed, false);
  const followUp = f.prompt(sid), second = await activeTurn(f);
  assert.notEqual(first, second);
  f.notify('item/completed', { item: item(second, 'recovered') });
  f.notify('turn/completed', { turnId: second, terminal: 'completed' });
  assert.equal((await followUp).stopReason, 'end_turn');
  assert.equal(f.text(), 'partialrecovered');
});
test('ephemeral Muse handshake cannot start an ACP session', async t => {
  const f = fixture((frame, io) => {
    if (frame.method !== 'initialize') return false;
    io.response(frame, { schema: 'fixture', sessionDurability: 'ephemeral' });
    return true;
  });
  t.after(() => f.bridge.close());
  await assert.rejects(f.open(), /durable handshake/);
  assert.equal(f.frames.some(x => x.method === 'session/start'), false);
});
test('events before turn ack and completion-only items are retained', async t => {
  const f = fixture((frame, io) => {
    if (frame.method !== 'turn/start') return false;
    const tid = frame.params.commandId;
    io.notify('item/completed', { item: item(tid, 'early') });
    io.notify('turn/completed', { turnId: tid, terminal: 'completed' });
    io.response(frame, { commandId: tid, status: 'accepted', disposition: 'started', startedNewTurn: true, turnId: tid }); return true;
  }); t.after(() => f.bridge.close());
  assert.equal((await f.prompt(await f.open())).stopReason, 'end_turn'); assert.equal(f.text(), 'early');
});
test('concurrent prompts reject without second command; cancellation waits terminal', async t => {
  const f = fixture(); t.after(() => f.bridge.close()); const sid = await f.open();
  const done = f.prompt(sid); const tid = await activeTurn(f);
  await assert.rejects(f.prompt(sid), /already active/);
  f.bridge.send({ jsonrpc: '2.0', method: 'session/cancel', params: { sessionId: sid } });
  await pause(); await pause();
  assert.equal(f.frames.filter(x => x.method === 'turn/start').length, 1);
  assert.equal(f.frames.filter(x => x.method === 'turn/cancel').length, 1);
  f.notify('turn/completed', { turnId: tid, terminal: 'cancelled' });
  assert.equal((await done).stopReason, 'cancelled');
});
test('cancel intent before ack cancels authoritative turn once', async t => {
  let held, io;
  const f = fixture((frame, api) => { if (frame.method === 'turn/start') { held = frame; io = api; return true; } return false; });
  t.after(() => f.bridge.close()); const sid = await f.open(); const done = f.prompt(sid);
  await activeTurn(f);
  f.bridge.send({ jsonrpc: '2.0', method: 'session/cancel', params: { sessionId: sid } });
  io.response(held, { commandId: held.params.commandId, status: 'accepted', disposition: 'started', startedNewTurn: true, turnId: 'authoritative' });
  for (let i = 0; i < 5; i++) await pause();
  assert.equal(f.frames.find(x => x.method === 'turn/cancel').params.turnId, 'authoritative');
  f.notify('turn/completed', { turnId: 'authoritative', terminal: 'cancelled' });
  assert.equal((await done).stopReason, 'cancelled');
});
test('retryable refusal produces exactly one MSP command', async t => {
  const f = fixture((frame, io) => {
    if (frame.method !== 'turn/start') return false;
    io.push({ jsonrpc: '2.0', id: frame.id, error: { code: -32001, message: 'busy', data: { kind: 'overloaded', retryable: true } } }); return true;
  }); t.after(() => f.bridge.close());
  await assert.rejects(f.prompt(await f.open()), /busy/);
  assert.equal(f.frames.filter(x => x.method === 'turn/start').length, 1); assert.equal(f.bridge.closed, true);
});
for (const fault of ['EOF', 'divergence', 'cursor', 'identity', 'truncated', 'gap', 'tool']) {
  test(`explicit partial failure on ${fault}`, async t => {
    const f = fixture(); t.after(() => f.bridge.close()); const done = f.prompt(await f.open());
    const rejected = assert.rejects(done); const tid = await activeTurn(f);
    f.notify('item/started', { item: item(tid, 'partial', 1, 'inProgress') });
    if (fault === 'EOF') { for(let i=0;i<4;i++)await pause(); f.transport.close(); }
    else if (fault === 'divergence') f.notify('item/completed', { item: item(tid, 'replacement', 2) });
    else if (fault === 'cursor') {
      f.notify('item/updated', { viewCursor: 'conflict', item: item(tid, 'partial', 2, 'inProgress') });
      f.notify('item/updated', { viewCursor: 'conflict', item: item(tid, 'different', 3, 'inProgress') });
    } else if (fault === 'identity') f.notify('turn/completed', { turnId: 'wrong', terminal: 'completed' });
    else if (fault === 'truncated') f.notify('item/completed', { item: { ...item(tid, 'partial', 2), truncated: true } });
    else if (fault === 'gap') f.notify('view/gap', {});
    else f.notify('item/started', { item: { ...item(tid, '', 2), kind: 'toolCall' } });
    await rejected; assert.equal(f.bridge.closed, true);
  });
}
test('duplicate ACP request identity closes and settles original caller', async t => {
  const f = fixture(); t.after(() => f.bridge.close()); const done = f.prompt(await f.open());
  const rejected = assert.rejects(done, /identity/); await activeTurn(f);
  f.bridge.send({ jsonrpc: '2.0', id: 3, method: 'session/prompt', params: {} });
  await rejected; assert.equal(f.bridge.closed, true);
});
test('acknowledgement stall is bounded', async t => {
  const f = fixture(frame => frame.method === 'turn/start', { timeoutMs: 20 });
  t.after(() => f.bridge.close()); await assert.rejects(f.prompt(await f.open()), /deadline/);
});
test('ID-bearing cancellation rejects immediately without issuing an MSP cancel', async t => {
  const f = fixture(); t.after(() => f.bridge.close()); const sessionId = await f.open();
  await assert.rejects(f.rpc('session/cancel', { sessionId }), /notification/);
  assert.equal(f.frames.some(x => x.method === 'turn/cancel'), false);
  assert.equal(f.bridge.closed, false);
});
test('oversized ACP input and too many early events fail boundedly', async t => {
  const f = fixture(); t.after(() => f.bridge.close()); const sessionId = await f.open();
  await assert.rejects(f.rpc('session/prompt', { sessionId, prompt: [{ type: 'text', text: 'x'.repeat(1024 * 1024) }] }));
  assert.equal(f.frames.some(x => x.method === 'turn/start'), false);
  const g = fixture((frame, io) => {
    if(frame.method !== 'turn/start')return false;
    for(let i=0;i<129;i++)io.notify('item/delta', {itemId:'early',delta:'x'});
    return true;
  }); t.after(()=>g.bridge.close());
  await assert.rejects(g.prompt(await g.open()), /early event bound/);
});
