<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-19 (source-native Grok, AGY, and Parallel Search routing) -->

# Web Search Routing

```text
Type: owning lane
Use when: example-app work needs current external web research, a social URL,
          live thread or sentiment coverage, broad source discovery, or a decision
          about Grok, AGY, Parallel Search, or bounded fanout
Skip when: the task is local repository search, one known non-social page only needs a
           direct fetch, an authenticated product connector owns the resource, or
           rendered browser interaction is the actual task
Owns: engine and capability selection, bounded fanout sequencing, sufficient-evidence
      stop conditions, capability-bearing execution handoff, and joined research state
Does not own: source authority, freshness, provenance, citation quality, material
              conflict resolution, collaborator transport, browser interaction, or writes
Allowed side effects: authorized read-only search/fetch and collaborator research calls
Inputs: requested question, literal targets, source families, freshness and coverage,
        explicit surface constraints, live capability inventory, and call budget
Exit states: routed, complete, partial, blocked
Outputs: capability handoff rows, joined search state, and source-handling result
Re-enter when: requested sources, capability, coverage, failure, conflict, or authority changes
```

This lane chooses the smallest source-capable research path. It does not make
every current-fact question a multi-model council and does not turn a preferred
broad-web engine into a substitute for platform-native access.

## Adjacent Owners

- Consume [source-handling](source-handling.md) for authority, freshness,
  provenance, sampling, citations, gap closure, and untrusted content.
- Route a material disagreement that survives source bounding to
  [conflict-resolution](conflict-resolution.md). Never resolve it by majority
  vote or model count.
- Use `cross-harness-workflow` and its direct-collaboration lane only
  after this lane selects AGY or Grok. That specialist owns headed/headless
  surface choice, permissions, prompt transport, logical sessions, waits, and
  response readback.
- Keep Parallel Search as a parent-native MCP arm. Do not pass its ranking,
  availability, results, or tool name to AGY or Grok unless the user explicitly
  asks the collaborator to consume that context.
- Use a purpose-built connector or authenticated specialist for private product
  resources. Use the browser specialist when rendered interaction, not search,
  is the outcome.

## Selection Order

1. Preserve an explicit user-selected engine, surface, or `only` constraint.
   State any coverage limitation before relying on the result. Do not add a
   second engine when `only` forbids it.
2. Identify the source family and the capability needed to answer the request,
   not merely a tool that can return related snippets.
3. Select one primary engine from the matrix below.
4. Expand only when a bounded fanout trigger applies. Stop once the requested
   coverage has exact supporting sources and no triggered material gap remains.

| Request or source family | Primary route | Required capability |
| --- | --- | --- |
| Literal `x.com` or `twitter.com` URL, X post/thread/replies, or live X sentiment | Grok | X-native post/search evidence and reply-thread coverage appropriate to the request |
| Literal Reddit URL, live Reddit threads or sentiment, explicit Google search, or Google-grounded live-web exploration | AGY | Reddit or Google/web grounding that returns exact underlying pages or honestly reports blocked coverage |
| Broad open-web discovery, primary-source finding, generic current-web comparison, or corroboration | Parallel Search MCP | Broad search plus direct fetch of the underlying sources needed for the claim |
| Multiple named source families or explicit cross-platform sentiment | Bounded fanout across the relevant rows | Independent source-family coverage with one parent join |

Parallel Search is the preferred broad-web engine under the owner-approved
policy. That preference is not evidence that it is universally best and never
overrides Grok's X-native role, AGY's Reddit/Google role, or an explicit user
surface.

## Bounded Fanout

Expand beyond the primary engine only when at least one condition is true:

- the request spans more than one source family;
- the user explicitly requests comparison, corroboration, or all relevant
  engines;
- the primary result has only snippets, generic home pages, missing dates,
  missing requested replies/threads, or no exact underlying sources;
- a high-stakes, disputed, or time-sensitive claim needs independent
  corroboration; or
- current legitimate sources materially disagree.

Use only the engines that can close the named gap. Poll and record each arm
independently. Do not give one engine another engine's synthesis before its
independent pass, and do not call all three for reassurance. Apply the one
focused gap-closure pass and coverage language owned by `source-handling`.

## Capability-Bearing Handoff

Create this handoff before an AGY or Grok research call. A collaborator name
alone is not an executable research contract.

```text
Web-search capability handoff:
- request and literal target:
- selected engine: Grok | AGY
- required source-native capability:
- coverage requirement:
- explicit surface constraint: headed | headless | user-selected session | none
- fallback authority: none | same-capability surface | bounded named fanout
- failure semantics:
- source-handling requirements:
- execution owner: cross-harness-workflow/direct-collaboration
- sufficient-evidence stop:
```

The execution owner must prove that its chosen surface exposes the required
capability. A default wrapper mode with search disabled does not satisfy a live
search handoff. If the selected surface cannot meet the capability, fail closed
or use only a fallback already authorized by the handoff. Never silently change
engine, surface, or source claim.

For Parallel Search, keep the equivalent request, literal target, capability,
coverage, failure, and stop fields in the parent route ledger. The parent calls
the native MCP directly and binds results to the exact search/fetch operations.

## Failure And Join Rules

- If an explicit `only` engine is unavailable, return `BLOCKED` or a partial
  result with the exact missing proof. Do not substitute another engine.
- If the default primary engine is unavailable, use another route only when it
  can satisfy the same required capability and the recorded fallback permits
  it. Otherwise preserve that source family as `Pending Verification`.
- Parallel or generic web results may corroborate public X or Reddit pages, but
  they do not prove native reply/thread coverage that was not retrieved.
- Distinguish firsthand posts, official/marketing material, summaries,
  reposted claims, and search snippets before synthesis.
- Prefer direct original sources for claims. Use model output as a discovery
  and synthesis layer, never as the source being cited.
- Report unresolved conflicts with their source scope and authority. Do not
  average incompatible claims or use agreement count as proof.

## Output

```text
Web-search result:
- request and source scope:
- primary route and capability:
- fanout: not triggered | bounded named arms and trigger
- literal targets and query boundaries:
- direct sources and source types:
- coverage: exhaustive | sampled | bounded lookup
- joined findings:
- conflicts and governing owner:
- unavailable lanes / fallback used:
- collaborator session identities: <IDs or Pending Verification>
- source-handling result: <source packet or compact reference>
- sufficient-evidence stop reached: yes | no
- Pending Verification:
```
