<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Environment Config And Secrets Authoring

Use this lane when code adds, renames, retypes, defaults, or reads environment
variables, `.env*` files, config maps, runtime config objects, dataset or
project targeting values, service URLs, connection strings, secret references,
or per-environment conditionals across local, CI, preview, staging, and
production.

## Mission

Every config key is a cross-environment contract with a default, a type, an
owner, and a blast radius. The classic failure is code that works locally while
staging or production silently reads a missing key, a stale default, or the
wrong environment's target — including a non-production surface pointed at a
production dataset.

## Boundaries

Also load:

- `security-and-trust-boundary` for secret values, token scopes, public
  exposure of private keys, and client-bundle leakage;
- `ci-workflow-authoring` when workflow env, GitHub secrets/variables, or
  deploy-time injection changes;
- `feature-flags-rollout` when the key behaves as a mode or toggle rather than
  a connection/target value;
- `typescript-contracts` for env declaration types and parsing;
- `sanity-schema` for Sanity dataset/project targeting;
- `docs-and-operator-truth` so `.env.example`, READMEs, and runbooks track the
  real key set.

Do not introduce new config systems, loaders, or secret managers for one key
when the repo already has an owning pattern.

## Authoring Sequence

1. Inventory the key before editing: name, type, allowed values, default,
   which environments must define it, which code paths read it, and who owns
   its value in each environment.
2. Follow the repo's existing config precedent: central typed loader or env
   schema over scattered raw `process.env`/`os.Getenv` reads; one owner per
   key rather than repeated parsing with divergent defaults.
3. Decide missing-key behavior per environment deliberately: fail fast at
   startup for required production keys; safe local default only when the
   default cannot silently point at production data or external paid services.
   Distinguish an omitted value from an explicit zero when zero is a supported
   disable value. Apply defaults once at the parsing boundary, preserve the
   explicit value afterward, and validate the narrowed or serialized value the
   runtime actually consumes.
4. Keep environment parity explicit. When adding a key, update every place an
   environment defines config in the same slice: `.env.example`, CI workflow
   env, deploy/Terraform/Cloud Run config, secret manager references, and
   docs. A key that exists in only some environments is an incident seed.
5. Point defaults at the safest target. Local and CI defaults must never
   resolve to production databases, production datasets, production queues, or
   mutation-capable endpoints; require explicit opt-in for production targets.
6. Never commit secret values. Reference secrets by name; keep values in the
   secret manager or CI secret store; verify new keys are covered by ignore
   rules and are not echoed by scripts, logs, or error messages.
7. Respect client/server boundaries: only intentionally public values may use
   client-exposed prefixes or reach browser bundles; audit what the bundle
   actually contains when a key moves.
8. When renaming or removing a key, search all readers — code, workflows,
   Docker/compose, Terraform, scripts, docs — and either migrate them in the
   same slice or support both names through a stated deprecation window.
9. Parse structured DSN, URI, and query options at grammar boundaries before
   decoding component values. Cover duplicate keys, case variants, encoded
   delimiters, and malformed encodings instead of scanning a decoded string.
10. For connection URIs, distinguish the selected application database from
    the authentication database and driver defaults. Keep URI paths, explicit
    database selection, and authentication-source options explicit and
    semantically consistent across templates and operator examples; the two
    databases may intentionally differ.

## Prevention Probes

- Which environment can now read an undefined key, and what does the code do
  in that state — crash at startup, crash at first use, or silently proceed
  with a wrong default?
- Can any non-production environment reach a production database, dataset,
  bucket, queue, or third-party account through this key's default or through
  a copy-pasted value?
- Is the same key parsed in more than one place with different defaults,
  trimming, or boolean semantics ("1"/"true"/"TRUE")?
- Does a secret value leak into client bundles, build logs, error messages,
  crash reports, analytics payloads, or committed files?
- Do CI and deploy workflows inject the key for every job that now needs it,
  including preview and scheduled jobs?
- Does `.env.example` and operator documentation match the real required key
  set after this change?
- Can an old deploy and a new deploy read the same environment during rollout
  and disagree about the key's meaning?

## Validation

Prefer a startup or schema-validation test that fails when a required key is
absent or malformed; a grep-backed reader inventory for renamed/removed keys;
a bundle or build-output check when client exposure is in question; and a
config readback (deploy config, workflow env, secret reference names only) for
the environments the change claims to cover. Mark unverified environment
values `Pending Verification` — do not assume staging or production config
from memory.

## Output

```text
Environment config authoring:
- keys changed: <name, type, default, required-in>
- environment parity: <env files/CI/deploy/secret refs updated>
- safe-target check: <non-prod cannot reach prod evidence>
- secret handling: <reference-only proof, no value committed/logged>
- readers migrated: <inventory result>
- proof: <startup/schema/bundle check or Pending Verification>
```
