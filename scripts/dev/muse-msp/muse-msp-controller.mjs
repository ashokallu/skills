#!/usr/bin/env node

import {
  MuseClient,
  readSessionDurability,
  spawnMspConnection,
} from "@muse-code/sdk";
import { execFileSync } from "node:child_process";
import {
  appendFileSync,
  closeSync,
  existsSync,
  lstatSync,
  mkdirSync,
  openSync,
  readFileSync,
  realpathSync,
  rmdirSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";
import { createHash, randomUUID } from "node:crypto";

const CLIENT_VERSION = "0.1.0";
const SESSION_ID = /^[0-9a-fA-F-]{36}$/;
const SAFE_EFFORTS = new Set(["none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra"]);
const SAFE_CONTEXT_CLASSES = new Set(["public", "private-approved"]);
const MSP_APPROVAL_MODE = "promptUnmatched";

function die(message) {
  throw new Error(message);
}

function usage() {
  process.stdout.write(`Usage:
  node scripts/dev/muse-msp/muse-msp-controller.mjs \\
    --worktree-existing <path> --prompt-file <path> [options]

Options:
  --prompt-file <path>       First turn file. Required; never placed in argv.
  --follow-up-file <path>    Additional turn file. Repeatable, same writer.
  --resume <session-id>      Resume an exact released Muse session.
  --model <id>               Default: muse-spark-1.3-contributor.
  --reasoning-effort <tier>  Default: high.
  --context-class <class>    public or private-approved. Default: public.
  --confirm-contributor-data-use
                             Required for contributor + private-approved.
  --approval-allowlist <path>
                             JSON array of exact once-only approval matches.
  --timeout-sec <seconds>    Per-turn timeout. Default: 900.
  --cancel-after-ms <ms>     Test seam: protocol-cancel the first turn.
  --muse-bin <path>          Muse launcher or exact ELF. Default: muse.
  --output <path>            Final response. Must be a new file below the owned
                             repository Muse calls directory.
  --events-output <path>     New contained file of sanitized event summaries;
                             never raw args/content.
  --run-manifest <path>      New contained non-secret numeric/run-state file.
  --inspect-lease            Inspect this worktree lease and exit; never steal.

MSP session/userShell is deliberately unsupported: it is the TUI ! escape
hatch and is not Muse's managed sandboxed shell. Shell work must be proposed
by the model through the normal approval and managed-shell path.

The protocol implementation and lease inspector remain available for local
contract tests and future Muse releases. Live Meta startup currently fails
closed before provider invocation: muse serve has no stdin credential channel,
while mounted auth and inherited environment credentials are visible to model
tools. Use scripts/dev/agent-call-muse.sh for guarded real-provider work.
`);
}

function parseArgs(argv) {
  const options = {
    promptFiles: [],
    model: "muse-spark-1.3-contributor",
    effort: "high",
    contextClass: "public",
    confirmContributorDataUse: false,
    timeoutSec: 900,
    cancelAfterMs: null,
    museBin: "muse",
    inspectLease: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    const value = () => {
      index += 1;
      if (index >= argv.length || argv[index] === "") die(`${flag} requires a value`);
      return argv[index];
    };
    switch (flag) {
      case "--prompt-file":
      case "--follow-up-file": options.promptFiles.push(value()); break;
      case "--user-shell-file": die("--user-shell-file is forbidden: MSP session/userShell bypasses Muse managed-shell workspace protection");
      case "--worktree-existing": options.worktree = value(); break;
      case "--resume": options.resume = value(); break;
      case "--model": options.model = value(); break;
      case "--reasoning-effort": options.effort = value(); break;
      case "--context-class": options.contextClass = value(); break;
      case "--confirm-contributor-data-use": options.confirmContributorDataUse = true; break;
      case "--approval-allowlist": options.approvalAllowlist = value(); break;
      case "--timeout-sec": options.timeoutSec = Number(value()); break;
      case "--cancel-after-ms": options.cancelAfterMs = Number(value()); break;
      case "--muse-bin": options.museBin = value(); break;
      case "--output": options.output = value(); break;
      case "--events-output": options.eventsOutput = value(); break;
      case "--run-manifest": options.runManifest = value(); break;
      case "--inspect-lease": options.inspectLease = true; break;
      case "-h":
      case "--help": options.help = true; break;
      default: die(`unknown option: ${flag}`);
    }
  }
  return options;
}

function commandOutput(command, args, cwd) {
  return execFileSync(command, args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
}

function repoRoot(cwd) {
  return realpathSync(commandOutput("git", ["rev-parse", "--show-toplevel"], cwd));
}

function gitCommonDir(worktree) {
  const common = commandOutput("git", ["rev-parse", "--git-common-dir"], worktree);
  return realpathSync(resolve(worktree, common));
}

function assertRegisteredWorktree(root, requested) {
  const worktree = realpathSync(requested);
  if (worktree === root) die("--worktree-existing must differ from the coordinating checkout");
  if (commandOutput("git", ["rev-parse", "--is-inside-work-tree"], worktree) !== "true") {
    die("--worktree-existing must be a Git worktree");
  }
  if (gitCommonDir(root) !== gitCommonDir(worktree)) {
    die("--worktree-existing must belong to the coordinating repository");
  }
  const registered = commandOutput("git", ["worktree", "list", "--porcelain"], root)
    .split("\n").includes(`worktree ${worktree}`);
  if (!registered) die("--worktree-existing must be registered with git worktree");
  return worktree;
}

function isForbiddenContextPath(filePath) {
  const lower = filePath.toLowerCase();
  return /(^|\/)(\.env(?:\..*)?|\.envrc|id_(?:rsa|dsa|ecdsa|ed25519))$/.test(lower)
    || /auth-state|credential|secret|token|cookie|customer|production-data|prod-data|private-log/.test(lower)
    || /\.(?:pem|key|p12|pfx)$/.test(lower);
}

function validateOptions(options, root) {
  if (options.help) return options;
  if (!options.worktree) die("--worktree-existing is required");
  if (options.promptFiles.length === 0 && !options.inspectLease) die("--prompt-file is required");
  if (!SAFE_EFFORTS.has(options.effort)) die("unsupported --reasoning-effort");
  if (!SAFE_CONTEXT_CLASSES.has(options.contextClass)) die("--context-class must be public or private-approved");
  if (!Number.isInteger(options.timeoutSec) || options.timeoutSec < 1) die("--timeout-sec must be a positive integer");
  if (options.cancelAfterMs !== null && (!Number.isInteger(options.cancelAfterMs) || options.cancelAfterMs < 1)) {
    die("--cancel-after-ms must be a positive integer");
  }
  if (options.contextClass === "private-approved" && options.model.includes("contributor")
      && !options.confirmContributorDataUse) {
    die("private-approved context with a contributor model requires --confirm-contributor-data-use");
  }
  if (options.confirmContributorDataUse && options.contextClass !== "private-approved") {
    die("--confirm-contributor-data-use is valid only with --context-class private-approved");
  }
  if (options.resume && !SESSION_ID.test(options.resume)) die("--resume must be an exact session UUID");
  for (const file of options.promptFiles) {
    if (lstatSync(file).isSymbolicLink()) die(`prompt must be a regular non-symlink file: ${file}`);
    const path = realpathSync(file);
    if (!lstatSync(path).isFile()) die(`prompt must be a regular non-symlink file: ${file}`);
    if (isForbiddenContextPath(path)) die(`prompt path belongs to a forbidden data class: ${file}`);
  }
  options.worktree = assertRegisteredWorktree(root, options.worktree);
  return options;
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function sanitizeSlug(value) {
  return value.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 80) || "run";
}

function pidState(pid) {
  if (!Number.isInteger(pid) || pid < 1) return "malformed";
  try {
    process.kill(pid, 0);
    return "active";
  } catch (error) {
    return error?.code === "ESRCH" ? "stale" : "unknown";
  }
}

function readLease(path) {
  if (!existsSync(path)) return { state: "absent" };
  const stat = lstatSync(path);
  if (stat.isSymbolicLink() || !stat.isFile()) return { state: "unsafe" };
  try {
    const record = JSON.parse(readFileSync(path, "utf8"));
    return { state: pidState(record.pid), record };
  } catch {
    return { state: "malformed" };
  }
}

function withRegistryLock(stateDir, operation) {
  const lock = join(stateDir, "registry.lock");
  try {
    mkdirSync(lock, { mode: 0o700 });
  } catch (error) {
    if (error?.code === "EEXIST") {
      die(`lease registry is already locked; inspect it manually and never steal it: ${lock}`);
    }
    throw error;
  }
  try {
    return operation();
  } finally {
    rmdirSync(lock);
  }
}

function acquireLease(path, record) {
  const existing = readLease(path);
  if (existing.state !== "absent") {
    die(`writer lease unavailable (${existing.state}); no automatic lease stealing: ${basename(path)}`);
  }
  const descriptor = openSync(path, "wx", 0o600);
  try {
    writeFileSync(descriptor, `${JSON.stringify(record)}\n`, { encoding: "utf8" });
  } finally {
    closeSync(descriptor);
  }
  return { path, token: record.token };
}

function releaseOwnLease(lease) {
  if (!lease) return true;
  const current = readLease(lease.path);
  if (current.state === "unsafe" || current.state === "malformed" || current.record?.token !== lease.token) {
    return false;
  }
  unlinkSync(lease.path);
  return true;
}

function leasePaths(stateDir, worktree, sessionId) {
  return {
    worktree: join(stateDir, `worktree-${sha256(worktree)}.lease.json`),
    session: sessionId ? join(stateDir, `session-${sessionId.toLowerCase()}.lease.json`) : null,
  };
}

function acquireInitialLeases(stateDir, paths, leaseBase) {
  return withRegistryLock(stateDir, () => {
    const worktree = acquireLease(paths.worktree, {
      ...leaseBase,
      kind: "worktree",
      identity: leaseBase.worktreeIdentity,
    });
    try {
      const session = paths.session ? acquireLease(paths.session, {
        ...leaseBase,
        kind: "session",
        identity: leaseBase.sessionIdentity,
      }) : undefined;
      return { worktree, session };
    } catch (error) {
      if (!releaseOwnLease(worktree)) die("failed to roll back worktree lease after session lease refusal");
      throw error;
    }
  });
}

function loadApprovalAllowlist(path) {
  if (!path) return [];
  if (lstatSync(path).isSymbolicLink()) die("approval allowlist must be a regular non-symlink file");
  const resolved = realpathSync(path);
  if (!lstatSync(resolved).isFile()) die("approval allowlist must be a regular non-symlink file");
  const parsed = JSON.parse(readFileSync(resolved, "utf8"));
  if (!Array.isArray(parsed)) die("approval allowlist must be a JSON array");
  const allowedKeys = new Set(["toolName", "subjectKind", "rawArgs", "path"]);
  return parsed.map((entry, index) => {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) die(`approval allowlist entry ${index} must be an object`);
    for (const key of Object.keys(entry)) if (!allowedKeys.has(key)) die(`unsupported approval allowlist key: ${key}`);
    if (typeof entry.toolName !== "string" || typeof entry.subjectKind !== "string" || typeof entry.rawArgs !== "string") {
      die(`approval allowlist entry ${index} requires exact toolName, subjectKind, and rawArgs strings`);
    }
    if (entry.path !== undefined && typeof entry.path !== "string") die(`approval allowlist entry ${index} path must be a string`);
    return Object.freeze({ ...entry });
  });
}

function exactApprovalMatch(entry, request) {
  return entry.toolName === request.toolName
    && entry.subjectKind === request.subject?.kind
    && entry.rawArgs === request.rawArgs
    && (entry.path === undefined || entry.path === request.subject?.path);
}

function approvalDecision(request, allowlist) {
  const matchedIndex = allowlist.findIndex((entry) => exactApprovalMatch(entry, request));
  const permitted = matchedIndex !== -1;
  const choice = request.availableChoices.find((candidate) => {
    if (candidate.scope !== "once") return false;
    return permitted ? candidate.decision === "approved" : ["denied", "abort"].includes(candidate.decision);
  });
  if (!choice) die(`server supplied no safe once-only ${permitted ? "approval" : "denial"} choice`);
  if (permitted) allowlist.splice(matchedIndex, 1);
  return { choiceId: choice.choiceId };
}

function safeGitStatus(worktree) {
  const output = execFileSync("git", ["status", "--porcelain=v1", "-z", "--untracked-files=all"], {
    cwd: worktree,
    encoding: "utf8",
  });
  return output.split("\0").filter(Boolean).map((row) => {
    const path = row.slice(3).split(" -> ").at(-1);
    return path.replaceAll("\\", "/");
  }).sort();
}

function assertArtifactParent(path, runDir) {
  const parent = realpathSync(dirname(path));
  if (parent !== runDir) die("default artifacts must remain in the exact owned run directory");
}

function makeArtifacts(root, options) {
  const callsDir = join(root, "tmp", "codex-claude", "calls");
  mkdirSync(callsDir, { recursive: true, mode: 0o700 });
  if (lstatSync(callsDir).isSymbolicLink()) die("Muse calls directory must not be a symlink");
  if (realpathSync(callsDir) !== callsDir) die("Muse calls directory escaped the repository-owned tmp root");
  const stamp = new Date().toISOString().replaceAll(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
  const runDir = join(callsDir, `${stamp}-muse-msp-${sanitizeSlug(options.model)}-${process.pid}`);
  mkdirSync(runDir, { mode: 0o700 });
  const output = options.output ? resolve(options.output) : join(runDir, "final.md");
  const events = options.eventsOutput ? resolve(options.eventsOutput) : join(runDir, "events.jsonl");
  const manifest = options.runManifest ? resolve(options.runManifest) : join(runDir, "run.json");
  const paths = [output, events, manifest];
  if (new Set(paths).size !== paths.length) die("output, events, and manifest paths must differ");
  for (const path of paths) {
    if (!path.startsWith(`${callsDir}${sep}`)) die("artifacts must remain below the repository-owned Muse calls directory");
    mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
    const parent = realpathSync(dirname(path));
    if (parent !== callsDir && !parent.startsWith(`${callsDir}${sep}`)) {
      die("artifact parent escaped the repository-owned Muse calls directory");
    }
    if (existsSync(path)) die("refusing to overwrite an existing Muse artifact");
  }
  if (!options.output && !options.eventsOutput && !options.runManifest) {
    assertArtifactParent(output, runDir);
    assertArtifactParent(events, runDir);
    assertArtifactParent(manifest, runDir);
  }
  return { runDir, output, events, manifest };
}

function eventWriter(path) {
  writeFileSync(path, "", { mode: 0o600 });
  return (record) => appendFileSync(path, `${JSON.stringify(record)}\n`, { encoding: "utf8" });
}

function shellSingleQuote(value) {
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}

function createSandboxBridge(runDir, sandbox) {
  const bridge = join(runDir, "muse-bundled-bwrap");
  if (existsSync(bridge)) die("refusing to overwrite an existing per-run sandbox selector");
  const source = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    `export MUSE_BUNDLED_BWRAP_ELF=${shellSingleQuote(sandbox.binary)}`,
    `export MUSE_BUNDLED_BWRAP_VERSION=${shellSingleQuote(sandbox.version)}`,
    `export MUSE_BUNDLED_BWRAP_SHA256=${shellSingleQuote(sandbox.sha256)}`,
    `exec ${shellSingleQuote(sandbox.selector)} "$@"`,
    "",
  ].join("\n");
  writeFileSync(bridge, source, { mode: 0o500, flag: "wx" });
  return bridge;
}

function sandboxPreflight(root, museBin) {
  const checkScript = join(root, "scripts", "dev", "check-muse-linux-sandbox.sh");
  const output = commandOutput(checkScript, ["--muse-bin", museBin, "--json"], root);
  const parsed = JSON.parse(output);
  if (parsed.status !== "ready" || parsed.backend !== "muse_bundled_bwrap"
    || !parsed.binary || !parsed.selector || !parsed.selector_sha256
    || !parsed.git_guard || !parsed.git_guard_sha256 || !parsed.sha256 || !parsed.version
    || parsed.privilege_required !== false) {
    die("sandbox selector preflight returned an invalid contract");
  }
  return parsed;
}

async function withTimeout(promise, milliseconds, onTimeout) {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(async () => {
          try { await onTimeout(); } catch { /* terminal failure is recorded by caller */ }
          reject(new Error("turn timed out after protocol cancellation"));
        }, milliseconds);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

async function protocolCancel(connection, sessionId, turnId) {
  const result = await connection.command("turn/cancel", {
    commandId: connection.mintCommandId(),
    sessionId,
    turnId,
  });
  if (result.status !== "accepted" || result.turnId !== turnId) die("turn/cancel returned an invalid acknowledgement");
  return result;
}

export function releaseLeasesAfterClose(closeCompleted, sessionLease, worktreeLease) {
  if (closeCompleted !== true) return false;
  const sessionReleased = releaseOwnLease(sessionLease);
  const worktreeReleased = releaseOwnLease(worktreeLease);
  return sessionReleased && worktreeReleased;
}

function classifyError(error) {
  const text = `${error?.message ?? error}`;
  if (/sessionInUse|session in use|already in use|leaseUnavailable/i.test(text)) return "session_in_use";
  if (/timed out/i.test(text)) return "timed_out";
  if (/approval/i.test(text)) return "approval_failure";
  return "failed";
}

export {
  acquireInitialLeases,
  acquireLease,
  approvalDecision,
  classifyError,
  exactApprovalMatch,
  leasePaths,
  loadApprovalAllowlist,
  MSP_APPROVAL_MODE,
  pidState,
  protocolCancel,
  readLease,
  releaseOwnLease,
  validateOptions,
  withRegistryLock,
};

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  if (options.help) {
    usage();
    return 0;
  }
  const root = repoRoot(process.cwd());
  validateOptions(options, root);
  const stateDir = join(root, "tmp", "codex-claude", "state", "muse-msp");
  mkdirSync(stateDir, { recursive: true, mode: 0o700 });
  if (lstatSync(stateDir).isSymbolicLink()) die("Muse MSP state directory must not be a symlink");
  if (realpathSync(stateDir) !== stateDir) die("Muse MSP state directory escaped the repository-owned tmp root");
  const initialPaths = leasePaths(stateDir, options.worktree, options.resume);
  if (options.inspectLease) {
    process.stdout.write(`${JSON.stringify({
      worktree: readLease(initialPaths.worktree),
      session: initialPaths.session ? readLease(initialPaths.session) : { state: "not-requested" },
    }, null, 2)}\n`);
    return 0;
  }

  die("live Meta MSP is disabled: muse serve has no safe stdin credential channel; use scripts/dev/agent-call-muse.sh");

  const artifacts = makeArtifacts(root, options);
  const emit = eventWriter(artifacts.events);
  const startedAt = Date.now();
  const promptBytes = options.promptFiles.reduce((total, file) => total + readFileSync(file).byteLength, 0);
  const preHead = commandOutput("git", ["rev-parse", "HEAD"], options.worktree);
  const preChangedFiles = safeGitStatus(options.worktree);
  const allowlist = loadApprovalAllowlist(options.approvalAllowlist);
  const configuredApprovalEntries = allowlist.length;
  const sandbox = sandboxPreflight(root, options.museBin);
  const sandboxBridge = createSandboxBridge(artifacts.runDir, sandbox);
  const token = randomUUID();
  const leaseBase = { pid: process.pid, token, startedAt: new Date(startedAt).toISOString() };
  let worktreeLease;
  let sessionLease;
  let client;
  let connection;
  let session;
  let sessionId = options.resume ?? "";
  let currentTurn;
  let outcome = "running";
  let errorClass = "";
  let errorMessage = "";
  let writerReleased = false;
  let closeCompleted = false;
  let toolItems = 0;
  let failedToolItems = 0;
  let modelSteps = 0;
  let totalInputTokens = 0;
  let totalOutputTokens = 0;
  const approvalProposals = [];
  const approvalProposalPath = join(artifacts.runDir, "approval-proposals.json");
  const transition = (state) => emit({ kind: "state", state, at: new Date().toISOString() });

  const cancelCurrent = async (reason) => {
    if (!connection || !session || !currentTurn) return;
    transition(`cancel_requested:${reason}`);
    await protocolCancel(connection, session.sessionId, currentTurn.turnId);
    transition("cancel_accepted");
  };
  const signalHandler = () => { void cancelCurrent("signal"); };
  process.on("SIGINT", signalHandler);
  process.on("SIGTERM", signalHandler);

  try {
    const initialLeases = acquireInitialLeases(stateDir, initialPaths, {
      ...leaseBase,
      worktreeIdentity: sha256(options.worktree),
      sessionIdentity: options.resume?.toLowerCase(),
    });
    worktreeLease = initialLeases.worktree;
    sessionLease = initialLeases.session;
    transition("worktree_lease_acquired");
    if (sessionLease) transition("session_lease_acquired");

    const handshake = spawnMspConnection({
      command: sandbox.git_guard,
      args: ["serve", "--sandbox-network", "restricted", "--trust-workspace"],
      cwd: options.worktree,
      env: {
        PATH: "/usr/bin:/bin",
        LANG: "C.UTF-8",
        LC_ALL: "C.UTF-8",
        MUSE_NO_AUTO_UPDATE: "1",
        MUSE_GIT_GUARD_ELF: sandbox.binary,
        MUSE_GIT_GUARD_VERSION: sandbox.version,
        MUSE_GIT_GUARD_SHA256: sandbox.sha256,
        MUSE_GIT_GUARD_BWRAP: sandboxBridge,
        MUSE_GIT_GUARD_WORKTREE: options.worktree,
        MUSE_GIT_GUARD_COMMON_DIR: gitCommonDir(options.worktree),
      },
      shutdownTimeoutMs: 5000,
      onStderr: (chunk) => emit({ kind: "host_stderr", bytes: Buffer.byteLength(chunk) }),
    });
    const spawned = await handshake.initialize({
      clientInfo: { name: "codex_desktop", title: "Codex Desktop Muse Controller", version: CLIENT_VERSION },
    });
    connection = spawned.connection;
    client = new MuseClient(connection, {
      durability: readSessionDurability(spawned.initializeResult),
      host: spawned,
    });
    transition("host_initialized");

    session = options.resume
      ? await client.resumeSession({ sessionId: options.resume, history: "auto" })
      : await client.startSession({
          workspaceRoot: options.worktree,
          modelId: options.model,
          providerId: "meta",
          approvalMode: MSP_APPROVAL_MODE,
        });
    sessionId = session.sessionId;
    const opened = session.opening?.result?.session;
    if (!opened || opened.sessionId !== sessionId) die("MSP opening omitted the exact session identity");
    if (opened.workspaceRoot !== options.worktree) die("MSP session workspace does not match --worktree-existing");
    if (opened.status === "running") die("MSP session is already running; refusing concurrent writer state");
    if (opened.modelId && opened.modelId !== options.model) die("MSP session model does not match --model");

    if (!sessionLease) {
      const sessionPath = leasePaths(stateDir, options.worktree, sessionId).session;
      sessionLease = withRegistryLock(stateDir, () => acquireLease(sessionPath, {
        ...leaseBase,
        kind: "session",
        identity: sessionId.toLowerCase(),
      }));
      transition("session_lease_acquired");
    }
    transition(options.resume ? "session_resumed" : "session_started");

    session.onApproval((request) => {
      emit({ kind: "approval", tool: request.toolName, subject: request.subject?.kind ?? "unknown" });
      const proposal = {
        toolName: request.toolName,
        subjectKind: request.subject?.kind ?? "unknown",
        rawArgs: request.rawArgs,
        ...(typeof request.subject?.path === "string" ? { path: request.subject.path } : {}),
      };
      approvalProposals.push(proposal);
      writeFileSync(approvalProposalPath, `${JSON.stringify(approvalProposals, null, 2)}\n`, { mode: 0o600 });
      return approvalDecision(request, allowlist);
    });
    session.onApprovalError((failure) => {
      emit({ kind: "approval_error", failure: failure.kind });
    });

    const replies = [];
    for (let index = 0; index < options.promptFiles.length; index += 1) {
      const text = readFileSync(options.promptFiles[index], "utf8");
      currentTurn = await session.sendUserTurn({
        input: [{ type: "text", text }],
        reasoningEffort: options.effort,
        ifBusy: "queue",
      });
      transition(`turn_${index + 1}_submitted`);
      let cancellationTimer;
      if (index === 0 && options.cancelAfterMs !== null) {
        cancellationTimer = setTimeout(() => { void cancelCurrent("test_timer"); }, options.cancelAfterMs);
      }
      const itemCollector = (async () => {
        for await (const item of currentTurn.items()) {
          if (item.kind === "toolCall" || item.kind === "userShell") {
            toolItems += 1;
            if (item.status === "failed" || item.failureKind || (Number.isInteger(item.exitCode) && item.exitCode !== 0)) {
              failedToolItems += 1;
            }
          }
          if (item.kind === "agentMessage" && typeof item.text === "string") replies.push(item.text);
          emit({
            kind: "item",
            turn: index + 1,
            itemKind: item.kind,
            status: item.status,
            tool: item.tool ?? null,
            durationMs: item.durationMs ?? null,
            exitCode: item.exitCode ?? null,
            failureKind: item.failureKind ?? null,
            truncated: item.truncated ?? false,
          });
        }
      })();
      const terminal = await withTimeout(
        currentTurn.completed,
        options.timeoutSec * 1000,
        () => cancelCurrent("timeout"),
      );
      clearTimeout(cancellationTimer);
      await itemCollector;
      currentTurn = undefined;
      modelSteps += 1;
      if (terminal.kind !== "completed") die(`turn ended without a completed terminal: ${terminal.kind}`);
      totalInputTokens += terminal.params.usage?.inputTokens ?? 0;
      totalOutputTokens += terminal.params.usage?.outputTokens ?? 0;
      emit({
        kind: "terminal",
        turn: index + 1,
        terminal: terminal.params.terminal,
        durationMs: terminal.params.durationMs ?? null,
        inputTokens: terminal.params.usage?.inputTokens ?? null,
        outputTokens: terminal.params.usage?.outputTokens ?? null,
      });
      if (terminal.params.terminal !== "completed") die(`Muse turn terminal was ${terminal.params.terminal}`);
      transition(`turn_${index + 1}_completed`);
    }
    writeFileSync(artifacts.output, `${replies.at(-1) ?? ""}\n`, { mode: 0o600 });
    outcome = "completed";
  } catch (error) {
    outcome = classifyError(error);
    errorClass = outcome;
    errorMessage = `${error?.message ?? error}`;
    emit({ kind: "controller_error", class: errorClass });
  } finally {
    process.off("SIGINT", signalHandler);
    process.off("SIGTERM", signalHandler);
    if (client) {
      try {
        await client.close();
        closeCompleted = true;
        transition("host_closed");
      } catch (error) {
        errorClass ||= "close_failed";
        errorMessage ||= `${error?.message ?? error}`;
      }
    }
    writerReleased = releaseLeasesAfterClose(closeCompleted, sessionLease, worktreeLease);
    transition(writerReleased ? "writer_released" : "writer_release_failed");
  }

  const postHead = commandOutput("git", ["rev-parse", "HEAD"], options.worktree);
  const postChangedFiles = safeGitStatus(options.worktree);
  const preChangedFileIds = [...new Set(preChangedFiles.map((path) => sha256(path)))].sort();
  const postChangedFileIds = [...new Set(postChangedFiles.map((path) => sha256(path)))].sort();
  const elapsedMs = Date.now() - startedAt;
  const manifest = {
    outcome,
    error_class: errorClass,
    control_plane: "msp_owned",
    model: options.model,
    provider: "meta",
    session_id: sessionId,
    context_class: options.contextClass,
    approval_allowlist_entries: configuredApprovalEntries,
    worktree: relative(root, options.worktree).startsWith(`..${sep}`)
      ? `registered-worktree:${sanitizeSlug(basename(options.worktree))}`
      : relative(root, options.worktree).replaceAll("\\", "/"),
    pre_head: preHead,
    post_head: postHead,
    pre_changed_file_count: preChangedFileIds.length,
    post_changed_file_count: postChangedFileIds.length,
    pre_changed_file_ids: preChangedFileIds,
    post_changed_file_ids: postChangedFileIds,
    terminal: outcome === "completed" ? "completed" : "failed",
    writer_release: { released: writerReleased, host_close_completed: closeCompleted },
    artifacts: {
      output: basename(artifacts.output),
      events: basename(artifacts.events),
      manifest: basename(artifacts.manifest),
      approval_proposals: existsSync(approvalProposalPath) ? basename(approvalProposalPath) : null,
    },
    telemetry: {
      elapsed_ms: elapsedMs,
      prompt_bytes: promptBytes,
      turn_count: options.promptFiles.length,
      model_steps_observed: modelSteps,
      tool_items_observed: toolItems,
      failed_tool_items_observed: failedToolItems,
      input_tokens_observed: totalInputTokens,
      output_tokens_observed: totalOutputTokens,
      output_bytes: existsSync(artifacts.output) ? readFileSync(artifacts.output).byteLength : 0,
      approval_requests_observed: approvalProposals.length,
      approval_allowlist_entries_consumed: configuredApprovalEntries - allowlist.length,
    },
    recorded_at_utc: new Date().toISOString(),
  };
  writeFileSync(artifacts.manifest, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  process.stdout.write(`${artifacts.output}\n`);
  if (outcome !== "completed" || !writerReleased || !closeCompleted) {
    process.stderr.write(`Muse MSP call ${outcome}${errorMessage ? ` (${errorMessage})` : ""}; manifest: ${artifacts.manifest}\n`);
    return outcome === "timed_out" ? 124 : 1;
  }
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().then((code) => { process.exitCode = code; }).catch((error) => {
    process.stderr.write(`error: ${error?.message ?? error}\n`);
    process.exitCode = 1;
  });
}
