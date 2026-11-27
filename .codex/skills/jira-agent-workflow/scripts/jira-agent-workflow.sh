#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${repo_root}" ]]; then
  repo_root="$(cd "${script_dir}/../../../.." && pwd)"
fi

export PATH="${HOME}/.local/bin:${HOME}/.local/share/mise/shims:${PATH}"

extract_env_file_value() {
  local file="$1"
  local key="$2"
  local raw

  [[ -f "${file}" ]] || return 0

  raw="$(
    sed -n -E \
      "s/^export[[:space:]]+${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*(#.*)?$/\\1/p;
       s/^export[[:space:]]+${key}[[:space:]]*=[[:space:]]*'([^']*)'[[:space:]]*(#.*)?$/\\1/p;
       s/^export[[:space:]]+${key}[[:space:]]*=[[:space:]]*([^#[:space:]]*)[[:space:]]*(#.*)?$/\\1/p;
       s/^${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*(#.*)?$/\\1/p;
       s/^${key}[[:space:]]*=[[:space:]]*'([^']*)'[[:space:]]*(#.*)?$/\\1/p;
       s/^${key}[[:space:]]*=[[:space:]]*([^#[:space:]]*)[[:space:]]*(#.*)?$/\\1/p" \
      "${file}" \
      | head -n1
  )" || true

  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"

  printf '%s' "${raw}"
}

load_env_value_if_unset() {
  local key="$1"
  local value

  [[ -z "${!key:-}" ]] || return 0

  value="$(extract_env_file_value "${repo_root}/.envrc" "${key}")"

  if [[ -n "${value}" ]]; then
    printf -v "${key}" '%s' "${value}"
    export "${key}"
  fi
}

load_env_value_if_unset JIRA_PERSONAL_TOKEN
load_env_value_if_unset JIRA_URL
load_env_value_if_unset JIRA_PROJECT_KEY
load_env_value_if_unset GH_TOKEN
load_env_value_if_unset GITHUB_PAT_TOKEN
load_env_value_if_unset COPILOT_GITHUB_TOKEN

jira_base="${JIRA_URL:-}"
jira_base="${jira_base%/}"
project_key="${JIRA_PROJECT_KEY:-DEMO}"
limit="10"
assignee="currentUser()"
board_id=""
board_name=""
base_ref="origin/main"
branch_prefix="codex"
dry_run=0
issue_key_arg=""
apply=0
link_jira_pr=0

usage() {
  cat <<'USAGE'
Usage:
  <skill-dir>/scripts/jira-agent-workflow.sh me
  <skill-dir>/scripts/jira-agent-workflow.sh issue <ISSUE_KEY>
  <skill-dir>/scripts/jira-agent-workflow.sh assigned-candidates [--project DEMO] [--assignee currentUser()|user.name] [--limit 10]
  <skill-dir>/scripts/jira-agent-workflow.sh boards [--project DEMO] [--name TEXT] [--limit 50]
  <skill-dir>/scripts/jira-agent-workflow.sh board <BOARD_ID>
  <skill-dir>/scripts/jira-agent-workflow.sh sprints --board <BOARD_ID>
  <skill-dir>/scripts/jira-agent-workflow.sh workflow-snapshot [--project DEMO] [--assignee currentUser()|user.name] [--board <REST_BOARD_ID>] [--limit 10]
  <skill-dir>/scripts/jira-agent-workflow.sh start-assigned-work [--project DEMO] [--assignee currentUser()|user.name] [--limit 10] [--base origin/main] [--prefix codex] [--dry-run]
  <skill-dir>/scripts/jira-agent-workflow.sh dev-info <ISSUE_KEY> [--summary] [--application-type github] [--data-type branch] [--sweep-application-types] [--poll] [--timeout-sec 90]
  <skill-dir>/scripts/jira-agent-workflow.sh branch-assert --issue <ISSUE_KEY> [--branch <BRANCH>]
  <skill-dir>/scripts/jira-agent-workflow.sh run-ledger init --issue <ISSUE_KEY> [--worktree <PATH>] [--branch <BRANCH>]
  <skill-dir>/scripts/jira-agent-workflow.sh run-ledger read --issue <ISSUE_KEY>
  <skill-dir>/scripts/jira-agent-workflow.sh run-ledger update --issue <ISSUE_KEY> --field <NAME> --value <VALUE>
  <skill-dir>/scripts/jira-agent-workflow.sh create-payload-dry-run --summary <TEXT> [--issue-type Task] [--description-file <PATH>] [--priority <NAME>] [--assignee <USER>]
  <skill-dir>/scripts/jira-agent-workflow.sh prepare-pr --issue <ISSUE_KEY> [--base origin/main]
  <skill-dir>/scripts/jira-agent-workflow.sh publish-pr --issue <ISSUE_KEY> [--base origin/main] [--dry-run] [--link-jira-pr]
  <skill-dir>/scripts/jira-agent-workflow.sh link-pr --issue <ISSUE_KEY> --pr-url <URL> --title <TEXT> [--apply]

Safe helper for Jira agent workflows. Set JIRA_URL before using Jira. Reads only JIRA_PERSONAL_TOKEN, JIRA_URL,
JIRA_PROJECT_KEY, GH_TOKEN, GITHUB_PAT_TOKEN, and COPILOT_GITHUB_TOKEN from .envrc or the
environment. Jira mutations must stay in MCP or an explicit apply path; tokens
are never printed.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

github_token_env() {
  local token

  token="$(github_token_value)"
  GH_TOKEN="${token}" GITHUB_TOKEN="${token}" "$@"
}

github_token_value() {
  local token="${GH_TOKEN:-}"

  if [[ -z "${token}" ]]; then
    token="${GITHUB_PAT_TOKEN:-}"
  fi
  if [[ -z "${token}" ]]; then
    token="${COPILOT_GITHUB_TOKEN:-}"
  fi

  [[ -n "${token}" ]] || die "No GitHub token found in environment or ${repo_root}/.envrc"
  printf '%s' "${token}"
}

git_push_with_github_token() {
  local worktree="$1"
  local branch="$2"
  local remote_url

  remote_url="$(git -C "${worktree}" remote get-url origin)"
  if [[ "${remote_url}" != https://github.com/* ]]; then
    git -C "${worktree}" push -u origin "${branch}"
    return
  fi

  local token
  local askpass
  token="$(github_token_value)"
  askpass="$(mktemp)"
  cat >"${askpass}" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  *Username*) printf '%s\n' 'x-access-token' ;;
  *Password*) printf '%s\n' "${GITHUB_TOKEN}" ;;
  *) printf '\n' ;;
esac
EOF
  chmod 700 "${askpass}"
  trap 'rm -f "${askpass}"' RETURN ERR
  GIT_ASKPASS="${askpass}" GIT_TERMINAL_PROMPT=0 GITHUB_TOKEN="${token}" \
    git -C "${worktree}" push -u origin "${branch}"
  rm -f "${askpass}"
  trap - RETURN ERR
}

require_env() {
  [[ "${jira_base}" == https://* ]] || die "Set JIRA_URL to your HTTPS Jira base URL"
  [[ -n "${JIRA_PERSONAL_TOKEN:-}" ]] || die "JIRA_PERSONAL_TOKEN is not set"
}

ready_worktree_husky() {
  local worktree="$1"

  require_cmd yarn
  yarn --cwd "${worktree}/.husky" install --non-interactive >/dev/null
  [[ -f "${worktree}/.husky/_/husky.sh" ]] ||
    die "Husky bootstrap failed: ${worktree}/.husky/_/husky.sh is missing"
  local hooks_path
  hooks_path="$(git -C "${worktree}" config --get core.hooksPath || true)"
  [[ "${hooks_path}" == ".husky" ]] ||
    die "Husky bootstrap failed: core.hooksPath is ${hooks_path:-unset}, expected .husky"
}

ready_worktree() {
  local worktree="$1"
  local readiness_script="${repo_root}/scripts/dev/prepare-worktree-readiness.sh"

  [[ -x "${readiness_script}" ]] ||
    die "worktree readiness helper is missing or not executable: ${readiness_script}"
  "${readiness_script}" "${worktree}" >/dev/null
}

jira_get() {
  require_env

  local path="$1"
  shift || true

  curl -fsS --get "${jira_base}${path}" \
    -H "Authorization: Bearer ${JIRA_PERSONAL_TOKEN}" \
    -H "Accept: application/json" \
    "$@"
}

jira_post_json() {
  require_env

  local path="$1"
  local payload="$2"

  curl -fsS -X POST "${jira_base}${path}" \
    -H "Authorization: Bearer ${JIRA_PERSONAL_TOKEN}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data "${payload}"
}

jira_put_json() {
  require_env

  local path="$1"
  local payload="$2"

  curl -fsS -X PUT "${jira_base}${path}" \
    -H "Authorization: Bearer ${JIRA_PERSONAL_TOKEN}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data "${payload}"
}

sanitize_global_id_part() {
  printf '%s' "$1" | sed -E 's#^https?://github.com/##; s#[^A-Za-z0-9._:/-]+#-#g'
}

valid_issue_key() {
  [[ "$1" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]]
}

require_issue_key() {
  local issue_key="$1"
  valid_issue_key "${issue_key}" || die "invalid Jira issue key: ${issue_key}"
}

ledger_dir() {
  printf '%s/tmp/jira-agent-runs' "${repo_root}"
}

ledger_path() {
  local issue_key="$1"
  printf '%s/%s.json' "$(ledger_dir)" "${issue_key}"
}

slugify() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' |
    cut -c1-48 |
    sed -E 's/-+$//'
}

fetch_remote_base_ref() {
  local ref="$1"
  local remote="${ref%%/*}"
  local branch="${ref#*/}"

  [[ "${ref}" == */* && "${remote}" != "${branch}" ]] || return 0
  git -C "${repo_root}" remote get-url "${remote}" >/dev/null 2>&1 || return 0
  git -C "${repo_root}" fetch --quiet "${remote}" "${branch}"
}

parse_common_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        project_key="${2:?missing --project value}"
        shift 2
        ;;
      --assignee)
        assignee="${2:?missing --assignee value}"
        shift 2
        ;;
      --limit)
        limit="${2:?missing --limit value}"
        shift 2
        ;;
      --board)
        board_id="${2:?missing --board value}"
        shift 2
        ;;
      --name)
        board_name="${2:?missing --name value}"
        shift 2
        ;;
      --base)
        base_ref="${2:?missing --base value}"
        shift 2
        ;;
      --prefix)
        branch_prefix="${2:?missing --prefix value}"
        shift 2
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      --link-jira-pr)
        link_jira_pr=1
        shift
        ;;
      --issue)
        issue_key_arg="${2:?missing --issue value}"
        shift 2
        ;;
      --apply)
        apply=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

board_unavailable_json() {
  local id="$1"
  local error="$2"

  jq -n --arg boardId "${id}" --arg error "${error}" '{
    boardId: ($boardId | tonumber? // $boardId),
    unavailable: true,
    error: $error,
    note: "This may be a browser-visible Jira board id that is not available through Jira Agile REST. Use the boards command to discover a REST-visible board id before sprint or board writes."
  }'
}

jql_assignee_clause() {
  if [[ "${assignee}" == "currentUser()" || "${assignee}" == "currentUser" ]]; then
    printf 'assignee = currentUser()'
  else
    [[ "${assignee}" =~ ^[A-Za-z0-9._@-]+$ ]] ||
      die "invalid --assignee value for JQL helper: ${assignee}"
    printf 'assignee = "%s"' "${assignee}"
  fi
}

jql_project_clause() {
  [[ "${project_key}" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]] ||
    die "invalid --project value for JQL helper: ${project_key}"
  printf 'project = %s' "${project_key}"
}

cmd_me() {
  jira_get "/rest/api/2/myself" |
    jq '{name, key, displayName, emailAddress, active}'
}

cmd_issue() {
  local issue_key="${1:-}"
  [[ -n "${issue_key}" ]] || die "issue key is required"
  require_issue_key "${issue_key}"

  jira_get "/rest/api/2/issue/${issue_key}" \
    --data-urlencode "fields=summary,status,priority,assignee,reporter,project,issuetype,created,updated,customfield_10004,customfield_10006,customfield_10009" |
    jq '{
      key,
      summary: .fields.summary,
      status: .fields.status.name,
      priority: .fields.priority.name,
      issueType: .fields.issuetype.name,
      project: .fields.project.key,
      assignee: (.fields.assignee.name // null),
      assigneeDisplayName: (.fields.assignee.displayName // null),
      reporter: (.fields.reporter.name // null),
      created: .fields.created,
      updated: .fields.updated,
      epicLink: .fields.customfield_10006,
      rank: .fields.customfield_10009,
      sprints: [
        (.fields.customfield_10004 // [])[] |
        capture("id=(?<id>[0-9]+).*name=(?<name>[^,\\]]+).*state=(?<state>[^,\\]]+)")?
      ]
    }'
}

cmd_assigned_candidates() {
  parse_common_flags "$@"

  local assignee_clause
  local project_clause
  assignee_clause="$(jql_assignee_clause)"
  project_clause="$(jql_project_clause)"
  local jql="${assignee_clause} AND ${project_clause} AND resolution = Unresolved ORDER BY priority DESC, updated DESC"

  jira_get "/rest/api/2/search" \
    --data-urlencode "jql=${jql}" \
    --data-urlencode "maxResults=${limit}" \
    --data-urlencode "fields=summary,status,priority,issuetype,updated,project" |
    jq --arg jql "${jql}" '{
      jql: $jql,
      total,
      issues: [
        .issues[] | {
          key,
          summary: .fields.summary,
          status: .fields.status.name,
          priority: .fields.priority.name,
          issueType: .fields.issuetype.name,
          updated: .fields.updated,
          project: .fields.project.key
        }
      ]
    }'
}

cmd_boards() {
  parse_common_flags "$@"

  local args=(
    --data-urlencode "projectKeyOrId=${project_key}"
    --data-urlencode "maxResults=${limit}"
  )
  if [[ -n "${board_name}" ]]; then
    args+=(--data-urlencode "name=${board_name}")
  fi

  local response
  local error_file
  error_file="$(mktemp)"
  if ! response="$(jira_get "/rest/agile/1.0/board" "${args[@]}" 2>"${error_file}")"; then
    jq -n --arg project "${project_key}" --arg error "$(cat "${error_file}")" \
      '{project: $project, unavailable: true, error: $error, boards: []}'
    rm -f "${error_file}"
    return 0
  fi

  rm -f "${error_file}"
  jq --arg project "${project_key}" '{
    project: $project,
    total: (.total // (.values | length)),
    boards: [
      .values[] | {
        id,
        name,
        type,
        self,
        location: (.location // null)
      }
    ]
  }' <<<"${response}"
}

cmd_board() {
  local id="${1:-}"
  [[ -n "${id}" ]] || die "board id is required"

  local response
  local error_file
  error_file="$(mktemp)"
  if ! response="$(jira_get "/rest/agile/1.0/board/${id}" 2>"${error_file}")"; then
    board_unavailable_json "${id}" "$(cat "${error_file}")"
    rm -f "${error_file}"
    return 0
  fi

  rm -f "${error_file}"
  jq '{id, name, type, self}' <<<"${response}"
}

cmd_sprints() {
  parse_common_flags "$@"
  [[ -n "${board_id}" ]] || die "--board is required"

  local response
  local error_file
  error_file="$(mktemp)"
  if ! response="$(jira_get "/rest/agile/1.0/board/${board_id}/sprint" \
    --data-urlencode "state=active,future" \
    --data-urlencode "maxResults=50" 2>"${error_file}")"; then
    board_unavailable_json "${board_id}" "$(cat "${error_file}")" |
      jq '. + {sprints: []}'
    rm -f "${error_file}"
    return 0
  fi

  rm -f "${error_file}"
  jq --arg boardId "${board_id}" '{
      boardId: ($boardId | tonumber? // $boardId),
      total: (.values | length),
      sprints: [
        .values[] | {
          id,
          name,
          state,
          startDate: (.startDate // null),
          endDate: (.endDate // null),
          originBoardId: (.originBoardId // null)
        }
      ]
    }' <<<"${response}"
}

cmd_workflow_snapshot() {
  parse_common_flags "$@"

  jq -n \
    --argjson me "$(cmd_me)" \
    --argjson candidates "$(cmd_assigned_candidates --project "${project_key}" --assignee "${assignee}" --limit "${limit}")" \
    --argjson sprints "$(if [[ -n "${board_id}" ]]; then cmd_sprints --board "${board_id}"; else printf 'null'; fi)" \
    '{me: $me, candidates: $candidates, sprints: $sprints}'
}

cmd_start_assigned_work() {
  parse_common_flags "$@"

  local candidates
  candidates="$(cmd_assigned_candidates --project "${project_key}" --assignee "${assignee}" --limit "${limit}")"

  local selected
  selected="$(jq -c '
    def priority_rank:
      {
        "Blocker": 6,
        "Critical": 5,
        "Highest": 5,
        "High": 4,
        "Medium": 3,
        "Low": 2,
        "Lowest": 1
      }[.priority] // 0;
    def active_rank:
      if (.status | ascii_downcase | test("backlog|to do|todo|open")) then 0 else 1 end;
    [.issues[]]
    | sort_by([priority_rank, active_rank, .updated])
    | reverse
    | .[0] // empty
  ' <<<"${candidates}")"
  [[ -n "${selected}" ]] || die "no unresolved assigned issues found"

  local issue_key
  local summary
  issue_key="$(jq -r '.key' <<<"${selected}")"
  summary="$(jq -r '.summary' <<<"${selected}")"
  require_issue_key "${issue_key}"

  local slug
  slug="$(slugify "${summary}")"
  [[ -n "${slug}" ]] || slug="work"

  local branch="${branch_prefix}/${issue_key}-${slug}"
  local worktree="${repo_root}/tmp/worktrees/${issue_key}-${slug}"

  if [[ "${dry_run}" -eq 1 ]]; then
    jq -n \
      --argjson candidates "${candidates}" \
      --argjson selected "${selected}" \
      --arg branch "${branch}" \
      --arg worktree "${worktree}" \
      --arg base "${base_ref}" \
      '{
        dryRun: true,
        selected: $selected,
        branch: $branch,
        worktree: $worktree,
        base: $base,
        candidates: $candidates.issues
      }'
    return 0
  fi

  fetch_remote_base_ref "${base_ref}"
  git -C "${repo_root}" rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null ||
    die "base ref not found: ${base_ref}"

  if git -C "${repo_root}" show-ref --verify --quiet "refs/heads/${branch}"; then
    die "branch already exists: ${branch}"
  fi

  if [[ -e "${worktree}" ]]; then
    die "worktree path already exists: ${worktree}"
  fi

  mkdir -p "$(dirname "${worktree}")"
  git -C "${repo_root}" worktree add -b "${branch}" "${worktree}" "${base_ref}" >/dev/null
  ready_worktree "${worktree}"

  cmd_run_ledger init --issue "${issue_key}" --worktree "${worktree}" --branch "${branch}" >/dev/null
  cmd_run_ledger update --issue "${issue_key}" --field status --value "worktree-created" >/dev/null
  cmd_branch_assert --issue "${issue_key}" --branch "${branch}" >/dev/null

  jq -n \
    --argjson selected "${selected}" \
    --arg branch "${branch}" \
    --arg worktree "${worktree}" \
    --arg base "${base_ref}" \
    --arg ledger "$(ledger_path "${issue_key}")" \
    '{
      dryRun: false,
      selected: $selected,
      branch: $branch,
      worktree: $worktree,
      base: $base,
      ledger: $ledger
    }'
}

cmd_branch_assert() {
  local issue_key=""
  local branch=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --issue)
        issue_key="${2:?missing --issue value}"
        shift 2
        ;;
      --branch)
        branch="${2:?missing --branch value}"
        shift 2
        ;;
      *)
        die "unknown argument for branch-assert: $1"
        ;;
    esac
  done

  [[ -n "${issue_key}" ]] || die "--issue is required"
  require_issue_key "${issue_key}"

  if [[ -z "${branch}" ]]; then
    branch="$(git -C "${repo_root}" branch --show-current)"
  fi
  [[ -n "${branch}" ]] || die "could not determine current branch; pass --branch"

  if [[ "${branch}" != *"${issue_key}"* ]]; then
    jq -n --arg issue "${issue_key}" --arg branch "${branch}" '{
      ok: false,
      issueKey: $issue,
      branch: $branch,
      error: "worktree drift detected: branch does not contain selected Jira key"
    }'
    return 1
  fi

  jq -n --arg issue "${issue_key}" --arg branch "${branch}" '{
    ok: true,
    issueKey: $issue,
    branch: $branch
  }'
}

cmd_run_ledger() {
  local action="${1:-}"
  shift || true

  local issue_key=""
  local worktree=""
  local branch=""
  local field=""
  local value=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --issue)
        issue_key="${2:?missing --issue value}"
        shift 2
        ;;
      --worktree)
        worktree="${2:?missing --worktree value}"
        shift 2
        ;;
      --branch)
        branch="${2:?missing --branch value}"
        shift 2
        ;;
      --field)
        field="${2:?missing --field value}"
        shift 2
        ;;
      --value)
        value="${2:?missing --value value}"
        shift 2
        ;;
      *)
        die "unknown argument for run-ledger: $1"
        ;;
    esac
  done

  [[ -n "${issue_key}" ]] || die "--issue is required"
  require_issue_key "${issue_key}"

  local path
  path="$(ledger_path "${issue_key}")"

  case "${action}" in
    init)
      mkdir -p "$(ledger_dir)"
      jq -n \
        --arg issue "${issue_key}" \
        --arg worktree "${worktree}" \
        --arg branch "${branch}" \
        --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          issueKey: $issue,
          createdAt: $createdAt,
          updatedAt: $createdAt,
          worktree: ($worktree | select(length > 0) // null),
          branch: ($branch | select(length > 0) // null),
          status: "initialized",
          confirmedMutations: [],
          pendingVerification: []
        }' >"${path}"
      jq . "${path}"
      ;;
    read)
      [[ -f "${path}" ]] || die "ledger does not exist: ${path}"
      jq . "${path}"
      ;;
    update)
      [[ -f "${path}" ]] || die "ledger does not exist: ${path}"
      [[ -n "${field}" ]] || die "--field is required for update"
      local tmp
      tmp="$(mktemp)"
      jq \
        --arg field "${field}" \
        --arg value "${value}" \
        --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.[$field] = $value | .updatedAt = $updatedAt' \
        "${path}" >"${tmp}"
      mv "${tmp}" "${path}"
      jq . "${path}"
      ;;
    *)
      die "run-ledger action must be init, read, or update"
      ;;
  esac
}

cmd_create_payload_dry_run() {
  local summary=""
  local issue_type="Task"
  local description_file=""
  local priority=""
  local create_assignee=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        project_key="${2:?missing --project value}"
        shift 2
        ;;
      --summary)
        summary="${2:?missing --summary value}"
        shift 2
        ;;
      --issue-type)
        issue_type="${2:?missing --issue-type value}"
        shift 2
        ;;
      --description-file)
        description_file="${2:?missing --description-file value}"
        shift 2
        ;;
      --priority)
        priority="${2:?missing --priority value}"
        shift 2
        ;;
      --assignee)
        create_assignee="${2:?missing --assignee value}"
        shift 2
        ;;
      *)
        die "unknown argument for create-payload-dry-run: $1"
        ;;
    esac
  done

  [[ -n "${summary}" ]] || die "--summary is required"

  local description=""
  if [[ -n "${description_file}" ]]; then
    [[ -f "${description_file}" ]] || die "description file not found: ${description_file}"
    description="$(<"${description_file}")"
  fi

  jq -n \
    --arg project "${project_key}" \
    --arg summary "${summary}" \
    --arg issueType "${issue_type}" \
    --arg description "${description}" \
    --arg priority "${priority}" \
    --arg assignee "${create_assignee}" \
    '{
      fields: {
        project: {key: $project},
        summary: $summary,
        issuetype: {name: $issueType}
      }
    }
    | if $description != "" then .fields.description = $description else . end
    | if $priority != "" then .fields.priority = {name: $priority} else . end
    | if $assignee != "" then .fields.assignee = {name: $assignee} else . end'
}

cmd_dev_info() {
  local issue_key="${1:-}"
  [[ -n "${issue_key}" ]] || die "issue key is required"
  shift || true
  require_issue_key "${issue_key}"

  local summary_only=0
  local application_type="github"
  local data_type_filter=""
  local sweep_application_types=0
  local poll=0
  local timeout_sec=90
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --summary)
        summary_only=1
        shift
        ;;
      --application-type)
        application_type="${2:?missing --application-type value}"
        shift 2
        ;;
      --data-type)
        data_type_filter="${2:?missing --data-type value}"
        shift 2
        ;;
      --sweep-application-types)
        sweep_application_types=1
        shift
        ;;
      --poll)
        poll=1
        shift
        ;;
      --timeout-sec)
        timeout_sec="${2:?missing --timeout-sec value}"
        shift 2
        ;;
      *)
        die "unknown argument for dev-info: $1"
        ;;
    esac
  done

  local start
  start="$(date +%s)"
  local issue_id
  issue_id="$(jira_get "/rest/api/2/issue/${issue_key}" --data-urlencode "fields=id" | jq -r '.id')"

  while true; do
    local summary
    local summary_error_file
    summary_error_file="$(mktemp)"
    if ! summary="$(jira_get "/rest/dev-status/latest/issue/summary" \
      --data-urlencode "issueId=${issue_id}" 2>"${summary_error_file}")"; then
      summary="$(jq -n --arg error "$(cat "${summary_error_file}")" '{unavailable: true, error: $error}')"
    fi
    rm -f "${summary_error_file}"

    if [[ "${summary_only}" -eq 1 ]]; then
      jq -n --arg issueKey "${issue_key}" --arg issueId "${issue_id}" --argjson summary "${summary}" '{
        issueKey: $issueKey,
        issueId: $issueId,
        summary: $summary
      }'
      return 0
    fi

    local output
    output="$(jq -n --arg issueKey "${issue_key}" --arg issueId "${issue_id}" --argjson summary "${summary}" '{
      issueKey: $issueKey,
      issueId: $issueId,
      summary: $summary,
      branches: [],
      pullRequests: [],
      commits: [],
      repositories: [],
      instances: [],
      unavailable: []
    }')"

    local application_types=("${application_type}")
    if [[ "${sweep_application_types}" -eq 1 ]]; then
      application_types=(github GitHub githube GitHubEnterprise stash bitbucket)
    fi

    local data_types=(branch pullrequest commit repository)
    if [[ -n "${data_type_filter}" ]]; then
      data_types=("${data_type_filter}")
    fi

    local data_type
    local app_type
    for app_type in "${application_types[@]}"; do
      for data_type in "${data_types[@]}"; do
        local response
        local error_file
        error_file="$(mktemp)"
        if response="$(jira_get "/rest/dev-status/latest/issue/detail" \
          --data-urlencode "issueId=${issue_id}" \
          --data-urlencode "applicationType=${app_type}" \
          --data-urlencode "dataType=${data_type}" 2>"${error_file}")"; then
          output="$(jq --arg applicationType "${app_type}" --arg dataType "${data_type}" --argjson response "${response}" '
            .instances += [
              ($response.detail // [])[]
              | select(._instance?)
              | ._instance + {applicationType: $applicationType, dataType: $dataType}
            ]
            | if $dataType == "branch" then
                .branches += [
                  ($response.detail // [])[]
                  | (.branches // [])[]
                  | . + {applicationType: $applicationType}
                ]
              elif $dataType == "pullrequest" then
                .pullRequests += [
                  ($response.detail // [])[]
                  | (.pullRequests // [])[]
                  | . + {applicationType: $applicationType}
                ]
              elif $dataType == "commit" then
                .commits += [
                  ($response.detail // [])[]
                  | (.commits // [])[]
                  | . + {applicationType: $applicationType}
                ]
              elif $dataType == "repository" then
                .repositories += [
                  ($response.detail // [])[]
                  | (.repositories // [])[]
                  | . + {applicationType: $applicationType}
                ]
              else . end
          ' <<<"${output}")"
        else
          output="$(jq --arg applicationType "${app_type}" --arg dataType "${data_type}" --arg error "$(cat "${error_file}")" '
            .unavailable += [{applicationType: $applicationType, dataType: $dataType, error: $error}]
          ' <<<"${output}")"
        fi
        rm -f "${error_file}"
      done
    done

    jq . <<<"${output}"

    if [[ "${poll}" -ne 1 ]]; then
      return 0
    fi

    if jq -e '((.branches | length) + (.pullRequests | length) + (.commits | length) + (.repositories | length)) > 0' <<<"${output}" >/dev/null; then
      return 0
    fi

    if (( $(date +%s) - start >= timeout_sec )); then
      return 0
    fi
    sleep 10
  done
}

cmd_prepare_pr() {
  parse_common_flags "$@"
  [[ -n "${issue_key_arg}" ]] || die "--issue is required"
  require_issue_key "${issue_key_arg}"

  local path
  path="$(ledger_path "${issue_key_arg}")"
  [[ -f "${path}" ]] || die "ledger does not exist: ${path}"

  local ledger
  local worktree
  local branch
  ledger="$(jq . "${path}")"
  worktree="$(jq -r '.worktree // empty' <<<"${ledger}")"
  branch="$(jq -r '.branch // empty' <<<"${ledger}")"
  [[ -n "${worktree}" && -d "${worktree}" ]] || die "ledger worktree does not exist: ${worktree}"
  [[ -n "${branch}" ]] || die "ledger branch is missing"

  local actual_branch
  actual_branch="$(git -C "${worktree}" branch --show-current)"
  [[ "${actual_branch}" == "${branch}" ]] || die "worktree branch mismatch: expected ${branch}, got ${actual_branch}"
  cmd_branch_assert --issue "${issue_key_arg}" --branch "${branch}" >/dev/null

  local status
  local commits_ahead
  local changed_files
  local has_diff=false
  status="$(git -C "${worktree}" status --short)"
  if ! commits_ahead="$(git -C "${worktree}" rev-list --count "${base_ref}..HEAD" 2>/dev/null)"; then
    die "base ref is missing or invalid for ${worktree}: ${base_ref}"
  fi
  if ! changed_files="$(git -C "${worktree}" diff --name-only "${base_ref}...HEAD" 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))')"; then
    die "failed to diff ${base_ref}...HEAD in ${worktree}"
  fi
  if [[ "${commits_ahead}" != "0" ]] || [[ "$(jq 'length' <<<"${changed_files}")" != "0" ]]; then
    has_diff=true
  fi

  local issue
  local summary
  local title
  local body
  issue="$(cmd_issue "${issue_key_arg}")"
  summary="$(jq -r '.summary' <<<"${issue}")"
  title="chore: ${issue_key_arg} ${summary}"
  body="$(cat <<EOF
## Description

### What?

- ${summary}

### Why?

- Jira issue: ${jira_base}/browse/${issue_key_arg}

## Reviewer guide

Review the branch diff and Jira issue context together.

The highest-value review points are whether the implementation matches the
Jira issue and whether validation is complete.

## Dependencies

None.

## Risks and impact (What is the risk level of the changes and why?)

- [ ] Minimal
- [x] Normal
- [ ] High

Pending Verification: confirm the final risk level before publishing.

## Verification

### Does this change the UI?

- [ ] Yes (if yes, provide screenshots/video)
- [x] No

### How can the changes be tested and verified?

- Pending Verification: replace this with commands actually run before publishing.

---

**Link to Github issue:**
${jira_base}/browse/${issue_key_arg}
EOF
)"

  jq -n \
    --arg issueKey "${issue_key_arg}" \
    --arg title "${title}" \
    --arg body "${body}" \
    --arg branch "${branch}" \
    --arg worktree "${worktree}" \
    --arg base "${base_ref}" \
    --arg status "${status}" \
    --argjson changedFiles "${changed_files}" \
    --argjson hasDiff "${has_diff}" \
    --argjson commitsAhead "${commits_ahead}" \
    '{
      issueKey: $issueKey,
      title: $title,
      body: $body,
      branch: $branch,
      worktree: $worktree,
      base: $base,
      clean: ($status == ""),
      status: $status,
      commitsAhead: $commitsAhead,
      hasDiff: $hasDiff,
      changedFiles: $changedFiles
    }'
}

cmd_publish_pr() {
  parse_common_flags "$@"
  [[ -n "${issue_key_arg}" ]] || die "--issue is required"
  require_issue_key "${issue_key_arg}"

  local prepared
  prepared="$(cmd_prepare_pr --issue "${issue_key_arg}" --base "${base_ref}")"

  if ! jq -e '.clean' <<<"${prepared}" >/dev/null; then
    jq '. + {published: false, error: "worktree has uncommitted changes; commit before publishing"}' <<<"${prepared}"
    return 1
  fi

  if ! jq -e '.hasDiff' <<<"${prepared}" >/dev/null; then
    jq '. + {published: false, error: "no branch diff exists; refusing to publish an empty PR"}' <<<"${prepared}"
    return 1
  fi

  if [[ "${dry_run}" -eq 1 ]]; then
    jq '. + {dryRun: true, published: false}' <<<"${prepared}"
    return 0
  fi

  require_cmd gh

  local worktree
  local branch
  local title
  local body
  worktree="$(jq -r '.worktree' <<<"${prepared}")"
  branch="$(jq -r '.branch' <<<"${prepared}")"
  title="$(jq -r '.title' <<<"${prepared}")"
  body="$(jq -r '.body' <<<"${prepared}")"

  local github_repo origin_url
  origin_url="$(git -C "${worktree}" remote get-url --push origin)"
  if [[ "${origin_url}" =~ ^(https://github[.]com/|git@github[.]com:|ssh://git@github[.]com/)([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$ ]]; then
    github_repo="${BASH_REMATCH[2]%.git}"
  else
    die "origin push URL must identify a github.com repository"
  fi

  git_push_with_github_token "${worktree}" "${branch}"

  local pr_url
  pr_url="$(github_token_env gh -R "${github_repo}" pr create \
    --base "${base_ref#origin/}" \
    --head "${branch}" \
    --title "${title}" \
    --body "${body}")"

  cmd_run_ledger update --issue "${issue_key_arg}" --field prUrl --value "${pr_url}" >/dev/null
  cmd_run_ledger update --issue "${issue_key_arg}" --field status --value "pr-created" >/dev/null

  local dev_info
  dev_info="$(cmd_dev_info "${issue_key_arg}" --sweep-application-types)"

  local jira_remote_link
  local jira_remote_link_command
  jira_remote_link="null"
  jira_remote_link_command="null"
  if ! jq -e '((.branches | length) + (.pullRequests | length) + (.commits | length) + (.repositories | length)) > 0' <<<"${dev_info}" >/dev/null; then
    if [[ "${link_jira_pr}" -eq 1 ]]; then
      jira_remote_link="$(cmd_link_pr --issue "${issue_key_arg}" --pr-url "${pr_url}" --title "${title}" --apply)"
    else
      jira_remote_link_command="$(jq -n \
        --arg command "<skill-dir>/scripts/jira-agent-workflow.sh link-pr --issue ${issue_key_arg} --pr-url ${pr_url} --title $(printf '%q' "${title}") --apply" \
        --arg reason "Jira development-info is empty; remote issue link is the deterministic fallback." \
        '{command: $command, reason: $reason}')"
    fi
  fi

  jq -n \
    --argjson prepared "${prepared}" \
    --arg prUrl "${pr_url}" \
    --argjson devInfo "${dev_info}" \
    --argjson jiraRemoteLink "${jira_remote_link}" \
    --argjson jiraRemoteLinkCommand "${jira_remote_link_command}" \
    '$prepared + {
      dryRun: false,
      published: true,
      prUrl: $prUrl,
      devInfo: $devInfo,
      jiraRemoteLink: $jiraRemoteLink,
      jiraRemoteLinkCommand: $jiraRemoteLinkCommand,
      jiraDevelopmentPanel: (if (((($devInfo.branches // []) | length) + (($devInfo.pullRequests // []) | length) + (($devInfo.commits // []) | length) + (($devInfo.repositories // []) | length)) > 0) then "linked" else "Pending Verification" end)
    }'
}

cmd_link_pr() {
  local pr_url=""
  local title=""
  local relationship="pull request"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --issue)
        issue_key_arg="${2:?missing --issue value}"
        shift 2
        ;;
      --pr-url)
        pr_url="${2:?missing --pr-url value}"
        shift 2
        ;;
      --title)
        title="${2:?missing --title value}"
        shift 2
        ;;
      --relationship)
        relationship="${2:?missing --relationship value}"
        shift 2
        ;;
      --apply)
        apply=1
        shift
        ;;
      *)
        die "unknown argument for link-pr: $1"
        ;;
    esac
  done

  [[ -n "${issue_key_arg}" ]] || die "--issue is required"
  require_issue_key "${issue_key_arg}"
  [[ -n "${pr_url}" ]] || die "--pr-url is required"
  [[ "${pr_url}" =~ ^https://github[.]com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+$ ]] ||
    die "--pr-url must be a GitHub PR URL"
  [[ -n "${title}" ]] || die "--title is required"

  local global_id
  global_id="github:$(sanitize_global_id_part "${pr_url}")"

  local existing
  existing="$(jira_get "/rest/api/2/issue/${issue_key_arg}/remotelink")"

  local existing_link
  existing_link="$(jq -c --arg globalId "${global_id}" --arg url "${pr_url}" '
    map(select((.globalId // "") == $globalId or (.object.url // "") == $url)) | .[0] // empty
  ' <<<"${existing}")"

  local payload
  payload="$(jq -n \
    --arg globalId "${global_id}" \
    --arg url "${pr_url}" \
    --arg title "${title}" \
    --arg relationship "${relationship}" \
    '{
      globalId: $globalId,
      relationship: $relationship,
      object: {
        url: $url,
        title: $title,
        icon: {
          url16x16: "https://github.githubassets.com/favicons/favicon.png",
          title: "GitHub"
        }
      }
    }')"

  if [[ "${apply}" -ne 1 ]]; then
    jq -n \
      --arg issueKey "${issue_key_arg}" \
      --arg prUrl "${pr_url}" \
      --arg title "${title}" \
      --arg globalId "${global_id}" \
      --argjson existing "$(if [[ -n "${existing_link}" ]]; then printf '%s' "${existing_link}"; else printf 'null'; fi)" \
      --argjson payload "${payload}" \
      '{
        dryRun: true,
        issueKey: $issueKey,
        prUrl: $prUrl,
        title: $title,
        globalId: $globalId,
        existing: $existing,
        payload: $payload,
        note: "Pass --apply to create or update this Jira remote issue link."
      }'
    return 0
  fi

  local response
  if [[ -n "${existing_link}" ]]; then
    local link_id
    link_id="$(jq -r '.id' <<<"${existing_link}")"
    response="$(jira_put_json "/rest/api/2/issue/${issue_key_arg}/remotelink/${link_id}" "${payload}")"
  else
    response="$(jira_post_json "/rest/api/2/issue/${issue_key_arg}/remotelink" "${payload}")"
  fi
  if [[ -z "${response}" ]]; then
    response="{}"
  fi

  existing="$(jira_get "/rest/api/2/issue/${issue_key_arg}/remotelink")"
  existing_link="$(jq -c --arg globalId "${global_id}" --arg url "${pr_url}" '
    map(select((.globalId // "") == $globalId or (.object.url // "") == $url)) | .[0] // null
  ' <<<"${existing}")"

  jq -n \
    --arg issueKey "${issue_key_arg}" \
    --arg prUrl "${pr_url}" \
    --arg title "${title}" \
    --arg globalId "${global_id}" \
    --argjson response "${response}" \
    --argjson remoteLink "${existing_link}" \
    '{
      dryRun: false,
      issueKey: $issueKey,
      prUrl: $prUrl,
      title: $title,
      globalId: $globalId,
      response: $response,
      remoteLink: $remoteLink,
      status: (if $remoteLink == null then "Pending Verification" else "remote-link-present" end)
    }'
}

main() {
  local command="${1:-}"
  shift || true

  case "${command}" in
    -h|--help|"")
      usage
      return 0
      ;;
  esac

  require_cmd curl
  require_cmd jq

  case "${command}" in
    me)
      cmd_me
      ;;
    issue)
      cmd_issue "$@"
      ;;
    assigned-candidates)
      cmd_assigned_candidates "$@"
      ;;
    boards)
      cmd_boards "$@"
      ;;
    board)
      cmd_board "$@"
      ;;
    sprints)
      cmd_sprints "$@"
      ;;
    workflow-snapshot)
      cmd_workflow_snapshot "$@"
      ;;
    start-assigned-work)
      cmd_start_assigned_work "$@"
      ;;
    dev-info)
      cmd_dev_info "$@"
      ;;
    branch-assert)
      cmd_branch_assert "$@"
      ;;
    run-ledger)
      cmd_run_ledger "$@"
      ;;
    create-payload-dry-run)
      cmd_create_payload_dry_run "$@"
      ;;
    prepare-pr)
      cmd_prepare_pr "$@"
      ;;
    publish-pr)
      cmd_publish_pr "$@"
      ;;
    link-pr)
      cmd_link_pr "$@"
      ;;
    *)
      die "unknown command: ${command}"
      ;;
  esac
}

main "$@"
