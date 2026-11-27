#!/usr/bin/env node
// Provider-free actual ACP translator handshake. No sessions or model calls.
import { spawn } from 'node:child_process';
import { mkdtemp, rm, readFile, realpath, open } from 'node:fs/promises';
import { constants } from 'node:fs';
import { boundedProbeExit } from './probe-lifecycle.mjs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { createMuseAcpMspTransport } from './acp-msp-transport.mjs';

const binary = process.argv[2];
if (!path.isAbsolute(binary ?? '')) throw Error('Pass an exact absolute Muse binary path');
const resolved = await realpath(binary);
// Keep the inode open and execute the inherited descriptor, not a replaceable path.
const executable = await open(resolved, constants.O_RDONLY | constants.O_NOFOLLOW);
const identity = await executable.stat();
if (!identity.isFile()) throw Error('Muse executable must be a regular file');
const sha256 = createHash('sha256').update(await executable.readFile()).digest('hex');
const home = await mkdtemp('/tmp/muse-acp-handshake-');
let child, bridge, timer, initialized, stderrBytes = 0, failure;
let exit;
try {
  child = spawn('/proc/self/fd/3', ['serve', '--disable-write', '--disable-shell'], {
    cwd: home, detached: true, stdio: ['pipe', 'pipe', 'pipe', executable.fd],
    env: { HOME: home, XDG_CONFIG_HOME: path.join(home, '.config'),
      XDG_STATE_HOME: path.join(home, '.local', 'state'),
      XDG_DATA_HOME: path.join(home, '.local', 'share'), PATH: '/usr/bin:/bin',
      LANG: 'C.UTF-8', MUSE_NO_AUTO_UPDATE: '1' },
  });
  exit = new Promise(resolve => {
    child.once('error', () => resolve({ spawnFailed: true }));
    child.once('close', (code, signal) => resolve({ code, signal }));
  });
  // /proc identifies the actual image even if the original pathname was replaced.
  await new Promise((resolve, reject) => { child.once('spawn', resolve); child.once('error', reject); });
  const launchedHash = createHash('sha256').update(await readFile(`/proc/${child.pid}/exe`)).digest('hex');
  if (launchedHash !== sha256) throw Error('Launched executable digest mismatch');
  child.stdout.setEncoding('utf8');
  child.stderr.on('data', chunk => {
    stderrBytes += chunk.length;
    if (stderrBytes > 262144) {
      failure = 'Stderr diagnostic bound exceeded';
      bridge?.close();
    }
  });
  child.stdin.on('error', () => {});
  const transport = { incoming: child.stdout,
    write: chunk => new Promise((resolve, reject) => child.stdin.write(chunk,
      error => error ? reject(error) : resolve())),
    close: async () => { child.stdin.end(); },
  };
  bridge = createMuseAcpMspTransport({ transport,
    target: { workspaceRoot: home, modelId: 'muse-spark-1.3-contributor', effort: 'max' },
    // Diagnostic handshake acceptance only, never an admission callback.
    acceptInitialize: result => {
      initialized = result;
      return typeof result.serverInfo?.version === 'string' && result.serverInfo.version.trim() !== '';
    },
  });
  await new Promise((resolve, reject) => {
    timer = setTimeout(() => reject(Error('Handshake diagnostic deadline')), 15000);
    bridge.onClose(() => reject(Error('Translator closed before handshake')));
    bridge.onMessage(frame => {
      if (frame.id === 1) frame.error ? reject(Error(frame.error.message)) : resolve();
    });
    bridge.send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {} });
  });
} catch (error) { failure ??= error.message; }
finally {
  clearTimeout(timer); bridge?.close(); child?.stdin.end();
  if (child && Number.isInteger(child.pid)) {
    const signal = kind => { try { process.kill(-child.pid, kind); } catch (error) { if (error.code !== 'ESRCH') throw error; } };
    const result = await boundedProbeExit(exit, signal);
    let groupGone = false;
    try { process.kill(-child.pid, 0); } catch (error) { if (error.code === 'ESRCH') groupGone = true; }
    if (!groupGone) { try { signal('SIGKILL'); } catch {} failure ??= 'Process group cleanup unproved'; }
    if (result.timedOut || !groupGone) {
      child.stdin.destroy(); child.stdout.destroy(); child.stderr.destroy(); child.unref();
    }
    if (result.timedOut || result.signalError) failure ??= 'Process exit cleanup unproved';
    if (!failure) {
      const finalHash = createHash('sha256').update(await readFile(`/proc/self/fd/${executable.fd}`)).digest('hex');
      if (finalHash !== sha256) failure = 'Executable changed during handshake';
    }
    if (groupGone && !result.timedOut) await rm(home, { recursive: true, force: true });
    console.log(JSON.stringify({ binary: resolved, sha256, server: initialized?.serverInfo,
      schema: initialized?.schema, handshakePassed: !failure, failure: failure ?? null,
      cleanup: { ...result, groupGone, retainedHome: groupGone && !result.timedOut ? null : home }, stderrBytes, admission: false, providerCalls: 0 }));
    if (failure || !groupGone || result.code !== 0) process.exitCode = 1;
  }
  if (!child?.pid) { process.exitCode = 1; console.log(JSON.stringify({ failure: failure ?? "Spawn failed", admission: false })); }
  if (!child?.pid) await rm(home, { recursive: true, force: true });
  await executable.close();
}
