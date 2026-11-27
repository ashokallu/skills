<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-05 (Pi and Luna runtime preflight ownership) -->

# Real-model Behavior Evaluation

Use this lane when a behavior run will call a real model, when any selected
task uses a prompt grader, or when a provider, model, or grader failure must be
diagnosed. It prevents a paid run from testing the wrong candidate, sending an
unresolved model name to the provider, or reporting a contradictory grader
result as behavioral proof.

Mock trigger suites that make no provider-backed candidate or judge call do not
activate this lane. A provider-backed behavior candidate activates it even when
the selected task uses only a deterministic program grader.

## Deterministic VPN Route Selection - First Action

Before a real behavior run, use the focused selector rather than choosing a
provider or executor from memory:

```bash
scripts/dev/run-behavior-eval.rb \
  --suite <behavior-eval.yaml> \
  --task <focused-task-id> \
  --route auto
```

`auto` invokes `scripts/dev/agent-collab-vpn-smoke.sh` exactly once. A passing
smoke selects the Waza/Copilot lane. A failed smoke selects the Pi OpenAI Codex lane;
it is no longer an instruction to retry Waza, inspect LiteLLM, switch a Waza
model, or ask the user to connect before the independent fallback is checked.
Use `--route vpn` or `--route no-vpn` only when the user or a current enclosing
workflow explicitly fixes that environment branch. The explicit VPN route
still requires a passing smoke and fails closed otherwise.

Keep canonical Waza behavior specs schema-valid. Waza 0.38.0 accepts `mock` and
`copilot-sdk`, not `pi`; never write `executor: pi` or a Pi model name
into Waza model fields. A CLI override such as `--model mock` or
`--judge-model mock` does not prove a run is offline when the eval still
declares `executor: copilot-sdk` or includes a prompt grader.

### VPN Enabled - Waza/Copilot Contract

After the selector's VPN smoke passes, the Waza lane retains the candidate
isolation, effective-model preflight, grader transport, focused-first, and paid
iteration requirements below. Waza output is evidence only for the exact
candidate, task, provider route, and models recorded by that run.

The selector builds a temporary Waza overlay, copies each selected
`--instruction-file` into its context allowlist, and records explicit execution
and prompt-grader models in the overlay before the provider call. It uses an
already explicit non-`auto` suite or grader model when present. Otherwise the
VPN route fails closed until the caller supplies `--waza-model <model>` and, for
a selected prompt grader, `--waza-judge-model <model>` from the current
supported-model preflight. These flags are VPN-lane inputs; they do not change
the fixed Pi identity on the no-VPN lane.

After Waza returns, the selector verifies that the JSON result names the
selected execution model and writes a sibling `.contract.json` artifact. That
contract binds the result digest to source `HEAD`, the exact suite, task,
target-skill, selected-instruction, rubric, and program-grader file digests,
plus requested execution and judge models. Keep effective judge-model identity
`Pending Verification` unless the Waza result itself proves it. Result paths
must stay below `tmp/waza-results` and must not overwrite prior evidence.

### VPN Disabled - Pi OpenAI Codex Contract

When the smoke fails, the selector may run one focused task through Pi using
OpenAI subscription OAuth with `openai-codex/gpt-5.6-luna` at low thinking for
a fresh candidate call and, for a rubric-backed prompt grader, a separate fresh
judge call. Supply every linked reference needed by the behavior explicitly
with `--instruction-file`. The runner accepts files inside the selected target
skill tree and repo-owned Markdown instructions transitively named by the
target skill or another supplied instruction; unrelated repository files fail
closed. Before spending the candidate call, inspect the selected target skill
for mandatory linked reads and confirm that the selector's
`--dry-run` `candidate_visible_inputs` inventory contains every one needed for
the task. A target skill that delegates its final output contract to a linked
reference is not a complete candidate without that reference. It streams the
authoritative candidate text bytes unchanged to program graders. Inline `config.prompt` graders are unsupported and block this route; convert their
acceptance text to output-aware `config.rubric` transport before using Pi.

Immediately before the first Pi model call, the runner requires the current Pi
model catalog to advertise the exact `openai-codex` / `gpt-5.6-luna` pair and
requires `pi auth check` to report `ready` OAuth for that pair. It removes an
inherited `OPENAI_API_KEY` from the isolated child process so API-key state
cannot silently replace the approved subscription route. A missing executable,
catalog mismatch, auth mismatch, or malformed preflight fails closed.

Each Pi call uses a separate temporary workspace, `--no-session`, and explicit
disables for tools, extensions, skills, prompt templates, themes, context files,
and project approval. It also fixes the provider, model, thinking level, JSON
stream mode, and a minimal system prompt. The rendered task and allowlisted
context travel through one explicit `@evaluation-prompt.md` file inside that
isolated workspace, avoiding command-line size limits without enabling ambient
file discovery. Runner-supplied candidate inputs are
only the task, target `SKILL.md`, and explicitly allowlisted target-skill files.
Runner-supplied judge inputs are only the task, candidate output, and
rubric-derived grading contract.

The trace parser rejects malformed or unknown events, every tool event or tool
content block, non-empty terminal `toolResults`, missing or duplicate terminal
evidence, pending retry, non-success stop reason, stderr, and provider, model,
or API identity mismatch. Prompt instructions not to call tools are not
isolation proof; the required CLI disables and audited zero-tool trace are.

Label a successful fallback result `Pi OpenAI Codex behavior evidence`. The
provider, model, and API fields in Pi's local trace are trace identity, not
provider-side effective-model telemetry. Keep effective provider-model identity
`Pending Verification` unless an independent provider-side artifact proves it.
The result does not prove Waza or Copilot/LiteLLM execution.
`tmp/litellm-supported-model-slugs.md` is a dated LiteLLM inventory, not Pi
availability evidence and never a future-availability guarantee. A live Pi
failure or trace schema the runner cannot audit returns `Pending Verification`;
do not fall back to another model or silently skip a grader.

The Pi result records source `HEAD`, the same exact input-file digests used by
the VPN contract, one deterministic candidate digest over that inventory, and
the invocation and trace audit. A separate runner digest binds the evidence to
the exact selector implementation used. The result also refuses to overwrite a
prior file below `tmp/waza-results`.

## Inputs And Ownership

Before preparing the run, record:

```text
Real-model run contract:
- candidate: <source SHA plus changed and new governed files>
- candidate digest: <digest over the exact evaluated instruction and eval files>
- suite: <repo-relative eval path>
- focused task: <task ID>
- execution model: <explicit model or unresolved>
- prompt-grader model: <explicit model per participating grader or none>
- authorized scope: <focused task only | named tasks | full suite>
- result artifact: <planned local result path>
```

The authoring or instruction-maintenance lane owns the candidate. This lane owns
evaluation isolation, effective-model proof, execution order, result integrity,
and cost expansion. It does not authorize canonical eval rewrites, provider
configuration changes, broad paid execution, or product/instruction fixes.

## Candidate And Write Boundary

Create an agent-owned isolated evaluation workspace that contains the exact
current candidate, not merely committed `HEAD`. Include applicable tracked
diffs and new instruction, reference, grader, fixture, and eval files. Record
the source SHA, governed file inventory, and a content digest after assembling
the workspace. If the candidate changes, its digest and every result against
the old digest become stale.

Create the workspace outside the active repository root, or prove it has an
independent Git worktree boundary before using Git to assemble the overlay. A
plain descendant directory inherits the parent repository, so `git -C
<descendant> apply` can target the active checkout instead of the copied
candidate. After applying tracked changes and copying new files, compare every
changed source path with its isolated counterpart by immutable content digest.
A missing or mismatched path blocks the provider call.

Modify temporary model settings only in that isolated overlay. Never rewrite
canonical eval YAML merely to make a run executable. Never delete, move, or
rewrite unrelated ignored artifacts to repair skill discovery. Never stage or
publish the overlay or its result files as part of the candidate.

An agent-owned isolated evaluation clone may contain an untrusted `.mise.toml`
even when the active checkout's toolchain is healthy. For static JS, YAML, and
fixture gates, do not mutate mise trust merely to make the disposable clone
run. Resolve and record the already verified absolute runtime binaries before
entering the clone, then constrain `PATH` for the complete test process tree so
nested scripts cannot resolve back through mise shims. An absolute top-level
`node` or `ruby` invocation alone is insufficient when its children use
`/usr/bin/env` or bare runtime names. This exception is evaluation-only: when
the proof actually depends on a branch-managed compiler, package manager, mise
task, or authoring worktree, use `worktree-readiness`, trust the exact
worktree config, and prove the branch-pinned toolchain instead.

For the Pi/Luna route, do not repair this boundary by hand-editing `PATH`. The
repo runner owns it. It rejects a `pi` executable that resolves to the mise
shim, first asks mise for the active Pi launcher from the trusted repository,
then falls back to the installed Node-runtime inventory only when exactly one
complete `bin/pi` plus sibling `bin/node` pair exists. The runner prepends that
exact runtime directory for model-catalog, OAuth, candidate, and judge child
processes, while preserving the parent Ruby path. If discovery is ambiguous,
resolve the intended installed runtime read-only and pass:

```bash
scripts/dev/run-behavior-eval.rb \
  --suite <behavior-eval.yaml> \
  --task <focused-task-id> \
  --route no-vpn \
  --pi-bin <absolute-node-runtime>/bin/pi
```

`--pi-bin` must be absolute, executable, non-shim, and accompanied by an
executable sibling `node`. Failure occurs before model-catalog or OAuth checks,
so it is a runtime-preflight failure and consumes no paid verification
iteration. Do not retry a provider call until the dry run records the selected
Pi, Node, and runtime-bin identities.

Before execution, search the evaluation workspace for another `SKILL.md` with
the same skill name. Expose only the intended canonical skill directory,
explicitly supplied linked instructions, and the required relative grader or
fixture paths. An outside-tree instruction is valid only when its repo-relative
path is named by the target skill or another supplied instruction. A duplicate
or ambiguous skill path or an unrelated context file blocks the provider call
until isolation is corrected.

Waza 0.38.0 eagerly injects the selected target `SKILL.md`, but it does not
expand that skill's linked references into the task workspace. When a focused
behavior depends on one of those references, add the exact candidate reference
as an `instruction_files` entry or task resource in the isolated overlay only.
Bind it to the candidate by path and content digest before the call. Do not
duplicate the reference text in canonical task YAML or mistake the injected
target body for proof that the linked reference was available.

## Cheap Gates First

After route selection and before any provider call in the selected lane:

1. Run the suite's deterministic contracts, parser checks, fixture self-tests,
   and mock trigger evals that cover the candidate.
2. Validate the isolated YAML and required relative paths.
3. Select one representative task whose failure would meaningfully challenge
   the changed behavior.
4. Confirm that the authorized scope covers that focused task. Full-suite
   authorization does not waive the focused-first gate.

A deterministic failure returns to instruction or eval authoring. Do not spend
model tokens to rediscover it.

## Effective-model Preflight

Resolve the effective model in the isolated overlay before contacting the
provider:

- set the suite execution model to an explicit supported model;
- set every participating prompt grader's nested model configuration to an
  explicit supported judge model; and
- inspect the selected suite and task files to prove that no participating
  execution or prompt-grader model still resolves to `auto`.

CLI `--model` and `--judge-model` arguments may still be supplied, but their
presence is not proof that nested task-level grader configuration was
overridden. The inspected overlay is the proof. If any participating model is
missing, unsupported, ambiguous, or still `auto`, stop before the provider
call and report model resolution as `Pending Verification`.

Bind the run to one explicit provider route before the focused call. Inspect
only secret-safe environment names, endpoint host, and model identifiers; never
print provider credentials. For GitHub Copilot MaaS, remove inherited custom-
provider variables only from the isolated child process and require the
executor transcript's provider/system model declaration to match the selected
model. For BYOK, preserve the authorized provider variables and record that
Waza omits the CLI startup `--model` while supplying the requested model in the
per-session provider config. In that mode the CLI's static system banner can
name its local catalog fallback and is not effective-model proof. Require
provider-side request telemetry or an equivalent secret-safe model readback in
addition to the inspected Waza session configuration. If the selected route,
requested model, and route-appropriate model evidence do not agree, invalidate
the run and stop before broader execution. Never report the requested model as
executed from result config alone.

Inspect the focused transcript for an executor-owned response-length or
formatting instruction that conflicts with the rubric. A generic brevity
preference must not make an exhaustive policy contract structurally
impossible. In the isolated overlay only, add one neutral response-contract
instruction that asks for the complete selected checklist and explicitly
permits the length needed by the rubric, or redesign a mechanically checkable
contract as a deterministic grader. Do not copy rubric answers into the task,
weaken the candidate contract, or publish that normalization as skill content.

Keep prompt graders independent by default. Set `continue_session: true` only
when the grader contract genuinely requires the candidate's full conversation
or workspace session, and record that reduced independence in the result. Do
not add it as a generic auth, reliability, or scoring workaround.

For an independent semantic grader under Waza 0.38.0, put the acceptance
contract in `config.rubric`, not an inline `config.prompt`. The rubric transport
injects the task input and candidate output into the judge request; an
independent inline prompt does not. The rubric must direct the judge to call
Waza's native `set_waza_grade_pass` or `set_waza_grade_fail` tool exactly as its
scoring contract requires. Keep both instructions in the rubric so the judge
sees the candidate and can produce structured grade evidence without resuming
the candidate session.

Do not ask a prompt grader to emit a custom prose pass token such as `Passed.`.
Waza 0.38.0 can record pass-sounding prose or the default feedback `All prompts
passed` while setting `score: 0` and `passed: false` when no native grade tool
was called. Treat empty `details.passes` and `details.failures` as an invalid
grader transport, not a candidate result. The structured result remains
authoritative only after the grader transport itself is coherent.

## Paid Verification Iteration Ceilings

Interpret a user-supplied verification cap in the context of the evaluation
loop. Unless the user explicitly limits internal model turns, a phrase such as
`up to three verification calls`, `three iterations`, or a request to run and
fix the behavior up to three times means at most three paid provider-backed
verification runs. It does not limit the executor's internal turns.

One paid verification iteration is:

1. prove the candidate identity, effective models, focused task, and cheap
   deterministic gates;
2. run exactly one provider-backed focused verification;
3. inspect provider, candidate, grader, transcript, and skill-attestation
   evidence;
4. make justified local candidate or grader repairs; and
5. stop on accepted proof or begin another iteration only when the user budget
   still permits it and another paid result can change the decision.

Local inspection, deterministic self-tests, and regrading the saved response do
not consume another paid iteration. Each new execution of the selected paid
focused verification does, including a rerun after candidate or grader repair.
Candidate, prompt-grader, and internal model subcalls inside one Waza run are
cost evidence within that iteration, not additional iterations, unless the user
explicitly caps those subcalls. Stop early when the focused behavior passes; a
ceiling is a maximum, not a target. Never launch a broader suite merely because
paid iterations remain.

Waza may report several internal turns or provider subcalls for one
provider-backed run; that remains one paid verification iteration. Do not
replace Waza with a direct harness only to constrain internal turns when the
authorized objective is Waza-native proof.

Only apply a hard internal-turn ceiling when the user explicitly says that each
provider run itself may use at most a named number of model turns. In that case,
prove from current executor source or authoritative CLI help that the selected
mechanism enforces the ceiling. A task expectation, grader threshold,
`max_attempts`, or wall-clock timeout is not a hard turn limit.

## Waza Provider Environment

The passing VPN gate above owns admission to this Waza-only section. Do not
inspect or repair Waza provider state after a failed smoke. The selector may
continue only through the separate Pi contract; it must not use Pi to diagnose
or impersonate the Waza provider route.

When a topic worktree lacks the configured provider environment, treat
`.envrc` as executable, ignored, worktree-local state rather than branch
content. Locate the checkout whose `git worktree list --porcelain` entry names
the instruction-maintenance branch, verify the exact `.envrc` path, and source
it only inside a non-traced subshell that immediately runs Waza.

Never use `set -x`, inherit secrets into the parent shell, or print values,
lengths, assignments, matching lines, or an environment dump. Check only
whether the exact credential variables required by the configured executor are
non-empty. Never copy, create, stage, commit, log, or paste `.envrc` or its
values into another worktree.

Before inspecting provider configuration after an auth failure, read
`docs/agents/copilot-byok-headless.md`. Use its fixed non-secret allowlist;
never run a broad provider-name search across `.envrc`.

Classify provider responses precisely:

- HTTP 401 proves the endpoint rejected the supplied or missing authorization;
  it does not prove which credential is absent or whether VPN is healthy.
- A provider rejection of `auto` proves model resolution failed; it does not
  prove that the requested explicit model is unavailable.
- Switching models through the same broken auth or unresolved configuration
  path is not a repair.

## Focused Execution And Attestation

Run exactly the selected focused task first and write a structured result
artifact. After it finishes:

1. Compare the result's candidate identity with the recorded source SHA and
   candidate digest.
2. Attest the exact target skill content. Use canonical `skill_invocations` attestation:
   normalize the invocation list and, when the target appears there, require
   its path to equal the intended
   `.codex/skills/<skill>/SKILL.md` inside the isolated candidate. Waza 0.38.0
   may eagerly inject the target skill while the agent separately invokes a
   bootstrap or dispatcher skill. In that mode, extract the transcript's
   `<skill_context>` body and require its bytes and digest to equal the target
   file even when the invocation list is non-empty. Record additional invoked
   skills separately; absence or mismatch of both target-attestation forms
   invalidates the result.
3. Record provider execution status, candidate response status, grader
   execution status, structured grader score or pass state, and usage
   separately.
4. Record the provider route and requested/configured model separately from
   the route-appropriate effective-model evidence. On Copilot MaaS require the
   transcript declaration to agree. On BYOK require provider-side request
   telemetry or equivalent secret-safe readback; do not substitute the CLI's
   static fallback banner.
5. Compare grader prose, structured score/pass state, and process exit status.

A candidate mismatch or invocation mismatch invalidates the result. Correct
isolation and rerun only the focused task. If grader prose, structured state,
and exit status contradict one another, classify grader integrity as
unresolved and stop. Do not call the candidate behavior passed or failed from a
contradictory grader artifact.

## Cost And Expansion Gate

Use focused-run usage plus remaining task, trial, model, and prompt-grader
counts to estimate the shape of the broader run. Do not invent a precise token
forecast when caching or conversation length makes it unknowable; state the
observed focused cost and the multiplication factors.

Count every provider invocation as one paid trial, including a rerun of the
same focused task after an authoring or grader repair. Before any paid rerun,
recompute the remaining user-authorized task and trial budget. If that budget
is exhausted, stop with the current failed or unresolved evidence and request
explicit expansion; repairing the candidate or grader does not itself authorize
another paid invocation.

Continue beyond the focused task only when:

- provider execution, path attestation, candidate identity, and grader
  integrity all hold;
- the focused behavior result has been accepted or returned to authoring and
  repaired;
- the user already authorized that exact broader scope, or explicitly accepts
  expansion after seeing a material projected cost; and
- the broader run can still change the acceptance decision.

Prefer deterministic program graders for structural contracts, exact fields,
path checks, state transitions, and other machine-verifiable requirements.
Reserve prompt graders for genuinely semantic judgment. Do not pay a second
model to judge a contract that a deterministic grader can prove.

## Failure Recovery And Re-entry

Do not blind-retry, rotate models speculatively, or launch the full suite after
a partial failure. Retry the focused task only after evidence proves a concrete
auth, configuration, isolation, candidate, or grader correction.

Route failures by owner:

| Failure | Next owner |
| --- | --- |
| Candidate behavior violates the intended agreement | Return to instruction or code authoring, then re-enter with a new digest |
| Deterministic or prompt grader contract is wrong, ambiguous, or contradictory | Eval maintenance under `skill-quality-evals` |
| Provider auth or endpoint configuration fails | Provider environment recovery in this lane and `docs/agents/copilot-byok-headless.md` |
| Effective model remains unresolved or `auto` | Repair only the isolated overlay, then repeat model preflight |
| Candidate or skill invocation does not match | Rebuild isolation and repeat only the focused task |
| Broad cost is not authorized or no longer decision-relevant | Stop with broad execution deliberately withheld |

After a candidate fix, provider repair, or grader repair, re-enter this lane at
candidate identity and cheap gates. Do not resume from the failed provider
call using stale evidence.

## Completion Proof

Report these dimensions independently:

- exact candidate source SHA, governed-file digest, suite, and task;
- explicit execution and prompt-grader models;
- provider execution result;
- candidate behavior result;
- grader execution and structured result;
- canonical skill invocation or eager-injection attestation;
- focused-run usage and observed duration;
- broad-run scope completed or deliberately withheld; and
- unresolved auth, model, grader-integrity, isolation, or cost items under
  `Pending Verification`.

Provider success is not grader success. Grader success is not behavioral
success. A focused pass is not a full-suite pass. Use completion language only
for the exact dimensions proved by the recorded artifact.
