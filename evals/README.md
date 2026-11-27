# Waza skill evaluations

These suites exercise the skills shipped in this repository. Each suite lives
in `evals/<skill>/` and binds to the public skill name. Its manifest selects the
skill edition to evaluate. The included scenarios use example projects and
fixtures.

## Offline trigger checks

Install [Waza](https://github.com/microsoft/waza/releases) and run from the
repository root. The trigger suite commands below were checked with Waza
0.38.0.

```sh
waza --no-update-check run evals/work-orchestration/eval.yaml -v
waza --no-update-check run evals/pr-workflow/eval.yaml -v
```

To run all 21 trigger suites:

```sh
(
  set -e
  for suite in evals/*/eval.yaml; do
    waza --no-update-check run "$suite"
  done
)
```

Each `eval.yaml` uses the mock executor. The scores check trigger alignment
and suite wiring. The mock executor makes no model calls. Use the behavior
suites to evaluate model responses.

## Model-backed behavior suites

The six `behavior-eval.yaml` manifests add scenarios with program graders
or rubrics. They cover authoring, database review, GitHub operations, pull
requests, review, and orchestration. The manifests use `copilot-sdk` and
require an authorized model provider. Prompt graders can need a separate
judge model.

Review the selected task and its graders before executing it. Use a
disposable checkout and test-only credentials where a scenario needs them.
For a provider-free check of input assembly, run the focused runner with an
explicit route and `--dry-run`. The supplied model name in this example is
only a placeholder for the dry run.

```sh
ruby scripts/dev/run-behavior-eval.rb \
  --suite evals/database-reviewer/behavior-eval.yaml \
  --task database-reviewer-behavior-safe-additive \
  --instruction-file .codex/skills/database-reviewer/references/verdict-closeout.md \
  --route vpn --waza-model example-model --dry-run
```

Some behavior tasks need a linked reference in addition to `SKILL.md`.
Pass the exact reference with `--instruction-file`. The helper's
`--help` describes the explicit Waza and Pi routes. Supply approved execution
and judge models before a real run. Generated results and cache files stay
under `tmp/waza-results/` and `tmp/waza-cache/`.

## Database evidence fixtures

The bundled Cloud SQL snapshots demonstrate the evidence format with
illustrative values. Use fixture mode to validate their structure, collector
checksums, and internal consistency.

```sh
python3 evals/database-reviewer/validate_environment_context.py --fixture \
  .codex/skills/database-reviewer/evidence/staging-cloudsql.yaml \
  .codex/skills/database-reviewer/evidence/production-cloudsql.yaml
```

Python 3 and PyYAML are required for the snapshot validator. Operational
evidence requires current source and environment verification.
