#!/usr/bin/env node
// Provider-free protocol probe: no credentials, workspace, session or model turn.
import { spawnMspConnection } from '@muse-code/sdk';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const home = await mkdtemp(join(tmpdir(), 'muse-msp-probe-'));
let pending, host, timer;
try {
  pending = spawnMspConnection({
    command: process.env.AGENT_CALL_MUSE_BIN || 'muse',
    args: ['serve', '--disable-write', '--disable-shell', '--no-session-log'],
    env: { HOME: home, PATH: process.env.PATH, MUSE_NO_AUTO_UPDATE: '1', LANG: 'C.UTF-8' },
    shutdownTimeoutMs: 5000,
  });
  host = await Promise.race([
    pending.initialize({ clientInfo: { name: 'codex_muse_probe', version: '1.0' } }),
    new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('MSP initialize timed out')), 15000); }),
  ]);
  console.log(JSON.stringify({ server: host.initializeResult.serverInfo,
    schema: host.initializeResult.schema, durability: host.initializeResult.sessionDurability,
    schemaWarning: host.fingerprintWarning ?? null, providerQualified: false }));
} catch (error) {
  console.error(error.message); process.exitCode = 1;
} finally {
  clearTimeout(timer);
  try {
    const exit = await (host ?? pending)?.close();
    console.log(JSON.stringify({ cleanup: exit ?? null }));
    if (!exit || exit.code !== 0 || exit.signal != null) process.exitCode = 1;
  } finally { await rm(home, { recursive: true }); }
}
