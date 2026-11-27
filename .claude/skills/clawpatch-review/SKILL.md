---
name: clawpatch-review
description: Use when running Clawpatch as an extra example-app reviewer for a branch, PR worktree, or scoped code area, especially when configuring scoped mapper include/exclude paths before `clawpatch map --source agent` and interpreting Clawpatch findings.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-10 -->

# Clawpatch Review

Use this skill to run Clawpatch as an advisory reviewer in a example-app
worktree. Clawpatch is useful when it gets a focused inventory. Do not rely on
the default whole-repo mapper for this repository.

## Use For

- running a Clawpatch review on a PR or branch before handoff, push follow-up,
  or reviewer reply
- creating a scoped `tmp/clawpatch-*.config.json` for frontend, backend,
  workflow, or XP-import review
- deciding whether Clawpatch feature slices actually cover the changed files
- summarizing Clawpatch findings as triage leads, not final truth

## Do Not Use For

- replacing normal code review, tests, type checks, or PR CI validation
- unscoped whole-repo review unless the user explicitly wants broad exploration
- accepting Clawpatch findings without checking the cited files and feature map
- running `clawpatch fix` unless the user explicitly asks for automated patching

## Core Rules

- Run Clawpatch from the PR/worktree branch, not from `local-dev-reference`, unless
  the branch under review is intentionally the root checkout.
- For PRs, use the live PR base or stack parent in `--since`; do not default to
  `origin/main` for stacked branches.
- Keep Clawpatch state local and ignored: use `tmp/clawpatch-<area>.config.json`
  plus `stateDir: "tmp/clawpatch-<area>-state"`.
- Always use `clawpatch map --source agent` with a scoped config. In tested
  example-app worktrees, default `clawpatch map` produced zero useful
  features, and broad agent mapping missed backend implementation files.
- After mapping, inspect generated features before review. A useful feature map
  must own or context the changed implementation files, not only tests.
- Use `--jobs 1` first to control provider cost, avoid noisy parallel output,
  and make failures easy to attribute.
- Treat findings as leads. Fix clear, in-scope P0/P1 or obvious medium defects;
  report low or adjacent-surface findings separately instead of expanding scope
  by default.

## Optional Provider Routing

The repo default is `provider.name: "codex"` with `model: "gpt-6.1-sol"` and
`reasoningEffort: "high"`. Keep that default unless the user explicitly wants
to test another provider path.

Clawpatch 0.5.0 does not have a native `litellm`, `base_url`, `baseUrl`,
`api_base`, or OpenAI-compatible endpoint field in its config. It delegates to
provider CLIs. In this environment, `opencode` is installed and
`clawpatch doctor --provider opencode --plain` has verified that Clawpatch can
call it. `acpx` is supported by Clawpatch but may need installation.

When testing LiteLLM or another OpenAI-compatible gateway, route through a
provider CLI that owns that gateway configuration instead of putting endpoint
settings in Clawpatch. Use a throwaway scoped config, keep state under `tmp/`,
and smoke `doctor` plus one scoped agent map before trusting review output:

```json
{
  "schemaVersion": 1,
  "stateDir": "tmp/clawpatch-opencode-state",
  "include": ["<changed-area>/**"],
  "exclude": [".git/**", ".clawpatch/**", ".data/**", "tmp/**"],
  "provider": { "name": "opencode", "model": "<opencode-model-id>", "reasoningEffort": "medium" }
}
```

```bash
clawpatch --config tmp/clawpatch-opencode.config.json doctor --plain
clawpatch --config tmp/clawpatch-opencode.config.json map --source agent --plain
```

Do not change the committed `.clawpatch/config.json` to a gateway-backed
provider until that path has been verified on the current machine and the user
wants it as their default.

## Workflow

1. Confirm the worktree and base:

   ```bash
   git status --short --branch
   git diff --name-only origin/<base>...HEAD
   ```

2. Create a scoped config under `tmp/`. Include only changed areas plus nearby
   contracts, tests, package manifests, and type config needed for review.

3. Initialize local state and verify the provider:

   ```bash
   clawpatch --config tmp/clawpatch-<area>.config.json init
   clawpatch --config tmp/clawpatch-<area>.config.json doctor --plain
   ```

4. Map with the agent mapper:

   ```bash
   clawpatch --config tmp/clawpatch-<area>.config.json map --source agent --plain
   ```

5. Inspect features before review:

   ```bash
   for f in tmp/clawpatch-<area>-state/features/*.json; do
     jq -r '[.featureId,.title,.kind,(.ownedFiles|map(.path)|join(",")),(.contextFiles|map(.path)|join(","))] | @tsv' "$f"
   done | sort
   clawpatch --config tmp/clawpatch-<area>.config.json review --since origin/<base> --dry-run --json
   ```

   If the selected features do not include the changed implementation files,
   narrow or adjust `include`, rerun mapping, and only then review.

6. Review selected features:

   ```bash
   clawpatch --config tmp/clawpatch-<area>.config.json review --since origin/<base> --jobs 1 --plain
   clawpatch --config tmp/clawpatch-<area>.config.json report
   ```

7. Read the report and cited source. Collapse duplicate findings from overlapping
   features. Classify each finding as in-scope, adjacent, false positive, or
   Pending Verification.

## Config Templates

Frontend component or utility PR:

```json
{
  "schemaVersion": 1,
  "stateDir": "tmp/clawpatch-frontend-state",
  "include": [
    "app/components/<area>/**",
    "app/utils/<related>/**",
    "app/public/locales/*/common.json",
    "app/package.json",
    "app/tsconfig.json"
  ],
  "exclude": [".git/**", ".clawpatch/**", ".data/**", "tmp/**", "app/node_modules/**"],
  "provider": { "name": "codex", "model": "gpt-6.1-sol", "reasoningEffort": "high" },
  "commands": {
    "typecheck": "yarn --cwd app type-check",
    "lint": null,
    "format": null,
    "test": "yarn --cwd app test -- <focused-test> --runInBand"
  },
  "review": { "maxContextFiles": 24, "maxOwnedFiles": 12, "maxFindingsPerFeature": 10, "minConfidenceToFix": "medium" },
  "git": { "requireCleanWorktreeForFix": true, "commit": false, "openPr": false }
}
```

XP-import/backend job PR:

```json
{
  "schemaVersion": 1,
  "stateDir": "tmp/clawpatch-xpimport-state",
  "include": [
    "backend/internal/xpimport/**",
    "backend/jobs/xp-mongo-to-postgres-import/**",
    "backend/go.mod"
  ],
  "exclude": [".git/**", ".clawpatch/**", ".data/**", "tmp/**"],
  "provider": { "name": "codex", "model": "gpt-6.1-sol", "reasoningEffort": "high" },
  "commands": {
    "typecheck": "go test ./internal/xpimport ./jobs/xp-mongo-to-postgres-import",
    "lint": null,
    "format": null,
    "test": "go test ./internal/xpimport ./jobs/xp-mongo-to-postgres-import"
  },
  "review": { "maxContextFiles": 24, "maxOwnedFiles": 12, "maxFindingsPerFeature": 10, "minConfidenceToFix": "medium" },
  "git": { "requireCleanWorktreeForFix": true, "commit": false, "openPr": false }
}
```

Workflow or infra PR:

```json
{
  "schemaVersion": 1,
  "stateDir": "tmp/clawpatch-infra-state",
  "include": [
    ".github/workflows/**",
    "scripts/**",
    "infrastructure/**",
    "pull_request_template.md",
    "CODEOWNERS"
  ],
  "exclude": [".git/**", ".clawpatch/**", ".data/**", "tmp/**"],
  "provider": { "name": "codex", "model": "gpt-6.1-sol", "reasoningEffort": "high" },
  "commands": { "typecheck": null, "lint": null, "format": null, "test": null },
  "review": { "maxContextFiles": 24, "maxOwnedFiles": 12, "maxFindingsPerFeature": 10, "minConfidenceToFix": "medium" },
  "git": { "requireCleanWorktreeForFix": true, "commit": false, "openPr": false }
}
```

## Interpreting Results

- Good signal: selected features own changed implementation files and findings
  cite those files with concrete failure paths.
- Weak signal: selected features own only tests, docs, or unrelated adjacent
  helpers. Adjust the config and rerun before trusting a zero-finding review.
- Duplicate signal: the same root cause appears in multiple feature slices.
  Collapse it to one finding before reporting or fixing.
- Adjacent signal: finding is real but outside the PR scope. Mention it as
  follow-up unless the user asks to expand scope.

Close with the config path, state/report path, selected feature count, finding
count, and your triage of actionable vs adjacent findings.
