// Provider-free persistent protocol slice. No process, credentials, registration,
// write permission, resume, or cleanup attestation is supplied by this module.
import { Connection, SessionFold } from '@muse-code/sdk';
import { createHash, randomUUID } from 'node:crypto';

const idString = value => typeof value === 'string' && value.length > 0 && value.length <= 256;
const bytes = value => Buffer.byteLength(JSON.stringify(value));
const frameLimit = 1024 * 1024;

export function createMuseAcpMspTransport({ transport, target, acceptInitialize,
  timeoutMs = 120_000, handshakeMs = 15_000, cancelMs = 5000 }) {
  if (!target || !idString(target.workspaceRoot) || !target.workspaceRoot.startsWith('/') ||
      target.modelId !== 'muse-spark-1.3-contributor' || target.effort !== 'max' ||
      typeof acceptInitialize !== 'function' ||
      ![timeoutMs, handshakeMs, cancelMs].every(n => Number.isInteger(n) && n > 0 && n <= 120_000))
    throw new TypeError('Exact host target and handshake acceptance required');
  target = Object.freeze({ ...target });
  const connection = new Connection(transport, { frameLimitBytes: frameLimit });
  let message = () => {}, onClose = () => {}, closed = false, state = 'new';
  let sessionId, acpSessionId, active, starting = false;
  let retainedBytes = 0, emittedBytes = 0;
  const pending = new Set(), ids = new Set(), cursors = new Map(), early = [];
  const reply = (id, result) => { if (!closed && pending.delete(id)) message({ jsonrpc: '2.0', id, result }); };
  const reject = (id, reason, code = -32602, data) => {
    if (!closed && pending.delete(id)) message({ jsonrpc: '2.0', id,
      error: { code, message: reason, ...(data ? { data } : {}) } });
  };
  function close(reason = 'Muse protocol closed; completion unproved') {
    if (closed) return;
    for (const id of [...pending]) reject(id, reason, -32000,
      { completion: 'unproved', sessionRetained: false });
    closed = true;
    clearTimeout(active?.timer); clearTimeout(active?.cancelTimer);
    active = null;
    void connection.close().catch(() => {});
    onClose({ reason, partial: emittedBytes > 0, emittedBytes });
  }
  async function bounded(promise, ms) {
    let timer;
    try { return await Promise.race([promise, new Promise((_, reject) => {
      timer = setTimeout(() => reject(Error('Muse acknowledgement deadline exceeded')), ms);
    })]); } finally { clearTimeout(timer); }
  }
  async function command(method, params) {
    const commandId = connection.mintCommandId();
    const result = await connection.command(method, params, { commandId, maxAttempts: 1 });
    if (closed) throw Error('Muse connection closed');
    return { result, commandId };
  }
  async function cancel() {
    if (!active) return;
    const turn = active;
    turn.cancelWanted = true;
    if (!turn.turnId || turn.cancelSent) return;
    turn.cancelSent = true;
    turn.cancelTimer = setTimeout(() => close('Muse cancellation terminal unproved'), cancelMs);
    const { result, commandId } = await command('turn/cancel', { sessionId, turnId: turn.turnId });
    if (result.commandId !== commandId || result.status !== 'accepted' || result.turnId !== turn.turnId)
      throw Error('Muse cancellation identity changed');
  }
  function drain() {
    for (const event of early.splice(0)) eventReceived(event, true);
  }
  function emitItems(turn) {
    for (const item of turn.fold.items.list()) {
      if (item.kind !== 'agentMessage') continue;
      const delta = turn.fold.items.accumulated(item.itemId, 'text');
      const full = item.text ?? '';
      const before = turn.emitted.get(item.itemId) ?? '';
      if (typeof full !== 'string' || (delta !== undefined && !full.startsWith(delta) && !delta.startsWith(full)))
        throw Error('Muse snapshot and delta diverged');
      const complete = turn.completed.has(item.itemId);
      const text = complete ? full : delta !== undefined && delta.length > full.length ? delta : full;
      if (!text.startsWith(before) || (complete && delta !== undefined && full !== delta))
        throw Error('Muse authoritative text retracted streamed output');
      const suffix = text.slice(before.length);
      if (emittedBytes + Buffer.byteLength(suffix) > 8 * frameLimit) throw Error('Muse output bound exceeded');
      if (suffix) {
        emittedBytes += Buffer.byteLength(suffix);
        turn.emitted.set(item.itemId, text);
        message({ jsonrpc: '2.0', method: 'session/update', params: { sessionId: acpSessionId,
          update: { sessionUpdate: 'agent_message_chunk', content: { type: 'text', text: suffix } } } });
      }
      if (!complete) break; // Preserve first-opened order across messages.
    }
  }
  function eventReceived(event, buffered = false) {
    if (closed) return;
    const { method, params: p } = event;
    if (!p || bytes(event) > frameLimit) throw Error('Invalid Muse event');
    if (!buffered) {
      retainedBytes += bytes(event);
      if (retainedBytes > 8 * frameLimit) throw Error('Muse retained event bound exceeded');
    }
    if ((starting && !sessionId) || (active && !active.turnId)) {
      if (early.length >= 128) throw Error('Muse early event bound exceeded');
      early.push(event); return;
    }
    if (method === 'session/started') {
      if (!sessionId || p.session?.sessionId !== sessionId) throw Error('Muse started session changed');
      return;
    }
    if (!sessionId || p.sessionId !== sessionId) throw Error('Muse event session changed');
    // These host broadcasts are not turn events. In particular, statusChanged
    // shares the cursor of its causing view event and may arrive after terminal.
    if (method === 'session/statusChanged') {
      if (!['idle', 'running', 'notLoaded'].includes(p.status) ||
          (p.viewCursor !== null && !idString(p.viewCursor))) throw Error('Invalid Muse session status');
      return;
    }
    if (!idString(p.viewCursor)) throw Error('Muse event cursor missing');
    const digest = createHash('sha256').update(JSON.stringify(event)).digest('hex');
    if (cursors.has(p.viewCursor)) {
      if (cursors.get(p.viewCursor) !== digest) throw Error('Muse cursor conflict');
      return;
    }
    if (cursors.size >= 4096) throw Error('Muse cursor bound exceeded');
    cursors.set(p.viewCursor, digest);
    if (method === 'session/approvalModeChanged') {
      if (p.mode !== 'denyUnmatched') throw Error('Muse approval mode changed');
      return;
    }
    if (!active) throw Error('Muse event outside active turn');
    const turn = active;
    if (method.startsWith('item/')) {
      const item = p.item;
      if (method === 'item/delta') {
        if (!idString(p.itemId) || typeof p.delta !== 'string' || (p.field !== undefined && p.field !== 'text'))
          throw Error('Unsupported Muse delta');
        if (!turn.itemIds.has(p.itemId) && turn.itemIds.size >= 256) throw Error('Muse item bound exceeded');
        turn.itemIds.add(p.itemId);
      } else if (['item/started', 'item/updated', 'item/completed'].includes(method)) {
        if (!item || !idString(item.itemId) || !Number.isSafeInteger(item.revision) || item.revision < 0 ||
            item.turnId !== turn.turnId || !['agentMessage', 'userMessage'].includes(item.kind) ||
            !['inProgress', 'completed'].includes(item.status) || item.truncated === true ||
            (item.text !== undefined && typeof item.text !== 'string')) throw Error('Unsupported Muse item');
        if (!turn.itemIds.has(item.itemId) && turn.itemIds.size >= 256) throw Error('Muse item bound exceeded');
        turn.itemIds.add(item.itemId);
      } else throw Error('Unknown Muse item event');
      const outcome = turn.fold.apply(event);
      if (outcome.outcome?.kind === 'ignoredStaleRevision') return;
      if (method === 'item/completed') {
        if (item.status !== 'completed') throw Error('Muse item completion changed');
        turn.completed.add(item.itemId);
      }
      emitItems(turn); return;
    }
    if (p.turnId !== turn.turnId) throw Error('Muse event turn changed');
    if (method === 'turn/started') {
      if (p.commandId !== turn.commandId) throw Error('Muse turn command changed');
      return;
    }
    if (method !== 'turn/completed' || !['completed', 'cancelled', 'failed'].includes(p.terminal))
      throw Error('Unsupported Muse action or terminal');
    if ((p.terminal === 'failed') !== Boolean(p.error)) throw Error('Muse terminal error shape changed');
    emitItems(turn);
    if (p.terminal === 'completed' && [...turn.itemIds].some(id => !turn.completed.has(id)))
      throw Error('Muse terminal has unresolved items');
    clearTimeout(turn.timer); clearTimeout(turn.cancelTimer);
    active = null;
    if (p.terminal === 'failed') {
      if (!/^[A-Za-z][A-Za-z0-9]{0,63}$/.test(p.error.kind) ||
          typeof p.error.retryable !== 'boolean') throw Error('Muse turn error shape changed');
      return reject(turn.id, `Muse turn failed: ${p.error.kind}`, -32000,
        { completion: 'failed', kind: p.error.kind, retryable: p.error.retryable,
          sessionRetained: true });
    }
    reply(turn.id, { stopReason: p.terminal === 'completed' ? 'end_turn' : 'cancelled' });
  }
  connection.onNotification(event => { try { eventReceived(event); } catch (error) { close(error.message); } });
  connection.onServerRequest(async () => { close('Muse action request unsupported'); throw Error('Unsupported'); });
  connection.onProtocolError(() => close('Muse protocol framing or correlation failure'));
  void connection.closed.then(() => close('Muse EOF; no automatic replay'), () => close('Muse connection failed'));
  async function dispatch(frame) {
    const { id, method, params: p = {} } = frame;
    if (method === 'initialize') {
      if (state !== 'new') return reject(id, 'Already initialized');
      state = 'initializing';
      const result = await bounded(connection.request('initialize', {
        clientInfo: { name: 'codex_desktop_muse_acp', version: '0.1.0' } }), handshakeMs);
      if (closed) return;
      if (result.sessionDurability !== 'durable' || acceptInitialize(result) !== true)
        throw Error('Muse durable handshake not qualified');
      connection.notify('initialized'); await connection.flush(); state = 'ready';
      return reply(id, { protocolVersion: 1, agentCapabilities: { loadSession: false }, authMethods: [] });
    }
    if (state !== 'ready') return reject(id, 'Initialization required');
    if (method === 'session/new') {
      if (sessionId || starting || p.cwd !== target.workspaceRoot || !Array.isArray(p.mcpServers) || p.mcpServers.length)
        return reject(id, 'Invalid or occupied Muse target');
      starting = true;
      const { result } = await bounded(command('session/start', { workspaceRoot: target.workspaceRoot,
        modelId: target.modelId, providerId: 'meta', approvalMode: 'denyUnmatched' }), handshakeMs);
      const s = result.session;
      if (!s || !idString(s.sessionId) || s.workspaceRoot !== target.workspaceRoot || s.modelId !== target.modelId ||
          s.providerId !== 'meta' || s.status !== 'idle' || !idString(result.viewCursor) ||
          result.viewCursor.startsWith('pending:')) throw Error('Muse session identity changed');
      sessionId = s.sessionId; acpSessionId = randomUUID(); starting = false;
      reply(id, { sessionId: acpSessionId }); drain(); return;
    }
    if (!sessionId || p.sessionId !== acpSessionId) return reject(id, 'Unknown Muse session');
    if (method === 'session/cancel') {
      if (id !== undefined) return reject(id, 'Cancellation must be a notification');
      return cancel();
    }
    if (method !== 'session/prompt') return reject(id, 'Unsupported method', -32601);
    if (active) return reject(id, 'Muse turn already active');
    if (!Array.isArray(p.prompt) || !p.prompt.length || p.prompt.length > 128 ||
        p.prompt.some(part => part.type !== 'text' || typeof part.text !== 'string')) return reject(id, 'Text input required');
    const turn = { id, turnId: null, fold: new SessionFold(), itemIds: new Set(),
      emitted: new Map(), completed: new Set() };
    active = turn;
    turn.timer = setTimeout(() => close('Muse turn deadline; completion unproved'), timeoutMs);
    const { result, commandId } = await command('turn/start', { sessionId,
      input: p.prompt.map(part => ({ type: 'text', text: part.text })),
      reasoningEffort: target.effort });
    if (result.commandId !== commandId || result.status !== 'accepted' || result.disposition !== 'started' ||
        result.startedNewTurn !== true || !idString(result.turnId)) throw Error('Muse turn acknowledgement changed');
    turn.commandId = commandId; turn.turnId = result.turnId;
    drain(); if (active === turn && turn.cancelWanted) await cancel();
  }
  return {
    send(frame) {
      if (closed) throw Error('Muse transport closed');
      if (!frame || frame.jsonrpc !== '2.0' || typeof frame.method !== 'string' || bytes(frame) > frameLimit ||
          (frame.id === undefined && frame.method !== 'session/cancel')) return close('Malformed ACP request');
      if (frame.id !== undefined) {
        if (!(idString(frame.id) || Number.isSafeInteger(frame.id)) || ids.has(frame.id) || ids.size >= 4096)
          return close('Duplicate or exhausted ACP identity');
        ids.add(frame.id); pending.add(frame.id);
      }
      void dispatch(frame).catch(error => close(error.message));
    },
    onMessage(handler) { message = handler; }, onClose(handler) { onClose = handler; }, close,
    get closed() { return closed; },
    get diagnostics() { return { emittedBytes, retainedBytes, persistent: true, admitted: false }; },
  };
}
