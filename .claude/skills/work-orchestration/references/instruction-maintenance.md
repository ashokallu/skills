<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-31 (behavioral compression and maintenance-search safety) -->

# Instruction Maintenance

```text
Type: owning lane
Use when: the user asks to improve, add, remove, merge, relocate, or evaluate a skill,
          runbook, agent instruction, dispatcher, route, or workflow contract
Skip when: the request is ordinary product documentation with no agent/runtime behavior
Owns: instruction architecture, canonical ownership, preservation, rewrite,
      cross-reference/mirror updates, and behavioral validation
Does not own: unrelated product changes or specialist-domain policy decisions
Allowed side effects: authorized instruction/repository edits and validation only
Inputs: requested outcome, instruction tree, governing runtime/repo rules, known
        mirrors/consumers, and evaluation capability
Exit states: updated and validated | partial | blocked
Outputs: improved instruction set, validation evidence, migration notes, and gaps
Re-enter when: intended behavior, runtime capability, canonical owner, or mirror scope
               changes
```

The objective is better agent behavior with less ambiguity and less runtime
reading, not merely shorter prose. Preserve load-bearing safety and domain
knowledge while removing duplicated ownership, bypass ceremony, obsolete
runtime assumptions, and instructions that cannot change an observable action.

## 1. Classify The Change

- **clarity-only:** wording, structure, links, examples, or terminology without a
  behavior/ownership change;
- **behavioral:** activation, precedence, permission, side effect, retry,
  completion, or output changes;
- **architectural:** add/merge/remove a lane, move canonical ownership, split
  dispatcher/contracts/specialist detail, or change load paths;
- **runtime adaptation:** mirror the same behavior across runtimes with different
  tool names, paths, or capabilities.

Use [objective-lock](objective-lock.md) and [idea-challenge](idea-challenge.md)
when the change alters durable policy, owner-controlled semantics, permission,
production/destructive behavior, or dispatcher precedence. Only a verified
typo, formatting correction, or mechanical link repair may use the
dispatcher’s tiny-change exemption; broader clarity work still follows its
applicable direction gate.

## 2. Build The Current Behavior Map

For a whole-skill or architectural change, read the entire skill tree before
editing. For a narrow clarity/link repair, read the full target file plus every
directly affected owner, consumer, and contract; use repository-wide search to
map the remaining references without forcing unrelated full reads. Then map:

```text
Reference:
Type: dispatcher | gate | lane | companion | specialist adapter | example/eval
Observable trigger / non-trigger:
Canonical decision or behavior owned:
Allowed side effects:
Inputs / outputs / reopen condition:
Consumers and links:
Overlap, contradiction, or missing path:
```

Search the repository for:

- the same skill/lane name and known mirrors;
- duplicated schemas, permission language, route precedence, and completion rules;
- stale/retired names, hardcoded model versions, runtime-only paths/tools, and
  examples that accidentally became policy;
- missing or circular links;
- routes with no exit, no owner, or no activation/non-activation boundary.

Do not infer that similarly named directories are byte-identical mirrors.
Inspect governing instructions and intentional divergence for each runtime.

## 3. Choose One Canonical Owner Per Rule

Use this division:

- **dispatcher:** purpose, core invariants, fast path, deterministic activation
  precedence, route map, re-entry, and closeout;
- **decision gate:** one decision, observable trigger/non-trigger, evidence,
  dispositions, and reopen condition;
- **owning lane:** one bounded phase, procedure, side-effect ceiling, exits, and
  handoff;
- **companion contract:** reusable schema/lens only;
- **specialist adapter:** tool/domain mechanics and runtime-specific details;
- **evaluation file:** behavior cases and negative assertions, not live policy.

When two files own the same decision, select one canonical owner and replace the
other copy with a narrow link or remove it. Do not keep slightly different
parallel schemas “for convenience.” A reference should not restate dispatcher
precedence or generic contracts unless it adds a domain-specific constraint.

## 4. Write For Progressive Disclosure

The dispatcher kernel should let an agent choose the next file without reading
the whole tree. Each reference should conform near its start to the canonical
[Universal Reference Interface](workflow-contracts.md#universal-reference-interface).
Preserve separate trigger/non-trigger, ownership, side-effect, input,
terminal-state, output, and re-entry rules. Do not maintain a second field-list
schema here.

Then include only:

- the decisions/procedure unique to that reference;
- objective activation and non-activation examples where ambiguity is likely;
- exact failure/blocked/exit behavior;
- links to canonical shared contracts and adjacent owners.

Keep instructional code blocks self-contained; do not rely on hidden shell
state across separate blocks. Avoid circular activation language: if a
prerequisite should already have run, say “if you reached this owner without
it, stop before acting and run it now.”

Prefer observable language: “after two materially identical attempts, stop and
change tactic” over “be careful not to loop.” Use `must` only for invariants
whose violation creates safety, authority, correctness, or interoperability
failure. Use defaults for efficiency choices.

### Behavioral Compression

- Apply a sentence-level no-op test: if removing one sentence would not change
  a route, action, evidence requirement, stop condition, output, or forbidden
  side effect, delete the whole sentence instead of polishing it.
- Describe each observable branch once. When synonyms trigger the same branch,
  replace them with one operationally stated observable trigger; retain
  separate trigger language only for materially different paths. When
  dispositioning proposed synonym text, say to collapse it to that one
  observable trigger; naming only the branch or owner is not a substitute.
- Use a compact term only when its operational meaning is defined and it
  replaces repeated decision-bearing prose. Both conditions are required:
  defining the term is not enough when it replaces no repeated rule. Reject an
  undefined proposal first, and introduce it later only when it will replace
  that repetition. A slogan or familiar label without a checkable effect is
  still a no-op.
- For ordered work, treat a vague completion criterion as the first defect, not
  as evidence for a split. Replace it with a checkable and, when needed,
  exhaustive criterion before hiding later steps behind another file or phase.
  Reject or defer a proposed sequence split at that point; do not describe the
  split itself as accepted. Reconsider it only if later steps still cause
  observed premature completion after that decisive criterion is in use.
  Distinct ownership may justify a later lane boundary, but it does not waive
  this criterion-first sequence-split condition.

Do not add lane-local skip receipts, version bumps, hashes, full-file rereads,
or ledgers on ordinary paths unless a consumer genuinely needs them. “No
ceremony on bypass” means an inactive conditional gate adds no lane-local
packet and usually no file load. It does not waive the universal task
Classification receipt or any currently activated gate.

## Requested Artifact Fidelity

When the user asks an artifact to preserve a plan, proposal, observation,
alternative, or decision:

- preserve that content and label its decision status;
- do not treat preservation as execution approval, phase-selection authority,
  or permission to substitute a different behavioral policy; and
- before handoff or commit, run a semantic fidelity check: name the requested
  artifact and behavior, point to where they are preserved, state their current
  authority, and cite explicit owner authority for any material reversal,
  removal, deferral, or phase change.

Markdown lint and internal consistency do not substitute for semantic fidelity.

## Durable Evidence And Writing Rules

- Prefer trigger/action/effect rules over slogans. Add a rule only when it
  changes future agent behavior through a reusable trigger, decision,
  validation, route, failure signature, or avoidance action.
- Treat current code, config, manifests, CI, and checked-in docs as the source
  of truth. Verify commands, paths, links, and source claims before calling
  them current.
- Treat `Last verified` as evidence metadata, not an edit timestamp. Advance it
  only for behavior, commands, paths, or sources actually reverified. Preserve
  the prior date for wording-only edits, and never cite gitignored `tmp/`,
  backups, or machine-local artifacts in that header.
- Keep Markdown structured and secret-safe. Preserve table shape unless its
  contract changes. Use placeholders for credentials and redact personal data,
  private payloads, and sensitive internal details.
- Keep YAML frontmatter simple; avoid unquoted colon-bearing values that a
  loader can reject.
- Prefer stable source-relative labels over one-off branches, run IDs, service
  URLs, or local paths unless the value is a verified execution contract.
- Keep root boot files broad. Put detailed behavior in the narrowest lane that
  makes the decision.

## 5. Remove Volatile Or Harness-Specific Policy

Keep durable behavior in shared instructions. Move or remove:

- hardcoded current model generations and model-selection folklore;
- UI-only click paths, wrapper syntax, or tool inventories from generic lanes;
- runtime-specific skill roots copied into another runtime;
- persona prose and generic “be thorough” exhortations;
- examples whose values look authoritative but are not contracts;
- repository-specific operational commands from generic orchestration, unless
  the skill is explicitly repository-specific and the command is load-bearing.

Specialist adapters may name their actual tools/paths, but must state capability
and side-effect assumptions so another runtime can fail closed or substitute a
verified equivalent.

## 6. Add A Lane Only When It Has Distinct Ownership

A new lane is justified only when all are true:

- an observable trigger recurs;
- no current owner can absorb it without conflicting responsibilities;
- it owns one decision or bounded phase;
- its allowed side effects and terminal exits are distinct;
- the dispatcher can route to it deterministically;
- at least one activation and one non-activation case can be written.

Do not create a lane for a checklist, one-off example, implementation detail,
or schema that belongs in a companion. Prefer consolidating overlapping lanes
over adding another hop.

After adding/renaming/removing a lane, update the dispatcher map, adjacent
handoffs, canonical contract links, specialist tables, examples, evaluation
cases, and intentional mirrors. Remove stale route names.

## Instruction Ownership And Compaction Gate (Step 7)

Treat instruction loading as a layered runtime contract. Put a rule in the
narrowest layer that can reliably activate it, and keep broader layers limited
to the fallback needed to reach that owner:

| Layer | Owns | Must not become |
| --- | --- | --- |
| `AGENTS.md` | universal safety, evidence, routing, and side-effect invariants | a copy of specialist procedure |
| `repo.md` | stable repository facts, command-discovery entrypoints, and runtime boot index | a runtime overlay or specialist runbook |
| Runtime overlay | runtime-only loading, tool, transport, and proven fail-closed reliability guards | a second shared repo guide |
| Orchestrator kernel | classification, precedence, route selection, and the minimum fail-closed fallback needed to load the owner | the canonical copy of every packet or lane procedure |
| Orchestrator reference | one reusable gate, lane, schema, or companion contract | an eager boot requirement for unrelated work |
| Specialist skill or runbook | domain execution, validation, review, publication, or operation | universal routing policy |

Before deleting, merging, or moving normative text, build one append-only row
per rule. Section-level summaries are insufficient because they can hide a
lost condition, recovery path, authority distinction, or stop rule:
Before retiring a directory, inventory every file and do not delete the surface
until the rows cover every durable rule or an evidenced retirement reason.

An agent, skill, or role deletion authorizes removal of its definition-specific
identity, persona, obsolete handoffs, and unsupported compatibility aliases. It
does not authorize deleting adjacent README guidance, ADRs, research, evidence,
templates, source links, safety rules, or operational facts merely because they
mention that identity. Classify every deleted file and every deleted hunk as
definition-specific or generally useful before editing. Preserve generally
useful content in place or move it to a reachable canonical owner; when the
identity itself must disappear, rewrite the content in role-neutral terms. If
a generally useful row has no owner or validation disposition, stop the
deletion and leave that content intact.

```text
Instruction preservation row <stable-id>:
- source rule: <exact rule or bounded source section>
- canonical owner: <repo-relative path and section>
- activation/load path: <how the active runtime reaches the owner>
- load capability: <proved | Pending Verification + bounded proof>
- required inline fallback: <none | exact minimal fail-closed summary>
- coverage: <deterministic assertion, behavior case, or Pending Verification>
- disposition: preserve-inline | move | retire
```

Apply these rules to every row:

- `move` is allowed only after the canonical owner is self-contained, mirrored
  where required, and reachable without following a pointer back to the source
  being removed.
- `retire` requires evidence that the behavior is obsolete or intentionally
  replaced; shorter wording is not retirement authority.
- A deterministic text assertion proves presence and ownership, not model
  compliance. Preserve an existing runtime fallback until the replacement can
  load and baseline-versus-candidate behavior supports removing it.
- Single-owner checks may allow an explicitly named minimal fail-closed summary
  in an eager layer. They must reject a second canonical schema or procedure.
- Moving an always-required contract behind progressive disclosure must
  preserve unconditional activation through a complete eager fail-closed
  fallback or a mandatory owner load. A qualifier such as `when needed` or
  `when non-obvious` changes behavior unless the canonical contract itself
  defines that exception. Before removing eager fields, add a focused behavior
  case proving that an apparently simple path still honors every material
  input.
- Compact one layer at a time. Run its preservation, owner, link, mirror,
  routing, and focused behavior checks before changing the next layer.
- If a row lacks an owner, non-circular load path, required fallback, or
  coverage decision, stop the removal and leave the current behavior intact.

For a repo-wide compaction or a move across root guides, runtime overlays,
dispatcher kernels, and specialist owners, persist the rows in
[`docs/agents/instruction-preservation-ledger.md`](../../../../docs/agents/instruction-preservation-ledger.md)
before deleting source text. The ledger is evidence for the current move, not a
new eager instruction surface. A narrow same-owner wording cleanup may keep
equivalent rows in the change artifact only when no trigger, authority,
fallback, stop rule, runtime boundary, or load path moves.

The default fallback matrix is capability-based:

- shared runtimes may lazy-load a reference after the kernel selects it;
- runtime-only content stays in that runtime's overlay or operating contract;
- intentional Codex model-routing and Claude context-recovery differences stay
  local to those mirrors; and
- AGY/Grok defensive kernel text stays monolithic until focused runtime
  evidence, not deterministic string checks alone, supports compaction.

## 8. Mirrors And Runtime Variants

When the user explicitly scopes an experiment to one runtime, edit that runtime
and the named shared files only. Record the deferred mirrors and any shared-file
effect in the change artifact. Mirror deferral is not a new approval blocker
and does not authorize editing excluded trees. Use runtime-scoped checks where
available; report parity as intentionally deferred rather than claiming it
passed. Reconcile each mirror's current contract in the later authorized pass.

When intentional mirrors exist:

1. identify the canonical behavior and each runtime’s governing instructions;
2. apply the same behavior change to every applicable mirror;
3. adapt tool names, paths, output transports, and capability fallbacks;
4. inspect each diff independently; do not overwrite intentional local rules to
   achieve byte parity;
5. document deliberate divergence and its owner.

After copying, search each destination for source-runtime paths, wrappers,
models, MCP names, and helper scripts. Use that runtime's path or a generic
capability unless the divergence is intentional. Mirroring the same behavior
does not require byte parity where a runtime-specific rule already exists.

Before deleting an old agent/skill surface, remove it from mirror sync rules,
route tables, eval triggers, examples, and compatibility aliases, or document a
supported migration path.

## 9. Self-Repair And Recurring Failures

Patch the earliest lane that should have prevented the mistake, then add
downstream execution detail only where needed. Before editing, record a compact
failure chain:

```text
Missed trigger:
Wrong action:
Affected artifact or system:
Evidence that should have been checked:
Earliest preventing owner:
```

Cover the whole failure chain, not just the last visible symptom. A recurring
route, validation, public-artifact, reviewer/CI, and handoff failure may require
multiple owning-lane edits, or an explicit note that an existing rule already
covers a phase. Treat a concrete review finding as an acceptance criterion:
reread it after editing and run the focused lens that would catch it again.

During unrelated product work, do not expand into instruction edits without
authority. Record the narrow owning file and prevention rule as follow-up.
When the defect wasted paid model calls, CI time, reviewer time, or operator
attention, put the cheapest evidence gate before that expenditure and state
what remains `Pending Verification` when it cannot run.

### Owner-Designated Recovery Anchors

When the user reports that reviewer instruction changes reduced thoroughness,
or says the retired reviewer background material was more effective, use
`d11548a34dc2fd48a5f7e777f51d1c5d325422d1` as the owner-designated
known-good reviewer recovery baseline.

This is a comparative behavior anchor, not rollback authority:

1. Verify the commit object and bound inspection to its reviewer contracts,
   preservation rows, runtime reviewer surfaces, and relevant validation.
2. Compare observable obligations such as admitted-surface closure, triggered
   lenses, mandatory safety floors, residual analysis, stop proof, packet
   fidelity, and handoff acceptance. Do not use an unscoped repository-wide
   diff as the recovery recipe.
3. Classify each material difference as a lost guarantee, a valid later
   improvement, or an intentional replacement. Restore a lost guarantee at its
   current native owner with focused coverage while preserving compatible
   later improvements.
4. Do not reset, revert, cherry-pick, or copy the anchor wholesale.
5. Do not open archived background documents merely because the report names
   them. Restoring fixed background-document or case-study reads requires an
   explicit owner decision; the anchor alone does not reactivate them. A direct
   user instruction to restore those reads supplies that decision, but still
   restore them deliberately at current owners rather than copying the anchor.

The corresponding append-only provenance is in
[`docs/agents/instruction-preservation-ledger.md`](../../../../docs/agents/instruction-preservation-ledger.md).
That ledger and any agent memory are supporting evidence; this section owns the
executable recovery procedure. Deterministic checks prove discoverability and
guardrails, not future model compliance or reviewer quality.

## 10. Validation

At minimum:

- parse frontmatter and required metadata;
- check all relative links and anchors;
- verify every route target exists and every reference has one clear type/owner;
- search for stale names, duplicate canonical schemas, conflicting precedence,
  obsolete model/tool/path literals, and unsupported side-effect claims;
- run Markdown/lint or skill-quality checks available in the repository;
- run focused activation and non-activation evaluation cases for changed routes;
- inspect the final diff for accidental policy loss and unnecessary growth;
- compare word/line/load-path changes as a signal, not as the objective;
- verify requested-artifact semantic fidelity and evidence-backed
  `Last verified` metadata;
- verify the same behavior in intentional mirrors and inspect documented
  runtime divergence independently.
- use hooks only for high-signal deterministic prevention; avoid broad
  always-on hooks that slow ordinary work or hide failures.

When self-repair follows a review finding, treat the finding as an acceptance
criterion: reread it, verify the root cause is removed, and run the lens that
would catch the defect again. A clean link check alone does not prove better
orchestration.

Use fixed-string search and single-quoted shell arguments for literals
containing shell-active characters so maintenance scans cannot execute the
text being searched. Double quotes do not neutralize backticks or `$()`;
escape those characters explicitly when single quotes cannot be used. Before
running a search command that contains either form, inspect the final shell
argument and stop if it could perform command substitution.

## 11. Output

Deliver:

```text
Instruction maintenance result: UPDATED | PARTIAL | BLOCKED
Changed behavior and architecture:
Canonical ownership changes:
Removed redundancy/ceremony/volatile assumptions:
New/retired lanes and why:
Preserved safety/domain invariants:
Validation and evaluation results:
Mirrors/consumers updated or intentionally not present:
Compatibility or migration notes:
Pending Verification / residual risks:
```

The final skill should be executable by a cold agent: it can select one next
owner, knows what not to do, reaches every required contract, terminates every
path, and does not spend tokens proving that inactive gates were skipped.
