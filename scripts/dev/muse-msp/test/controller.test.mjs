import assert from "node:assert/strict";
import { existsSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  acquireInitialLeases,
  acquireLease,
  approvalDecision,
  classifyError,
  exactApprovalMatch,
  loadApprovalAllowlist,
  main,
  MSP_APPROVAL_MODE,
  pidState,
  protocolCancel,
  readLease,
  releaseOwnLease,
  releaseLeasesAfterClose,
  withRegistryLock,
} from "../muse-msp-controller.mjs";

const request = {
  toolName: "shell",
  rawArgs: '["npm","test"]',
  subject: { kind: "shell", path: "/workspace" },
  availableChoices: [
    { choiceId: "allow-once", decision: "approved", scope: "once", label: "Allow" },
    { choiceId: "deny-once", decision: "denied", scope: "once", label: "Deny" },
    { choiceId: "allow-session", decision: "approvedForSession", scope: "session", label: "Allow session" },
  ],
};

test("approval allowlist is exact and once-only", () => {
  assert.equal(MSP_APPROVAL_MODE, "promptUnmatched");
  const entry = {
    toolName: "shell",
    subjectKind: "shell",
    rawArgs: '["npm","test"]',
    path: "/workspace",
  };
  const allowed = [entry];
  assert.equal(exactApprovalMatch(allowed[0], request), true);
  assert.deepEqual(approvalDecision(request, allowed), { choiceId: "allow-once" });
  assert.equal(allowed.length, 0);
  assert.deepEqual(approvalDecision(request, allowed), { choiceId: "deny-once" });
  assert.deepEqual(approvalDecision(request, [{ ...entry, rawArgs: '["npm","run","test"]' }]), {
    choiceId: "deny-once",
  });
});

test("MSP userShell is rejected before host startup", async () => {
  await assert.rejects(
    () => main(["--user-shell-file", "/tmp/forbidden-command"]),
    /session\/userShell bypasses Muse managed-shell workspace protection/,
  );
});

test("registry lock is atomic and removed after success or failure", () => {
  const directory = mkdtempSync(join(tmpdir(), "muse-registry-lock-test-"));
  const lock = join(directory, "registry.lock");
  assert.equal(withRegistryLock(directory, () => "ok"), "ok");
  assert.equal(existsSync(lock), false);
  assert.throws(() => withRegistryLock(directory, () => { throw new Error("operation failed"); }), /operation failed/);
  assert.equal(existsSync(lock), false);
});

test("malformed and widened allowlists fail closed", () => {
  const directory = mkdtempSync(join(tmpdir(), "muse-allowlist-test-"));
  const malformed = join(directory, "malformed.json");
  const widened = join(directory, "widened.json");
  writeFileSync(malformed, "{}\n");
  writeFileSync(widened, JSON.stringify([{ toolName: "shell", subjectKind: "shell", rawArgs: "x", wildcard: "*" }]));
  assert.throws(() => loadApprovalAllowlist(malformed), /JSON array/);
  assert.throws(() => loadApprovalAllowlist(widened), /unsupported approval allowlist key/);
});

test("writer leases are exclusive and only their token may release", () => {
  const directory = mkdtempSync(join(tmpdir(), "muse-lease-test-"));
  const path = join(directory, "writer.lease.json");
  const lease = acquireLease(path, { pid: process.pid, token: "owner" });
  assert.equal(readLease(path).state, "active");
  assert.throws(() => acquireLease(path, { pid: process.pid, token: "other" }), /no automatic lease stealing/);
  assert.equal(releaseOwnLease({ path, token: "other" }), false);
  assert.equal(releaseOwnLease(lease), true);
  assert.equal(readLease(path).state, "absent");
});

test("resume lease pair is acquired under one lock and rolls back on refusal", () => {
  const directory = mkdtempSync(join(tmpdir(), "muse-lease-pair-test-"));
  const worktreePath = join(directory, "worktree.lease.json");
  const sessionPath = join(directory, "session.lease.json");
  acquireLease(sessionPath, { pid: process.pid, token: "existing" });
  assert.throws(() => acquireInitialLeases(directory, {
    worktree: worktreePath,
    session: sessionPath,
  }, {
    pid: process.pid,
    token: "new",
    worktreeIdentity: "worktree",
    sessionIdentity: "session",
  }), /no automatic lease stealing/);
  assert.equal(readLease(worktreePath).state, "absent");
  assert.equal(readLease(sessionPath).record.token, "existing");
});

test("stale and malformed leases are detected, never silently removed", () => {
  const directory = mkdtempSync(join(tmpdir(), "muse-stale-lease-test-"));
  const path = join(directory, "writer.lease.json");
  writeFileSync(path, '{"pid":2147483647,"token":"stale"}\n');
  assert.equal(readLease(path).state, "stale");
  assert.throws(() => acquireLease(path, { pid: process.pid, token: "new" }), /no automatic lease stealing/);
  assert.equal(readLease(path).record.token, "stale");
  assert.equal(pidState(0), "malformed");
});

test("session-in-use and timeout failures retain typed controller outcomes", () => {
  assert.equal(classifyError(new Error("sessionInUse")), "session_in_use");
  assert.equal(classifyError(new Error("session 11111111-1111-4111-8111-111111111111 is already in use")), "session_in_use");
  assert.equal(classifyError(new Error("turn timed out")), "timed_out");
  assert.equal(classifyError(new Error("anything else")), "failed");
});

test("protocol cancellation uses the server command lane and validates acknowledgement", async () => {
  const calls = [];
  const connection = {
    mintCommandId: () => "command-id",
    command: async (method, params) => {
      calls.push({ method, params });
      return { commandId: params.commandId, status: "accepted", turnId: params.turnId };
    },
  };
  assert.deepEqual(await protocolCancel(connection, "session-id", "turn-id"), {
    commandId: "command-id",
    status: "accepted",
    turnId: "turn-id",
  });
  assert.deepEqual(calls, [{
    method: "turn/cancel",
    params: { commandId: "command-id", sessionId: "session-id", turnId: "turn-id" },
  }]);
  await assert.rejects(() => protocolCancel({
    mintCommandId: () => "command-id",
    command: async () => ({ status: "accepted", turnId: "other-turn" }),
  }, "session-id", "turn-id"), /invalid acknowledgement/);
});

test("Max effort reaches context validation without starting a host", async () => {
  await assert.rejects(() => main([
    "--worktree-existing", "/tmp/muse-max-options-probe", "--prompt-file", "/tmp/muse-max-prompt",
    "--reasoning-effort", "max", "--context-class", "invalid",
  ]), /--context-class must be public or private-approved/);
});


test("uncertain host closure retains writer leases", () => {
  const directory = mkdtempSync(join(tmpdir(), "muse-close-lease-test-"));
  const file = join(directory, "writer.lease.json");
  const lease = acquireLease(file, {pid: process.pid, token: "owner"});
  assert.equal(releaseLeasesAfterClose(false, null, lease), false);
  assert.equal(readLease(file).state, "active");
  assert.equal(releaseLeasesAfterClose(true, null, lease), true);
  assert.equal(readLease(file).state, "absent");
});
