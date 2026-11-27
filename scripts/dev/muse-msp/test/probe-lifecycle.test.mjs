import test from 'node:test';
import assert from 'node:assert/strict';
import { boundedProbeExit } from '../probe-lifecycle.mjs';
test('non-exiting child returns unproved cleanup after kill deadline', async () => {
  const signals = [];
  const result = await boundedProbeExit(new Promise(() => {}), value => signals.push(value),
    { termMs: 5, killMs: 10, deadlineMs: 30 });
  assert.equal(result.timedOut, true);
  assert.deepEqual(signals, ['SIGTERM', 'SIGKILL']);
});
test('early exit clears escalation timers', async () => {
  const signals = [];
  assert.deepEqual(await boundedProbeExit(Promise.resolve({ code: 0 }), value => signals.push(value)), { code: 0 });
  assert.deepEqual(signals, []);
});
test('signal errors do not escape timers or report cleanup success', async () => {
  const result = await boundedProbeExit(new Promise(() => {}), () => { throw Object.assign(Error(), { code: 'EPERM' }); },
    { termMs: 1, killMs: 2, deadlineMs: 10 });
  assert.equal(result.signalError, 'EPERM');
  assert.equal(result.timedOut, true);
});

// Exercise the actual probe against an ELF host fixture that floods stderr.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
test('actual probe cannot pass after stderr overflow', async () => {
  const root = await mkdtemp('/tmp/muse-overflow-fixture-');
  try {
    await writeFile(path.join(root, 'host.c'), `#include <stdio.h>
int main(void) { char line[4096];
if (!fgets(line,sizeof(line),stdin)) return 2;
printf("%s\\n", "{\\\"jsonrpc\\\":\\\"2.0\\\",\\\"id\\\":1,\\\"result\\\":{\\\"serverInfo\\\":{\\\"name\\\":\\\"fixture\\\",\\\"version\\\":\\\"1.4.0\\\"},\\\"sessionDurability\\\":\\\"durable\\\"}}");
fflush(stdout);
/* Wait for initialized to prove the client accepted this handshake. */
if (!fgets(line,sizeof(line),stdin)) return 3;
for(int i=0;i<300000;i++) fputc('x',stderr); fflush(stderr); return 0; }`);
    await promisify(execFile)('cc', [path.join(root, 'host.c'), '-o', path.join(root, 'host')]);
    const probe = fileURLToPath(new URL('../probe-acp-host.mjs', import.meta.url));
    await assert.rejects(promisify(execFile)(process.execPath, [probe, path.join(root, 'host')], { timeout: 20000 }), error => {
      const result = JSON.parse(error.stdout.trim());
      assert.equal(result.server.name, 'fixture');
      assert.equal(result.handshakePassed, false);
      assert.match(result.failure, /Stderr diagnostic bound exceeded/);
      return true;
    });
  } finally { await rm(root, { recursive: true, force: true }); }
});
