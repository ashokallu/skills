// Trusted outer process. Never mount this process's home or credentials in Pi.
import fs from 'node:fs';
import http from 'node:http';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const digest = value => crypto.createHash('sha256').update(value).digest('hex');
export function validateBody(raw, encoding, model, effort, limit) {
  if (!['low', 'medium', 'high', 'xhigh', 'max'].includes(effort)) throw Error('effort-config');
  if (encoding === 'zstd') raw = zlib.zstdDecompressSync(raw, { maxOutputLength: limit });
  else if (encoding && encoding !== 'identity') throw Error('encoding');
  if (raw.length > limit) throw Error('request-size');
  const body = JSON.parse(raw);
  if (body.model !== model || body.stream !== true || body.store !== false ||
      !Array.isArray(body.input) || body.previous_response_id || body.background ||
      body.tools?.some(tool => tool.type !== 'function') ||
      body.reasoning?.effort !== effort) throw Error('request-contract');
  // Do not allow a socket caller to enable server-side tools or override routing.
  const allowed = new Set(['model','stream','store','instructions','input','text','include',
    'prompt_cache_key','tool_choice','parallel_tool_calls','tools','reasoning']);
  if (Object.keys(body).some(key => !allowed.has(key))) throw Error('request-field');
  return body;
}

export function validateResponse(raw, model) {
  const events = raw.toString('utf8').split(/\r?\n/).filter(line => line.startsWith('data:'))
    .map(line => line.slice(5).trim()).filter(line => line && line !== '[DONE]').map(JSON.parse);
  const terminal = events.filter(e => ['response.completed','response.failed','response.incomplete',
    'response.cancelled','error'].includes(e.type));
  if (terminal.length !== 1 || terminal[0].type !== 'response.completed') throw Error('terminal');
  for (const event of events) {
    if (event.response?.model && event.response.model !== model) throw Error('model-mismatch');
  }
  const response = terminal[0].response;
  if (response.model !== model || response.status !== 'completed') throw Error('model-status');
  const usage = response.usage;
  if (!usage || ['input_tokens','output_tokens','total_tokens'].some(key =>
    !Number.isSafeInteger(usage[key]) || usage[key] < 0) ||
    usage.total_tokens !== usage.input_tokens + usage.output_tokens) throw Error('usage');
  const textOf = items => items.filter(item => item.type === 'message')
    .flatMap(item => item.content || []).filter(item => item.type === 'output_text')
    .map(item => {
      if (typeof item.text !== 'string') throw Error('terminal-text');
      return item.text;
    }).join('');
  const done = new Map();
  for (const event of events.filter(event => event.type === 'response.output_item.done')) {
    if (!Number.isSafeInteger(event.output_index) || event.output_index < 0 ||
        done.has(event.output_index) || !event.item) throw Error('terminal-item');
    done.set(event.output_index, event.item);
  }
  const streamText = textOf([...done].sort(([a], [b]) => a - b).map(([, item]) => item));
  const terminalText = textOf(response.output || []);
  if (streamText && terminalText && streamText !== terminalText) throw Error('terminal-text');
  const text = streamText || terminalText;
  const sanitizedUsage = { input_tokens: usage.input_tokens, output_tokens: usage.output_tokens,
    total_tokens: usage.total_tokens };
  for (const [group, fields] of [['input_tokens_details', ['cached_tokens', 'cache_write_tokens']],
    ['output_tokens_details', ['reasoning_tokens']]]) {
    if (usage[group]) {
      sanitizedUsage[group] = {};
      for (const field of fields) {
        if (usage[group][field] !== undefined) {
          if (!Number.isSafeInteger(usage[group][field]) || usage[group][field] < 0) throw Error('usage');
          sanitizedUsage[group][field] = usage[group][field];
        }
      }
    }
  }
  return { effective_model: response.model, usage: sanitizedUsage, text_sha256: digest(text),
    cost_usd: null, cost_source: 'not-provided-by-provider' };
}

export function startBroker(config, auth, transport = fetch) {
  if (!['minimal', 'low', 'medium', 'high', 'xhigh', 'max'].includes(config.effort) ||
      config.provider_effort !== (config.effort === 'minimal' ? 'low' : config.effort)) {
    throw Error('effort-config');
  }
  if (auth?.type !== 'oauth' || typeof auth.access !== 'string' || !Number.isFinite(auth.expires) ||
      auth.expires < Date.now() + config.timeout_sec * 1000) throw Error('auth-not-ready');
  const account = JSON.parse(Buffer.from(auth.access.split('.')[1], 'base64url'))
    ['https://api.openai.com/auth']?.chatgpt_account_id;
  if (typeof account !== 'string' || !account) throw Error('auth-account');
  const state = { status: 'ready', requested_model: config.model, requested_effort: config.effort,
    requests: config.prior_requests || 0,
    total_tokens: config.prior_tokens || 0, attempts: [] };
  const save = () => {
    const file = fs.openSync(`${config.audit}.new`, 'w', 0o600);
    try { fs.writeFileSync(file, JSON.stringify(state)); fs.fsyncSync(file); }
    finally { fs.closeSync(file); }
    fs.renameSync(`${config.audit}.new`, config.audit);
    const directory = fs.openSync(path.dirname(config.audit), 'r');
    try { fs.fsyncSync(directory); } finally { fs.closeSync(directory); }
  };
  let busy = false;
  let poisoned = false;
  const deadline = Date.now() + config.timeout_sec * 1000;
  const server = http.createServer(async (req, res) => {
    let attempt;
    const fail = reason => {
      if (attempt) Object.assign(attempt, { status: 'failed', reason });
      poisoned = true; state.status = 'failed'; state.reason = reason; save();
      res.writeHead(403, { 'content-type': 'application/json' });
      res.end('{"error":"Pi broker rejected request"}');
    };
    if (busy || poisoned || Date.now() >= deadline || state.requests >= config.max_requests ||
        state.total_tokens >= config.max_tokens) return fail('admission');
    busy = true;
    // Reserve durably before any upstream request. Failed attempts consume admission.
    attempt = { requested_model: config.model, requested_effort: config.effort,
      effective_effort: null, status: 'inflight', usage: null, cost_usd: null };
    state.attempts.push(attempt);
    state.requests++; state.status = 'inflight'; save();
    try {
      if (req.method !== 'POST' || req.url !== '/codex/responses') throw Error('route');
      const chunks = []; let size = 0;
      for await (const chunk of req) {
        size += chunk.length;
        if (size > config.max_request_bytes) throw Error('request-size');
        chunks.push(chunk);
      }
      const body = validateBody(Buffer.concat(chunks), req.headers['content-encoding'],
        config.model, config.provider_effort, config.max_request_bytes);
      attempt.effective_effort = body.reasoning.effort;
      body.prompt_cache_key = config.session_id;
      const upstream = await transport('https://chatgpt.com/backend-api/codex/responses', {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(Math.max(1, deadline - Date.now())),
        headers: { authorization: `Bearer ${auth.access}`, 'chatgpt-account-id': account,
          'content-type': 'application/json', accept: 'text/event-stream',
          'OpenAI-Beta': 'responses=experimental', originator: 'pi',
          'User-Agent': 'pi-harness-candidate', 'session-id': config.session_id },
        body: JSON.stringify(body)
      });
      const output = []; let length = 0;
      for await (const chunk of upstream.body) {
        length += chunk.length;
        if (length > config.max_response_bytes) throw Error('response-size');
        output.push(Buffer.from(chunk));
      }
      const raw = Buffer.concat(output);
      if (raw.includes(Buffer.from(auth.access)) || raw.includes(Buffer.from(account))) throw Error('credential-echo');
      if (!upstream.ok) {
        try {
          const error = JSON.parse(raw);
          const message = error.detail ?? error.error?.message;
          if (typeof message === 'string') attempt.provider_error = message.slice(0, 512).replace(/[\x00-\x1f]/g, ' ');
        } catch { /* An unstructured error is represented by its HTTP status. */ }
        throw Error(`upstream-${upstream.status}`);
      }
      const evidence = validateResponse(raw, config.model);
      state.total_tokens += evidence.usage.total_tokens;
      Object.assign(attempt, evidence, { status: 'completed' }); state.status = 'ready'; save();
      if (poisoned) throw Error('concurrent-rejection');
      res.writeHead(200, { 'content-type': 'text/event-stream' }); res.end(raw);
    } catch (error) {
      const known = /^(effort-config|encoding|request-size|request-contract|request-field|route|upstream-\d+|response-size|credential-echo|terminal|terminal-text|terminal-item|model-mismatch|model-status|usage|concurrent-rejection)$/;
      fail(known.test(error.message) ? error.message : 'protocol-or-transport');
    } finally { busy = false; }
  });
  server.requestTimeout = config.timeout_sec * 1000;
  server.headersTimeout = Math.min(10000, server.requestTimeout);
  server.maxConnections = 4;
  server.listen(config.socket, () => { fs.chmodSync(config.socket, 0o600); save(); });
  const timer = setTimeout(() => server.closeAllConnections(), config.timeout_sec * 1000);
  timer.unref();
  server.on('close', () => clearTimeout(timer));
  return server;
}
async function main() {
  const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const { readStoredCredential } = await import(pathToFileURL(`${config.runtime}/dist/core/auth-storage.js`));
  startBroker(config, readStoredCredential('openai-codex', config.auth_path));
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(() => { process.stderr.write('Pi broker initialization failed\n'); process.exit(1); });
}
