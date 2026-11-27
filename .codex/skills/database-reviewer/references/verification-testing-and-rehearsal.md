# Verification, testing, and rehearsal

This lane is an additive evidence overlay for cross-lane evidence independence,
production-shaped rehearsal, fault injection, or adverse-condition proof
central to the requested decision. Domain lanes continue to own ordinary tests
and the database claims those tests support.

- Name the claims whose verdict depends on this overlay. Select evidence by
  claim and consequence; do not turn this lane into a universal test matrix.
- Record the engine/version, runner and transaction mode, extensions,
  collation/timezone, data shape, topology, concurrency, privileges, and failure
  conditions actually exercised. A test proves only that named scope.
- Separate source inspection, test execution, representative rehearsal, and
  observed production evidence. A green unit or integration test does not prove
  live locks, capacity, recovery, fleet coexistence, or production topology.
- Require independent validation when the verdict depends on correctness.
  Tests derived from the same implementation, self-reported job counters, and
  the mutating job's success signal can share the same defect. Prefer invariant
  queries, catalog state, external reconciliation, or a distinct observation
  path.
- Exercise the adverse condition behind the material claim: concurrent writers,
  partial or ambiguous commit, timeout, cancellation, process loss, retry from
  a new process, failover, lag, skew, hot targets, or resource pressure as
  applicable. Otherwise keep the claim unproven.
- Rehearse the exact release artifact, migration runner, flags, session
  settings, privileges, and topology path intended for production when the
  decision relies on production-shaped behavior.
- Preserve representative size, width, skew, duplicates, nulls, largest target,
  indexes, statistics, and write concurrency relevant to the claim. Tiny
  fixtures prove only their bounded semantics.
- When environments differ materially, rehearse against the largest or most
  adverse relevant data shape rather than extrapolating from a smaller
  environment. At minimum compare relation cardinality, logical-key fanout,
  blocker or exception count, statistics freshness, cache warmth, and effective
  session settings. A successful lower-environment run cannot close a
  largest-environment performance gate without a conservative bound.
- For a long-running mutating job, prove each expensive statement independently
  with a safe canonical probe before the full run. The first full execution may
  validate integration and operations, but it must not be the discovery method
  for an avoidable query-plan failure.
- Capture commands or artifacts, environment and fixture provenance, start and
  end time, phases, locks, resources, lag, errors, abort behavior, residue,
  cleanup, final state, independent validation, and limitations. Preserve
  failed-run evidence alongside later success.
- Verify that the harness does not conceal the material behavior through a
  different engine/version, transaction wrapper, proxy, permission set,
  extension set, replication topology, collation/timezone, or generated
  artifact.

Block candidates include verdict-forcing claims supported only by happy-path or
tiny-fixture tests, a harness mismatch that can change safety, missing
partial-failure/resume evidence for live data-dependent work, self-validation
that cannot detect silent divergence, or production-readiness approval without
the representative rehearsal or enforceable pre-execution gate it requires.

Useful evidence: exact test and rehearsal artifacts, environment and fixture
provenance, compatibility matrices, negative/concurrency/fault-injection
results, lock and resource traces, independent reconciliation, failed-run
residue checks, and a limitations statement.

When another material database consequence emerges, return to the central
router and add its matching lane.
