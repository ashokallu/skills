<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (guarded v6 headless workhorse and context bridge) -->

# Muse Work Orchestration Adapter

```text
Type: specialist adapter
Use when: generic delegation selected Muse, or the user explicitly asked the
          current parent to use Muse for analysis, review, or implementation
Skip when: Muse was neither explicitly requested nor selected by an owning lane
Owns: current Muse capabilities, role permissions, execution surface, model and
      session selection, worktree binding, wrapper arguments, run evidence,
      limitations, and Muse-specific foot guns
Does not own: decomposition, largest-safe-slice selection, Child Contract,
              dispatch, supervision, retry or takeover policy, join, validation,
              authoritative review, Git publication, external writes, or final claims
Allowed side effects: no side effects by selection alone; a wrapper run inherits
                      only the parent-authorized role and explicit worktree boundary
Inputs: accepted parent objective, Child Contract, Muse role, exact target,
        execution-surface requirement, and current wrapper or CLI capability evidence
Exit states: READY | SPLIT_REQUIRED | UNAVAILABLE | BLOCKED
Outputs: capability decision, role and transport, exact invocation boundary,
         session and worktree identities, expected evidence, and parent-owned remainder
Re-enter when: Muse CLI, model availability, wrapper flags, sandbox behavior, MSP or
               TUI ownership, session state, worktree, task capability, or authority changes
```

This adapter makes Muse usable without turning it into a second orchestration
system. Enter the `work-orchestration` delegation lane first. That lane
decides whether to delegate, chooses the largest safe slice, creates the Child
Contract, supervises the call, applies the one-changed-variable retry rule, and
joins the result. Use this adapter only for the Muse-specific decisions inside
that lifecycle.

An explicit user instruction such as "use Muse for this task" selects Muse as
the collaborator, not as the owner of the whole task. Delegate as much as the
current capability matrix safely supports, split unsupported work back to the
parent, and do not silently replace Muse with another harness. Without an
explicit Muse instruction or an owning council/delegation decision, never make
Muse the default merely to conserve another model's usage.

That explicit task instruction also authorizes the parent to curate and pass
the smallest relevant non-secret repository context needed for the accepted
slice. Do not ask another ceremonial confirmation solely to add
`--confirm-contributor-data-use`; the parent supplies that flag after it has
classified every selected attachment as eligible `private-approved` context.
It never authorizes secrets, credentials, auth state, PII, customer or
production data, private logs, or ambient browsing of Codex files.

## Authority Split

| Decision or action | Owner |
| --- | --- |
| Decompose work and select the largest safe slice | Generic delegation |
| Define objective, acceptance, files, constraints, and return contract | Generic delegation through the Child Contract |
| Decide whether Muse can perform that slice now | This adapter |
| Select Muse role, model, wrapper, session, and worktree | This adapter |
| Run commands, tests, builds, lint, or browser checks | Parent or owning validation lane |
| Inspect Git and accept changed files | Parent |
| Retry once, take over, stop, or join | Generic delegation |
| Issue authoritative review, completion, safety, or publication claims | Parent and owning specialist lanes |
| Commit, push, publish, comment, or mutate external systems | Parent through the owning workflow |

Muse may return changed files, findings, unresolved questions, and suggested
validation. Those are inputs, not proof. The parent verifies decision-bearing
anchors, the exact Git state, and the acceptance criteria proportionally. Do
not reflexively repeat all sound Muse analysis, but never outsource the proof
needed for a validation, safety, review, or publication claim.

## Current Capability Snapshot

The original capability map below comes from the 2026-09-03 audit. The current
pinned release is Muse Code `1.0.3-R2198.1`, revalidated on 2026-09-04 for the
bounded standalone task read/write/managed-shell profile. Its live
`muse-work task` probe reached `muse_completed` with parent byte and Git
readback. Private PR, resume, native web, and headed/TUI behavior were not
retested on this release; do not treat the historical rows as fresh proof.

For release-over-release comparison with other workhorse candidates, also read
`docs/agents/workhorse-harness-capability-ledger.md`. This adapter remains the
owner of current Muse execution policy.

| Work shape | Current status | Required boundary |
| --- | --- | --- |
| Planning, repository analysis, criticism, or review | Supported read-only | Use `reviewer`, `critic`, `contributor`, or `none`; writes, shell, and web stay disabled |
| File implementation | Supported with constraints | Use `implementer` only in an explicit registered Git worktree different from the coordinating checkout |
| Sandboxed shell, tests, builds, lint, or generated-code commands | Supported in an isolated worktree after bundled-backend preflight | Use `workhorse`; require the version/SHA-bound bundled Bubblewrap selector, outer Git guard, restricted network, one writer, and parent Git/validation readback |
| Current external research | Supported through Codex-brokered sources; native Muse web is additionally supported only for a wholly public prompt, context, and target | Use `researcher`; require `--enable-native-web`, both public classifications, Meta-only egress, and structured invocation plus successful-result evidence for native web |
| Persistent multi-turn control | Supported by exact task-scoped headless session continuity for public work | Use `--lane` or an exact UUID/alias through the wrapper; one session writer at a time. Private-approved context is memory-only and cannot resume |
| Live Meta MSP control | Unavailable/fail-closed | `muse serve` currently lacks a credential input that is neither inherited environment nor mounted file; keep protocol tests, but use the guarded wrapper for live work |
| Commit, push, PR mutation, external-system writes, or production actions | Forbidden | Keep with the parent and the owning workflow |
| Validation, safety, completion, or publication verdicts | Forbidden | Muse may suggest checks; the parent runs and interprets them |
| Raw Muse TUI | Explicit headed observation or manual rescue only | Prove the exact terminal, tmux pane, process, session, and single-writer state before input |
| Muse Server Protocol on a TUI-owned session | Forbidden/unavailable | Never steal or attach a second controller; `sessionInUse` is a correct refusal |

If the selected slice mixes supported and unsupported capabilities, return
`SPLIT_REQUIRED`: send the analysis or file-edit portion to Muse and keep
commands, web research, validation, publication, and other unsupported actions
with their existing owners. "Maximize offload" means choose the largest safe
supported slice; it never means widening Muse permissions.

Reduced ChatGPT Pro consumption is an architectural goal, not a proved result.
The manifest can prove that a Muse turn ran, but it cannot prove counterfactual
Sol usage or subscription savings. Keep savings `Pending Verification` until a
representative task-period comparison is measured outside this adapter.

## Field Guide From The 2026-09-03 Integration Audit

The current task history was re-audited after the v6 implementation. These are
observed properties of Muse 1.0.2-R2040.1 and the repository adapter, not
generic expectations about future releases.

### Strong features worth using

- `muse exec --json` exposes structured provider, model, session, workspace,
  tool, terminal, and usage events. The wrapper validates those identities
  instead of accepting process exit 0 or model prose as completion.
- Exact session continuity works mechanically. A session survived timeout and
  real Ctrl+C, then resumed with the same contributor model and target. A
  separate two-turn mechanism smoke recovered both a phrase and a worktree
  marker from turn one. That smoke used an explicit public test classification
  over a example-app worktree, so it does not prove that this private
  repository is eligible for retained public workhorse state. Treat a genuine
  public-repository workhorse continuity smoke as `Pending Verification`.
- File tools are useful and fast. Muse created exact requested files, read them
  back, and its own `write_file` rejected `../` with `path escapes workspace`.
  The outer guard is still mandatory because managed shell has broader reach.
- The managed shell works on this Ubuntu host through Muse's bundled Bubblewrap
  selector. It can run task commands and write inside the assigned worktree
  without root installation or host AppArmor changes.
- Native `web_search` works for a wholly public researcher lane. It emits
  structured proposal/intent and successful-result events that are stronger
  evidence than a URL appearing in prose.
- The TUI is genuinely useful for a human-visible rescue session: normal
  prompts, `/help`, `/usage`, `/status`, history, queued prompts, tool-output
  expansion, keymap/feedback commands, and external-editor support were
  observed. Treat these as headed affordances, not automation authority.
- MSP can perform lease-free `session/read` metadata inspection while a TUI
  owns a session. This is useful for diagnosis only; resume correctly fails
  with typed `sessionInUse`.

### Failure signatures and the correct response

| Symptom | Meaning | Correct response |
| --- | --- | --- |
| TUI launch rejects `--disable-web-tools` or `--no-foreign-personal-context` | Those flags belong to `exec`, not interactive TUI | Use the wrapper for bounded automation; do not copy headless flags blindly into TUI launch |
| Desktop input staging says the snapshot is stale while Muse repaints | Cursor/alternate-screen output changed between stage and submit | Do not bypass revalidation. Wait for a stable composer, use one exact terminal transaction, or move the task to the headless wrapper |
| A tmux paste appears late or twice | TUI paste/render acknowledgement is asynchronous | Never press Enter until the exact intended composer contents are visible once; clear duplicates before submission |
| `session ... is already in use` / `sessionInUse` | A TUI or other host owns the model-side session | Keep one writer. Read metadata only, or close/release the owner and use a separate exact headless session |
| First Ctrl+C shows `Interrupting`; second says it will quit | One interrupt cancels the turn, two terminate the TUI | Send one exact Ctrl+C, wait for idle and `activeTurnId: null`; never reflexively send a second |
| Background `kill -INT` does nothing in a shell test | Background-launched POSIX scripts may inherit SIGINT ignored | Use SIGTERM for deterministic background coverage and reserve real Ctrl+C for an integrated-terminal smoke |
| `--worktree-existing must differ from --workspace` | Muse distinguishes coordinator workspace from delegated worktree | Use the repo wrapper; do not pass the worker as both identities |
| `tool.bash` stalls under `untrusted` | The mode may wait for an approval that the one-shot parent cannot answer | Use the reviewed wrapper profile; never add `--yolo` or disable sandbox/approval |
| `bwrap: execvp /dev/.tbh-linux-sandbox: No such file or directory` | On this host, Ubuntu's AppArmor profile denied Bubblewrap's deleted-entry helper mechanism and surfaced ENOENT | Run the pinned preflight and bundled-Bubblewrap selector. Do not install a copied helper, change AppArmor, or treat the message as a missing-package prompt |
| External helper works only with dotted basename or private mode variables | Muse dispatches helper behavior by executable seam and internal mode | Do not recreate the helper protocol. The repo selector binds the exact Muse ELF/version/SHA and uses Muse's bundled backend |
| Custom selector variables disappear in an inner helper | Muse sanitizes/reconstructs environment across its sandbox layers | Carry only pinned non-secret identity through the reviewed executable seam; never rely on arbitrary ambient variables |
| `session/userShell` is offered by MSP | This is the TUI `!` escape hatch, not managed sandboxed shell | Reject it. It was observed writing the shared Git config outside the worker |
| Managed shell can write `.git/config` or the linked-worktree `.git` file without the outer guard | Muse's workspace boundary does not protect shared Git metadata | Require the positive-allowlist outer guard and independently compare Git pointer/config hashes |
| A once-only approval request repeats | Approval tuples are replay-sensitive and include model-authored description text in `rawArgs` | Consume exact tuples once; never use wildcard or reusable approvals. Live Meta MSP remains disabled |
| `read_file` reaches the coordinator or unrelated home under `--ro-bind / /` | Read-only prevents corruption, not disclosure; Muse's file permission can read broad roots | Never restore a whole-root read-only bind. Use the positive mount allowlist and explicit context snapshots |
| Muse authenticates from `META_API_KEY`, then shell can print it | Inherited credential environment crosses into managed tools | Use only `--api-key-stdin` with `env -i`; wrapper-level unsets are insufficient because Muse reconstructs tool environments |
| A native-web run returns a URL but the wrapper sees no web event | Parser may be looking in the wrong JSONL fields | Require lifecycle `event.task_kind`/`event.operation` plus successful `correlation_facts.tool_name`; prose is not proof |
| Terminal says completed but no expected diff/tool result exists | A model refusal or partial objective can still be a completed turn | Inspect events, final response, exact file bytes, and parent Git readback before accepting work |
| Contributor role refuses a bare exact-token smoke and returns an alternative plan | The contributor overlay requires a concrete alternative, tradeoffs, and validation | Use `--role none` for pure transport tokens; use contributor for substantive work and keep its structured return contract |

### Boundaries that must not drift

- Headless wrapper is the automation seam; raw TUI is visible manual rescue.
- One model-side session has one writer. A terminal, wrapper, and MSP controller
  must never race for it.
- Public exact-lane continuity is supported. Private-approved context is
  ephemeral, non-resumable, and deleted after ingestion.
- Public calls are unretained one-shots unless the parent explicitly supplies a
  lane, alias, or exact resume identity. Do not create durable state or update a
  checkout-global latest pointer for an ordinary call.
- The whole mounted checkout is context. Every example-app checkout is
  private even when the selected files look public, so example-app workhorse
  calls use fresh private-approved turns. Do not relabel one file, fixture, or
  task as public to unlock native web or retained state.
- Muse may reason, edit, and run bounded local commands in its exact target.
  Codex still owns decomposition, context selection, validation interpretation,
  Git acceptance, review verdicts, publication, and external/production actions.
- Built-in path containment is defense in depth, not a substitute for the
  positive mount allowlist, read-only Git metadata, clean environment, stdin
  credential transport, and Meta-only egress proxy.

## Role And Worktree Selection

Use the smallest role that satisfies the Child Contract:

| Role | Intended use | Filesystem writes | Shell | Web |
| --- | --- | --- | --- | --- |
| `reviewer` | Findings-first review of a stable target | No | No | No |
| `critic` | Challenge a plan or decision record | No | No | No |
| `contributor` | Read-only analysis, alternatives, or drafting returned in chat | No | No | No |
| `researcher` | Brokered-source analysis, or explicitly enabled wholly public native research | No | No | Disabled unless all public gates pass |
| `none` | A bounded prompt that needs no role overlay | No | No | No |
| `implementer` | File edits for one explicit ownership slice | Only inside `--worktree-existing` | No | No |
| `workhorse` | File edits plus task-relevant local commands | Only inside `--worktree-existing` | Managed sandbox only | No; provider egress only |

For `implementer` and `workhorse`, the worktree must already be registered with Git, must be
different from the coordinating checkout, and must be the exact write scope in
the Child Contract. One Muse writer owns one model-side session and one
worktree at a time. Do not let the parent or another worker edit overlapping
files until the run reaches a terminal state and releases the writer.

The current wrapper default is `muse-spark-1.3-contributor`. Use
`--model muse-spark-1.3` only when the user explicitly requests the base model
or current capability evidence justifies it. Verify `muse --help` and
`scripts/dev/agent-call-muse.sh --help` before relying on model, effort, role,
session, worktree, or safety flags after a Muse or wrapper change.

## Execution Surface

### Standalone `muse-work` controller

Use `scripts/dev/muse-work` when a human or another agent needs the complete
private task or PR workflow without relying on Codex to prepare it. The
controller is model-free: it resolves the target, prepares the worktree,
brokers private PR evidence through host `gh`, calls the existing guarded
wrapper, records minimal resumable state, and performs independent Git
readback. It does not replace the wrapper or grant Muse new permissions.

Pass task and follow-up text through stdin or a private regular prompt file;
never put prompt text in argv:

```bash
printf '%s' "$task" | scripts/dev/muse-work task
scripts/dev/muse-work task --prompt-file "<private-prompt-file>" --base "<ref>"
scripts/dev/muse-work pr <pr-number>
printf '%s' "$followup" | scripts/dev/muse-work resume <run-id>
scripts/dev/muse-work cleanup <run-id>
```

`task` creates a unique detached registered worktree at one exact commit,
runs `prepare-worktree-readiness.sh`, and invokes the `workhorse` role. `pr`
reads the current exact head and base with host-authenticated `gh`, reuses or
creates only a clean canonical PR worktree, builds the complete diff packet,
and invokes the read-only `reviewer` role. Readiness may update worktree-local
Git configuration and download the pinned Husky or Go tooling; it is a
host-side setup phase, not a no-op probe.

`resume` means workflow continuity only. It reopens the exact recorded run and
worktree, verifies the content-sensitive dirty-state fingerprint, and sends
the original objective, compact prior result, and new follow-up in a fresh
private-approved Muse turn. It never passes a Muse session ID, alias, lane,
`latest`, or `last`.

Private controller state lives under `tmp/muse-work/runs/<run-id>` with
mode-700 directories and mode-600 files. It retains only the exact target
binding, original objective, compact result, and attempt state. Raw PR packets
and wrapper JSONL events are transient and are removed after exact-PID-bound
ingestion. PR packets are complete-or-fail: invalid UTF-8, more than 16
attachments, any attachment over 1 MiB, or more than 4 MiB total blocks the
Muse call; the controller never truncates or omits part of the diff.

Cleanup requires the exact run ID and non-stealing run/worktree locks. It
removes an owned worktree only when the recorded target is still clean and
unchanged, leaves reused PR worktrees in place, then removes the exact private
run state. A task with Muse edits is deliberately not cleanup-eligible: inspect
and preserve or deliberately discard its Git work first. There is no force
cleanup mode.

The controller reports `muse_completed` only for a validated wrapper terminal
result. That is not an engineering, validation, review, or publication
verdict. The returned worktree, changed-file inventory, compact result, and
manifest are the handoff for the next human or owning agent.

The deterministic lifecycle suite is current, but corrected end-to-end live
operation remains `Pending Verification`: the first live task smoke exposed a
failure-ingestion defect, which was repaired without spending a second Muse
turn. Require one fresh bounded `muse_completed` run plus exact Git readback
before promoting the standalone composition to fully demonstrated.

### Deterministic headless wrapper

Use `scripts/dev/agent-call-muse.sh` for analysis, review, research, file
implementation, sandboxed workhorse turns, and exact public-lane follow-ups. Supply the
prompt through standard input or `--prompt-file` when practical; the wrapper
uses a private temporary prompt file and removes it after the call.

```bash
printf '%s' "$prompt" | scripts/dev/agent-call-muse.sh \
  --role contributor \
  --target-class public \
  --context-class public \
  --session-alias "<stable-lane>" \
  --title "<artifact-slug>"
```

Before the first `workhorse` run after any Muse update or wrapper change,
inspect the exact active ELF identity and statically review the selector:

```bash
scripts/dev/check-muse-linux-sandbox.sh --json
sha256sum scripts/dev/muse-bundled-bwrap.sh
sha256sum scripts/dev/muse-git-guard.sh
```

The preflight, selector, and outer guard are non-privileged. Every live Muse
role binds them to the active Muse release filename and SHA-256,
proves that Muse's bundled Bubblewrap exposes the required capabilities, and
fails closed after binary, selector, guard, or proxy drift. The positive
allowlist guard does not mount `/`. It mounts the exact target read-only or
writable according to role, mounts the linked worktree's `.git` pointer and
shared Git common directory read-only, exposes only exact lane state when
public continuity is requested, and gives the child private `/home`, `/run`,
and `/tmp`. The child therefore cannot browse Codex memory, task history, Muse
auth, unrelated user files, or unlisted system paths. Muse's inner managed-shell
sandbox retains restricted network, while the outer loopback CONNECT proxy
permits only `api.meta.ai:443`.
This additional boundary is mandatory because the current Muse managed shell
can otherwise write a linked worktree's shared Git common directory. Do not
install a copied Muse ELF as an external sandbox helper: on the currently
verified Ubuntu host, the system `bwrap` AppArmor profile rejects Muse's
deleted-entry embedded helper. The repo-owned selector uses Muse's bundled
Bubblewrap without changing AppArmor or narrowing the normal command `PATH`.

```bash
printf '%s' "$prompt" | scripts/dev/agent-call-muse.sh \
  --role workhorse \
  --worktree-existing "<registered-worker-worktree>" \
  --target-class private \
  --context-class private-approved \
  --confirm-contributor-data-use \
  --title "<artifact-slug>"
```

Private-approved calls are deliberately memory-only: they use
`--no-session-log`, reject `--lane`, `--session-alias`, and `--resume`, and
their completed run directory must be deleted after the parent has ingested
the result. Public continuity uses an exact lane-scoped UUID and isolated
state:

```bash
CODEX_THREAD_ID="<current-thread-id>" \
  scripts/dev/agent-call-muse.sh \
  --role workhorse \
  --worktree-existing "<registered-worker-worktree>" \
  --target-class public \
  --context-class public \
  --lane "<task-lane>" \
  --prompt-file "<turn-file>"
```

For current research, Codex first collects sources and writes each bundle with
`Source-URL`, `Retrieved-At`, `Source-Title`, and a `---` separator. Muse only
analyzes those bundles:

```bash
scripts/dev/agent-call-muse.sh \
  --role researcher \
  --target-existing "<public-git-checkout>" \
  --target-class public \
  --context-class public \
  --source-file "<provenance-labelled-source-bundle>" \
  --prompt-file "<research-question-file>"
```

Native web is a narrower public-only option. It is valid only when the prompt,
every context attachment, and the entire mounted target are public:

```bash
scripts/dev/agent-call-muse.sh \
  --role researcher \
  --target-existing "<public-git-checkout>" \
  --target-class public \
  --context-class public \
  --enable-native-web \
  --prompt-file "<public-research-question-file>"
```

The call fails unless JSONL contains a structured web proposal or side-effect
intent and a successful `tool.result`. Any private, internal, mixed, unknown,
or unclassifiable target stays on Codex-brokered sources.

### Persistent MSP controller

The pinned MSP package retains protocol, lease, approval, cancellation, and
close/release tests, but live Meta MSP is intentionally disabled:

```bash
npm --prefix scripts/dev/muse-msp ci --ignore-scripts
node scripts/dev/muse-msp/muse-msp-controller.mjs --help
```

`muse exec` accepts `--api-key-stdin`; `muse serve` currently does not. Passing
the key through inherited environment exposed it to managed shell, while
mounting auth would expose it to file tools. The controller therefore refuses
live Meta startup and directs callers to the guarded wrapper. Re-enable live
MSP only after the installed server offers an equivalent non-environment,
non-file credential transport and the full guard/egress suite passes.

```bash
printf '%s' "$prompt" | scripts/dev/agent-call-muse.sh \
  --role implementer \
  --worktree-existing "<registered-worker-worktree>" \
  --target-class public \
  --context-class public \
  --session-alias "<stable-worker-lane>" \
  --title "<artifact-slug>"
```

Resume only public work by exact supplied session ID or stable wrapper alias:

```bash
printf '%s' "$followup" | scripts/dev/agent-call-muse.sh \
  --role contributor \
  --target-class public \
  --context-class public \
  --resume "<session-id-or-alias:name>" \
  --title "<artifact-slug>"
```

Do not resume private-approved work. Do not use `latest` or `last` for a
workhorse; other read-only roles require the parent to explicitly accept the
checkout-global ambiguity and pass `--allow-unsafe-latest`.

### Tmux around the wrapper

Tmux may keep the same wrapper process alive and observable. It adds process
lifetime and exact pane addressing; it grants no capability and does not
replace the wrapper, its manifest, or the parent wait obligation. Use
`tmux-persistent-sessions.md` for generic socket, pane, wait, and cleanup
mechanics, then return here for Muse session and evidence rules.

### Raw TUI

Use raw `muse` TUI only when the user explicitly wants a visible headed Muse
session or the wrapper path needs manual rescue. Treat it as a single-owner
interactive surface, not a worker API. Before every input transaction, verify
the exact integrated terminal, private tmux socket and pane when present,
running Muse process, visible prompt state, model-side session ID, and absence
of another writer. Closed or ambiguous input state fails closed.

Do not attach Muse Server Protocol or another controller to the same TUI-owned
session. A live 2026-09-03 Codex Desktop probe resumed the requested session,
but Muse continuously repainted without a stable alternate-screen identity;
the safe stage-and-submit API therefore rejected stale input. MSP independently
returned `session already in use` and released its own leases. If the user wants
headless automation, finish or release the TUI writer and use a separate
wrapper or MSP-owned session. Raw TUI automation remains a rescue/inspection
lane, not the primary orchestration seam.

## Context And Artifact Boundary

Muse has no ambient context authority. The parent decides what it needs and
passes only explicit `--context-file` or `--source-file` inputs. Each selected
file is snapshotted once as a regular, non-symlink UTF-8 file, bounded to 1 MiB;
the call allows at most 16 files and 4 MiB total. Prompt labels contain ordinal,
size, and SHA-256 only, never the source path. The sandbox sees the composed
prompt read-only and cannot reach the source file or browse Codex memory,
session history, auth, or unrelated private data.

The mounted checkout is context too. `--target-class` is mandatory in effect:
`internal`, `private`, or the fail-closed default `unknown` requires
`--context-class private-approved` and the contributor acknowledgement. Only a
public target with public context may create or resume persisted session state.

Contributor defaults to `--context-class public`. Secrets, credentials, auth
state, PII/customer/production data, private logs, and unredacted personal
context are forbidden for every Muse role. Private/proprietary repository
context requires `--context-class private-approved`; contributor additionally
requires `--confirm-contributor-data-use` after the user accepts the current
model's data-use warning. Unknown context fails closed. Do not infer that the
base model has equivalent privacy terms.

The wrapper reads the Meta credential outside the sandbox and sends it only via
`--api-key-stdin`. Muse starts under `env -i`; inherited shell variables are
discarded, and the credential is absent from argv, the child environment, and
environment-exposed `/proc` surfaces. The provider base URL is fixed to
`https://api.meta.ai/v1`. Retained artifacts
are mode 600 and may contain selected context or model quotations. Manifests
retain counts, hashes, sizes, and sanitized identifiers, not attachment source
paths or environment values.

Cleanup defaults to dry-run and removes only completed, directly contained
per-run directories older than an explicit age. Private closeout removes one
exact owned completed run after parent ingestion:

```bash
scripts/dev/clean-agent-call-muse.sh --older-than-days 30
scripts/dev/clean-agent-call-muse.sh --older-than-days 30 --apply
scripts/dev/clean-agent-call-muse.sh --run "<exact-private-run-directory>" --apply
```

## Evidence And Return Contract

Every wrapper call must produce or identify:

- the final response artifact;
- JSONL events;
- the adjacent `run.json` manifest;
- requested and observed model/provider/session/worktree identities;
- terminal state and process exit evidence;
- independent pre/post Git readback for implementation; and
- confirmation that the session/worktree writer released before resume,
  takeover, or join.

File creation is not completion. If the file exists but the run has no
completed terminal state, matching worktree, released writer, or independent
Git readback, classify it as interrupted or indeterminate and return to generic
delegation. Muse's own statement that the tree is clean or dirty is advisory;
Git output from the exact worktree is authoritative.

A terminal `completed` event means the model turn ended, not that every tool
call or delegated objective succeeded. Inspect structured events, the final
response, and independent Git/validation evidence before accepting the work.

The Muse return should be compact and integration-ready:

```text
Muse return:
- session and role:
- terminal outcome and manifest:
- worktree and changed files:
- findings or implementation summary:
- unresolved questions:
- suggested parent validation:
- unsupported remainder returned to parent:
```

## Known Foot Guns

- Raw TUI ingress may be closed even while the TUI remains visible. Never
  infer write authority from a rendered screen alone.
- A live TUI owns its session. MSP or another controller can fail with
  `sessionInUse`; do not race, steal, or duplicate that writer.
- MSP `session/userShell` is the TUI `!` escape hatch, not Muse's managed
  sandboxed shell. It can write outside the assigned worktree; the controller
  rejects `--user-shell-file`, and agents must not invoke the raw protocol
  method. Shell work goes through model-proposed managed tools inside the
  guarded wrapper. The one-shot exec surface has no structured approval
  channel; its capability is predeclared by the parent-selected role and Child
  Contract.
- The current unguarded managed shell can mutate a linked worktree's `.git`
  pointer or shared Git common directory. Managed shell is supported only through the
  version/SHA-bound bundled Bubblewrap selector and outer Git guard after both
  pass preflight. Never call Muse workhorse directly or respond to failure with
  `--yolo`, `--disable-sandbox`, `--disable-approval`, or a legacy shell escape.
- Shell remains disabled for `implementer`; use `workhorse` in an isolated
  registered worktree when command execution is part of the accepted slice.
- Native Muse web is enabled only for `researcher` when prompt, context, and the
  entire mounted target are explicitly public. The wrapper requires structured
  invocation and successful-result evidence. Otherwise use Codex-brokered
  source bundles.
- A created file does not prove the run completed. Require terminal, manifest,
  writer-release, worktree, and Git evidence together.
- The wrapper's default eight model steps can be exhausted by required
  instruction loading and target discovery on a broad review, leaving an empty
  final response with a failed terminal. Choose a bounded initial
  `--max-model-steps` from the Child Contract. If this exact failure still
  occurs, return to generic delegation; its one-changed-variable retry may
  increase the ceiling once while resuming the exact released session.
- Do not trust a model-authored dirty-state summary over Git readback.
- Keep prompt bodies and context out of process arguments and telemetry. The
  old `--allow-sensitive-context` bypass is removed; forbidden data classes
  remain forbidden even after private-context acknowledgement.
- Caller-selected artifact paths are intentionally unsupported. Do not
  reintroduce arbitrary output paths that can overwrite files or escape exact
  private-run cleanup; every call owns one newly created run directory.
- Do not let parallel calls share a mutable latest-session pointer, wrapper
  alias, model-side session, tmux pane, or write worktree.
- Live Meta MSP is fail-closed because `muse serve` has no safe stdin credential
  channel. Do not reintroduce inherited-key or mounted-auth workarounds.
- Never delete or rewrite a stale MSP lease automatically. Inspect it, prove
  the prior owner is terminal, then use an owner-directed recovery outside the
  controller; a stale file is evidence, not permission to steal.

## Revalidation And Exit

An installed CLI upgrade does not automatically upgrade the admitted adapter.
`scripts/dev/check-muse-linux-sandbox.sh --json` deliberately rejects a
different release or ELF digest. Do not bypass that rejection or substitute a
new hash solely because the binary starts. Inspect the new headless flags and
bundled backend, preserve the guard/proxy/credential contracts, update the exact
preflight and test pins, run deterministic checks, then run an authorized
bounded live probe. Append the release-specific outcome to the capability
ledger without rewriting earlier snapshots.

The deterministic checks are `scripts/dev/check-agent-call-muse.sh` and
`python3 -m unittest discover -s scripts/dev -p test_muse_work.py`.
If the former reports a missing SDK import, use the locked installation in the
MSP section before retrying; that setup failure is not a runtime verdict.
Keep paid probes small and use low effort when the owner permits it. A step
limit and timeout are not token or monetary ceilings.

Re-run capability checks after any Muse CLI or model release, wrapper edit,
changed help output, sandbox backend or host AppArmor change, MSP behavior
change, TUI control change, session conflict, or worktree mismatch. Re-enter
generic delegation when the capability decision changes the slice, a retry is
needed, takeover is considered, or results are ready to join.

Return:

- `READY` when one exact role, surface, session, worktree boundary, and evidence
  contract can execute the selected slice;
- `SPLIT_REQUIRED` when Muse can safely own only part of the Child Contract;
- `UNAVAILABLE` when current Muse capability cannot satisfy the selected slice;
  or
- `BLOCKED` when writer ownership, identity, authorization, or evidence is
  ambiguous.
