// Host-owned capability for one Muse session. This module loads no credentials
// and starts no provider itself. Authenticated MSP startup remains gated.
import http from 'node:http';
import https from 'node:https';
import { lstat, unlink } from 'node:fs/promises';
import fs from 'node:fs/promises';
import path from 'node:path';

const MODEL = 'muse-spark-1.3-contributor';
const ORIGIN = 'https://api.meta.ai';
const BODY_LIMIT = 1024 * 1024;
const RESPONSE_LIMIT = 8 * 1024 * 1024;
const BODY_KEYS = new Set(['model', 'input', 'instructions', 'tools', 'tool_choice',
  'parallel_tool_calls', 'stream', 'reasoning', 'max_output_tokens', 'store',
  'previous_response_id', 'include', 'text']);

export async function createMuseProviderBroker({ socketPath, credential,
  maxRequests = 32, lifetimeMs = 300000, request = https.request } = {}) {
  if (!path.isAbsolute(socketPath ?? '') || typeof credential !== 'string' ||
      !credential || /[\r\n\0]/.test(credential) || !Number.isInteger(maxRequests) ||
      maxRequests < 1 || maxRequests > 64 || !Number.isInteger(lifetimeMs) ||
      lifetimeMs < 1 || lifetimeMs > 900000) throw new Error('Invalid broker capability');
  const parent = await lstat(path.dirname(socketPath));
  if (!parent.isDirectory() || parent.isSymbolicLink() || parent.uid !== process.getuid() ||
      (parent.mode & 0o077)) throw new Error('Broker requires a private owner directory');
  let closed = false, active = null, requests = 0;
  const sockets = new Set();
  const server = http.createServer(async (incoming, outgoing) => {
    const refuse = status => { outgoing.writeHead(status, { 'content-type': 'text/plain' }); outgoing.end('Muse broker refused request'); };
    if (closed || active || requests >= maxRequests) return refuse(429);
    const models = incoming.method === 'GET' && incoming.url === '/muse-code/models';
    const response = incoming.method === 'POST' && incoming.url === '/responses';
    if (!models && !response) return refuse(403);
    // Claim the slot before awaiting body bytes; no concurrent authority.
    const operation = { upstream: null, stop: null };
    active = operation; requests++;
    let done = false;
    const finish = () => { if (done) return; done = true; clearTimeout(timer); if (active === operation) active = null; };
    const fail = () => { operation.upstream?.destroy(); if (!outgoing.headersSent) refuse(502); else outgoing.destroy(); };
    operation.stop = fail;
    const timer = setTimeout(fail, Math.min(lifetimeMs, 120000));
    outgoing.once('finish', finish);
    outgoing.once('close', () => { operation.upstream?.destroy(); finish(); });
    try {
      const chunks = []; let size = 0;
      for await (const chunk of incoming) {
        size += chunk.length;
        if (size > BODY_LIMIT || done) throw new Error('Body limit');
        chunks.push(chunk);
      }
      const body = Buffer.concat(chunks);
      if (models && body.length) throw new Error('Unexpected GET body');
      if (response) {
        const value = JSON.parse(body.toString('utf8'));
        if (!value || Array.isArray(value) || typeof value !== 'object' ||
            Object.keys(value).some(key => !BODY_KEYS.has(key)) || value.model !== MODEL ||
            value.stream !== true || value.store === true ||
            (value.reasoning?.effort != null && value.reasoning.effort !== 'max') ||
            (value.max_output_tokens != null && (!Number.isInteger(value.max_output_tokens) ||
              value.max_output_tokens < 1 || value.max_output_tokens > 32768))) throw new Error('Request shape refused');
      }
      if (done || closed) throw new Error('Revoked capability');
      // Never forward owner-selected routing, authentication, cookies or headers.
      const upstream = request(new URL(models ? '/v1/muse-code/models' : '/v1/responses', ORIGIN), {
        method: incoming.method, headers: { authorization: `Bearer ${credential}`,
          'content-type': 'application/json', accept: models ? 'application/json' : 'text/event-stream' },
      }, result => {
        if (done || ![200].includes(result.statusCode)) { result.destroy(); return fail(); }
        const contentType = String(result.headers['content-type'] ?? '');
        if (!(models ? contentType.startsWith('application/json') : contentType.startsWith('text/event-stream'))) {
          result.destroy(); return fail();
        }
        outgoing.writeHead(200, { 'content-type': models ? 'application/json' : 'text/event-stream', 'cache-control': 'no-store' });
        let received = 0;
        result.on('data', chunk => {
          received += chunk.length;
          if (received > RESPONSE_LIMIT) { result.destroy(); return fail(); }
          if (!outgoing.write(chunk)) result.pause();
        });
        outgoing.on('drain', () => result.resume());
        result.once('error', fail);
        result.once('aborted', fail);
        result.once('end', () => { outgoing.end(); });
      });
      operation.upstream = upstream;
      upstream.once('error', fail);
      upstream.end(body);
    } catch { fail(); }
  });
  server.headersTimeout = 10000;
  server.requestTimeout = 120000;
  server.on('connection', socket => { sockets.add(socket); socket.once('close', () => sockets.delete(socket)); });
  server.on('connect', (_request, socket) => socket.destroy());
  server.on('upgrade', (_request, socket) => socket.destroy());
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(socketPath, resolve); });
  try { await fs.chmod(socketPath, 0o600); }
  catch (error) {
    closed = true; active?.stop();
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
    try { await unlink(socketPath); } catch (cleanupError) { if (cleanupError.code !== 'ENOENT') throw cleanupError; }
    throw error;
  }
  let closePromise;
  const close = () => closePromise ??= (async () => {
    closed = true; clearTimeout(lifetime); active?.stop();
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
    try { await unlink(socketPath); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    credential = ''; // No credential appears in status, logs or error objects.
    return { closed: true, socketRemoved: true, requests };
  })();
  const lifetime = setTimeout(() => { void close().catch(() => {}); }, lifetimeMs);
  return Object.freeze({ close, snapshot: () => ({ closed, active: active !== null, requests }) });
}
