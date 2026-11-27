<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-03 (planning-philosophy consumption and transport) -->

# Forward Analysis

```text
Type: companion contract
Use when: the earliest active decision gate is assessing a plan, fix, migration,
          policy, or review that may have non-local consequences
Skip when: the change is truly local and its consumers/proof are already obvious
Owns: one bounded analysis of the whole problem, proposed output, downstream consumers,
      smallest durable action, and claim boundary
Does not own: routing, authorization, implementation, or a second standalone gate
Allowed side effects: bounded read-only analysis within the activating gate
Inputs: objective, proposal/change, target, and known system boundaries
Exit states: COMPLETE | BLOCKED
Outputs: one visible, content-bound forward-analysis decision record transported
         losslessly to downstream consumers
Re-enter when: objective, target, material evidence, proposed output, consumer
               acceptance, or next blocker changes
```

Use this lens when a proposed action is described as an unblocker, final fix,
last PR, rollout-ready, production-ready, or otherwise sufficient for material
later work. Also use it when a predictable later rejection could waste
significant code, review, CI, release, migration, shared-environment, or
operator budget.

This is a decision contract, not a new lane, acknowledgement, raw-reasoning
dump, per-task report file, or recurring ceremony.

Do not route to `forward-analysis` as an independent phase. The activating gate
records the result once; later planning, authoring, review, and specialist lanes
consume or challenge it.

The record exposes the complete decision basis needed for challenge: premises,
evidence, alternative dispositions, consumer acceptance, the strongest
counterargument, and the proof boundary. Never request or include hidden
chain-of-thought, raw scratchpad, abandoned brainstorming, or unrelated
sensitive context.

## Decision Contract

Before recommending the action:

1. **Whole problem:** state the locked objective and the complete current
   blocker, not only the newest symptom or proposed patch.
2. **Decision-changing evidence:** inspect bounded current facts that can decide
   whether code is needed.
3. **Alternatives:** check no-op, existing path, configuration, data,
   documentation, operator sequence, canary, and owner-policy options. A no-code
   path is valid only when it satisfies the same outcome without transferring
   larger recurring risk or toil to an unowned operator.
4. **Proposed output:** name the artifact, state, or capability the action will
   produce.
5. **Next consumers:** name the next two or three known material consumers,
   their acceptance rules, current evidence, and next predictable blocker.
6. **Smallest durable action:** choose the least costly action that advances the
   objective and reduces total uncertainty. When bounded read-only evidence can
   determine whether code is needed, the next artifact is that evidence, not an "evidence PR" or gap-closing PR.
7. **Claim boundary:** state exactly what the evidence will prove and mark the
   remainder `Pending Verification`.

## Planning-Philosophy Consumption

For a substantive planning decision, consume
[planning-philosophy.md](planning-philosophy.md) once inside this analysis. The
selected mechanisms must change an engineering claim, alternative, evidence
request, consumer condition, prediction, or stop; otherwise discard them.

Map retained translations into the existing premises/evidence, alternatives,
next-consumers, strongest-counterargument, and claim-boundary fields. Do not
change the decision-record schema or add a philosophy packet. Idea challenge
uses this result without repeating the companion pass. When the companion
requires an influence acknowledgement, place it inside an existing record
field and emit no summary after the record.

## Stop Rules

Recommend evidence collection, owner decision, plan revision, or a stop instead
of code/release/operation when:

- the whole problem or decision buckets cannot be named;
- a known next consumer would reject the output;
- required freshness, lineage, policy, rollback, capacity, or ownership remains
  predictably unproven;
- lower-environment functional success is being used as production capacity or
  concurrency proof;
- an expensive PR, CI run, release, shared environment, or production action
  would be the first discovery surface for a cheap authorized preflight;
- a material product/data/security/infrastructure/operator decision has no
  accountable owner.

## Boundedness

Stop at the objective, protected invariants, next two or three known consumers,
and cheap authorized evidence that can change the decision. Record unrelated
future concerns as deferred. This lens never authorizes production access,
private-data transport, speculative architecture, or broader delegation.

Specialist lanes remain authoritative for their mechanics and verdicts.
Database reviewers independently own database correctness and operational
safety; they do not approve the parent workflow's broader unblock claim. The
parent and ordinary reviewer own that cross-lane synthesis.

## One-Pass Transport

Record the result once at the earliest gate. Give it the stable ID
`<action-item-id>/forward-analysis@v<positive-integer>`. Increment the version
whenever decision-changing content changes; never reuse an ID/version for a
different record body.

Content provenance is optional. When an authorized local hashing capability is
available, the record may include a real lowercase
`sha256:<64-hex-characters>` digest over the exact UTF-8 body from `Status`
through `Invalidation and reopen conditions`. Omit the provenance row entirely
when that capability is unavailable. Never emit `pending`, `Pending
Verification`, `none`, `<digest>`, an invented value, or another placeholder.
A present digest is non-authoritative provenance only: it is not permission,
proof, a consumer prerequisite, or a substitute for exact inline transport and
version-increment discipline.

When the record controls a substantive plan, show the complete record to the
user once before proposing implementation or an environment run. Later
user-facing updates name only its ID and a changed decision or blocker.
The literal `Forward-analysis decision record:` header appears exactly once in
that user-visible response.

Cross-session worker transport includes the exact complete record inline. A
critic consultation instead carries the record ID/version and the
decision-changing conclusions in the semantic brief owned by
`pre-code-critic-assignment`; it does not duplicate an unchanged full record.
A same-session consumer may use a reference only when it can currently
dereference the exact current record and verify its ID and version. Do not
create a registry or persisted report merely to make a reference resolvable.

Later consumers verify or challenge the record. They do not treat it as proof
or recompute it. Reopen and increment the version only under the route
condition above.

When a new-session critic is next, do not turn the record into a ceremonial
second packet. Supply its ID/version plus the whole-problem conclusion,
decision-changing evidence and alternatives, next-consumer acceptance,
smallest durable action, claim boundary, and strongest challenge in the critic
brief. Tell the critic to challenge those conclusions and never treat them as
proof. Omit unchanged non-decision fields and do not request content hashes.

Choose one serialization owner before drafting user-visible decision content.
When the current output prepares a new-session worker assignment, that
assignment is the owner: emit one copy-ready handoff with the exact record
nested inside it.
Do not emit a standalone idea-challenge packet, planning decision, steering
section, prose preview, or fenced second copy before or after the handoff.
Outside fields may carry assignment metadata such as target, escalation reason,
requested verdict, and record ID/version, but must not paraphrase the record's
objective, evidence, alternatives, consumers, or challenge targets. Preliminary
status before required reads finish may name only route, target, and next
evidence; it must not draft decision-record fields. End the response after the
handoff, with at most one next-route sentence that cites only the record
ID/version.

Use the compact critic brief from `pre-code-critic-assignment` when an idea
challenge escalates to a fresh critic. Its forward-analysis input is:

```text
Critic forward-analysis input:
- record: <ID/version>
- decision-changing conclusions: <whole problem, evidence, alternatives, output,
  next consumers, smallest action, claim boundary, and strongest challenge>
- consumer instruction: Challenge these conclusions; do not treat the parent result as proof.
```

```text
Forward-analysis decision record:
- Record: <action-item-id>/forward-analysis@v<positive-integer>
- Status: COMPLETE | BLOCKED
- Objective and whole problem:
- Protected invariants and non-goals:
- Decision-changing premises and evidence:
- Alternatives considered, disposition, and reopen trigger:
- Proposed output:
- Next consumers, acceptance, current proof, and next blocker:
- Smallest durable action:
- Strongest counterargument and challenge targets: <when planning philosophy
  materially changed the decision, include the `Planning philosophy influence:`
  sentence inside this field; never append it after the record>
- Claim boundary / Pending Verification:
- Invalidation and reopen conditions:
```

The record stays bounded to decision-changing content and the next two or three
material consumers. Do not repeat it at every phase.
