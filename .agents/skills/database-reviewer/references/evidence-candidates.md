# Optional database evidence candidates

This lane governs checked-in historical evidence that may calibrate a database
review. Recording an out-of-band operation is optional and best effort. The
candidate set is non-exhaustive: absence of a candidate proves nothing about
what did or did not happen in an environment.

## Candidate contract

- Keep provenance separate from relevance. Classify relevance to a claim as
  `direct`, `comparable`, `contextual`, or `not_applicable`. Classify how the
  observation was established independently.
- `agent_attested_non_replayable` means an executing agent observed the named
  terminal, catalog, or monitoring result, but no portable primary artifact or
  digest remains. It may calibrate judgment and constrain unsupported contrary
  claims. It cannot satisfy a requirement for independently replayable primary
  evidence.
- A candidate is a version-controlled historical record, not immutable
  environment truth. It remains evidence that the stated observation was
  recorded even after its current-state value expires.
- Git history preserves prior versions. A material factual correction increments
  `record_version` and records `corrected_at`, `reason`, and the prior Git commit
  when known. This is correction provenance, not an append-only operation
  ledger or retention program.
- Every candidate names its observation time, environment and object scope,
  evidence basis, claim groups, limitations, and facts it does not prove. Do
  not store credentials, connection details, query payloads, or personal data.

## Reviewer use

When a supplied or discovered candidate is relevant, record one disposition:

- `accepted`: supports the named claim within its provenance and limitations;
- `limited`: useful only as comparable or contextual calibration;
- `rejected`: violates the candidate contract or conflicts with stronger
  evidence; or
- `irrelevant`: no material claim overlap.

Each disposition names the affected claim and reason. A reviewer may not ignore
a relevant supplied candidate. A contrary runtime or capacity claim must name
the material difference that makes the candidate non-comparable. When that
difference is unproved, keep the contrary claim under `Pending Verification`
instead of emitting a finding.

Candidate evidence never overrides a confirmed source, state, catalog, or
runtime defect. Historical completion does not prove current object existence,
current workload, current headroom, future repeatability, rollback, or recovery.
Stronger evidence supersedes a candidate only for the equivalent claim.
