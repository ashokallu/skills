<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Environment Config And Secrets Lens

## Mission

Review changes that add, rename, retype, default, or read environment
variables, `.env*` files, runtime config objects, dataset/project targeting
values, service URLs, connection strings, secret references, and
per-environment conditionals across local, CI, preview, staging, and
production.

## Ownership And Boundaries

This lens owns the cross-environment config contract: key parity, default
safety, target correctness, and reader consistency. Defer secret-value
exposure severity and token scope to `security-privacy-lens`, workflow env
injection mechanics to `ci-workflow-infra-lens`, mode/toggle semantics to
`feature-flag-rollout-lens`, Sanity dataset behavior to
`cms-sanity-groq-lens`, and stale `.env.example`/README claims to the canonical
closeout `documentation_truth` category once this lens establishes what the truth is.

Do not demand config-system rewrites; surface only keys whose current state
can misbehave in a real environment.

## Evidence And Dedupe

A finding needs a named key, the environment where it misbehaves, and the
reachable consequence (crash, wrong target, silent default, leak). Group one
key's problems across its readers, env files, workflows, and docs as one
finding. Evidence includes the reader code, typed env schema or loader,
`.env.example`, workflow YAML env blocks, deploy/Terraform/Cloud Run config,
and secret reference names — never secret values.

## Review Probes

- Which environment can read this key as undefined, and does the code fail
  fast at startup, fail at first use, or silently proceed with a wrong
  default?
- Can any non-production environment reach a production database, dataset,
  bucket, queue, or paid third-party account through this key's default,
  fallback chain, or a copy-pasted value?
- Is the same key parsed in more than one place with divergent defaults,
  trimming, or boolean semantics ("1"/"true"/"TRUE")?
- For structured DSNs, URIs, and query options, does parsing occur at the
  grammar boundary before component decoding, with duplicate keys, case
  variants, encoded delimiters, and malformed encodings covered?
- For connection URIs, do the path, explicit application database selection,
  authentication database, driver defaults, secret templates, and operator
  examples make their relationship explicit and semantically consistent, or
  can a sample URI silently change authentication behavior? The application
  and authentication databases may intentionally differ.
- Does defaulting distinguish an omitted value from an explicit zero when zero
  is a supported disable value, and is range/type validation applied to the
  narrowed or serialized representation the runtime actually consumes?
- Was the key added or renamed in code but not in every environment
  definition: `.env.example`, CI workflow env, deploy config, secret manager
  references, and operator docs?
- Does a secret value appear in committed files, client bundles, build logs,
  error messages, crash payloads, or analytics events? Do client-exposed
  prefixes cover only intentionally public values?
- After a rename or removal, do stale readers remain in code, workflows,
  Docker/compose, Terraform, scripts, or docs?
- Can an old deploy and a new deploy read the same environment during rollout
  and disagree about the key's meaning or requiredness?
- Do PR claims about "works in staging" rest on config the reviewer can
  verify by name, or on assumed environment values?

## Triage

Promote: a non-production surface that can reach a production target, a
required production key that fails silently, a secret value in a committed or
client-visible artifact, and divergent parsers of one key that produce
different behavior. Keep naming-convention preferences and speculative
"someone might misconfigure this" concerns advisory unless a current default
or reader makes the misconfiguration the path of least resistance.

## Output Discipline

For findings, name the key, the affected environment, the reachable
consequence, and the smallest parity or default fix. Never quote secret
values; cite secret references by name only. When central safety depends on
live environment config the reviewer cannot read (deployed env, secret store
contents), use Risk Evidence Handoff requesting a names-only readback. If
clean, the selected-lens audit can state which keys and environment surfaces
were checked for parity and safe targets.
