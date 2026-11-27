#!/usr/bin/env bash
# Claude Code PostToolUse hook: format + lint the file Claude just touched.
# Reads the hook payload JSON on stdin; always exits 0 so formatter failures
# never block Claude's flow (lint errors still surface via stderr so the
# model sees them and can self-correct on the next turn).

set -u

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

file_path=$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti = d.get("tool_input") or {}
print(ti.get("file_path") or "")
' 2>/dev/null || true)

[[ -n "$file_path" && -f "$file_path" && "$file_path" == "$REPO_ROOT/"* ]] || exit 0

# Never format generated files — we'd just fight the generator.
case "$file_path" in
    */node_modules/*|*/.next/*|*/dist/*|*/build/*|*/coverage/*) exit 0 ;;
    */mock/mock_*.go) exit 0 ;;
    */backend/internal/shared/sql/querier.go|*/backend/internal/shared/sql/models.go|*/backend/internal/shared/sql/batch.go) exit 0 ;;
    */backend/internal/shared/sql/*.sql.go) exit 0 ;;
esac

ext="${file_path##*.}"

run_frontend_prettier() {
    (cd "$REPO_ROOT/app" && yarn --silent prettier:fix:files --log-level=warn "$file_path") >/dev/null 2>&1 || true
}

run_frontend_eslint() {
    # eslint runs in the background: one file is ~1–2 s on a warm cache;
    # we redirect stdout to /dev/null and surface only warnings/errors.
    (cd "$REPO_ROOT/app" && timeout 20 yarn --silent eslint --fix --no-warn-ignored "$file_path" 2>&1) \
        | tail -n 40 >&2 || true
}

run_backend_gofumpt() {
    command -v gofumpt >/dev/null 2>&1 && gofumpt -w "$file_path" >/dev/null 2>&1 || true
}

case "$file_path" in
    "$REPO_ROOT"/app/*)
        case "$ext" in
            ts|tsx|js|jsx|mjs|cjs|scss|css|json|md|yml|yaml)
                run_frontend_prettier
                ;;
        esac
        case "$ext" in
            ts|tsx|js|jsx|mjs|cjs)
                run_frontend_eslint
                ;;
        esac
        ;;
    "$REPO_ROOT"/backend/*)
        if [[ "$ext" == "go" ]]; then
            run_backend_gofumpt
        fi
        ;;
    "$REPO_ROOT"/e2e/*)
        case "$ext" in
            ts|tsx|js|json|md)
                (cd "$REPO_ROOT/e2e/pd" && npx --no-install prettier --write --log-level=warn "$file_path") >/dev/null 2>&1 || true
                ;;
        esac
        ;;
esac

exit 0
