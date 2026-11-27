#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/check-muse-linux-sandbox.sh [--muse-bin <path>] [--json]

Resolve the active Muse ELF, bind it to its release version and SHA-256, pin
the repo-owned selector and outer Git guard by digest, and prove that the
non-privileged selector exposes Muse's bundled Bubblewrap with the capabilities
required by managed shell. By default, select the bundled outer backend when
its namespace probe passes, otherwise the system backend when its probe passes.
MUSE_OUTER_BWRAP_SYSTEM=0 or 1 explicitly pins bundled or system; auto is the
default. A blocked explicit choice is never replaced. Nothing is installed and no privilege elevation is
attempted.

The bundled backend avoids a known host conflict where Ubuntu's AppArmor
profile for /usr/bin/bwrap denies execution of Muse's deleted-entry embedded
helper. Muse releases at or above the minimum are capability-checked and bound by
SHA-256 for each run. Older/malformed versions, missing capabilities, selector
or guard drift, unsafe paths, and within-run digest changes fail closed.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

resolve_command_path() {
  local requested=$1 resolved
  if [[ "$requested" == */* ]]; then
    [[ -e "$requested" ]] || die "Muse path does not exist: $requested"
    resolved=$(realpath "$requested")
  else
    resolved=$(command -v "$requested" 2>/dev/null || true)
    [[ -n "$resolved" ]] || die "Muse CLI not found on PATH: $requested"
    resolved=$(realpath "$resolved")
  fi
  [[ -f "$resolved" && ! -L "$resolved" ]] ||
    die 'Muse path must resolve to a regular non-symlink file'
  printf '%s\n' "$resolved"
}

is_elf() {
  [[ "$(od -An -tx1 -N4 "$1" 2>/dev/null | tr -d ' \n')" == 7f454c46 ]]
}

resolve_active_elf() {
  local requested=$1 candidate install_dir version
  candidate=$(resolve_command_path "$requested")
  if is_elf "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  install_dir=${candidate%/*}
  [[ -f "$install_dir/.muse-version" && ! -L "$install_dir/.muse-version" ]] ||
    die 'Muse launcher has no readable non-symlink .muse-version sibling'
  version=$(sed -n '1p' "$install_dir/.muse-version")
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-R[0-9]+(\.[0-9]+)?$ ]] ||
    die 'Muse launcher .muse-version is malformed'
  candidate="$install_dir/muse-bin-$version"
  [[ -f "$candidate" && ! -L "$candidate" && -x "$candidate" ]] ||
    die "active Muse ELF is missing or unsafe: $candidate"
  is_elf "$candidate" || die 'active Muse binary is not an ELF'
  printf '%s\n' "$(realpath "$candidate")"
}

binary_version() {
  local binary=$1 name version
  name=${binary##*/}
  case "$name" in
    muse-bin-*) version=${name#muse-bin-} ;;
    *) die 'active Muse ELF filename does not carry a release version' ;;
  esac
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-R[0-9]+(\.[0-9]+)?$ ]] ||
    die 'could not derive a release version from the Muse ELF'
  printf '%s\n' "$version"
}

version_at_least() {
  local actual=$1 minimum=$2
  local release_pattern='^[0-9]+\.[0-9]+\.[0-9]+-R[0-9]+(\.[0-9]+)?$'
  [[ "$actual" =~ $release_pattern && "$minimum" =~ $release_pattern ]] || return 1
  # An omitted revision patch is equivalent to .0.
  [[ "${actual##*-R}" == *.* ]] || actual+=.0
  [[ "${minimum##*-R}" == *.* ]] || minimum+=.0
  printf '%s\n%s\n' "$minimum" "$actual" | LC_ALL=C sort -V -C
}

# Keep selection in preflight so callers execute the backend actually probed.
# Explicit 0/1 retain the historical bundled/system choices; unset means auto.
select_outer_backend() {
  local requested=$1 bundled=$2 system=$3 selected_namespace
  case "$requested" in
    auto)
      if [[ "$bundled" == ok ]]; then
        outer_backend_selected=muse_bundled_bwrap
      elif [[ "$system" == ok ]]; then
        outer_backend_selected=system_bwrap
      else
        outer_backend_selected=muse_bundled_bwrap
      fi
      ;;
    0) outer_backend_selected=muse_bundled_bwrap ;;
    1) outer_backend_selected=system_bwrap ;;
    *) die 'MUSE_OUTER_BWRAP_SYSTEM must be auto, 0 (bundled), or 1 (system)' ;;
  esac
  if [[ "$outer_backend_selected" == system_bwrap ]]; then
    selected_namespace=$system
  else
    selected_namespace=$bundled
  fi
  if [[ "$selected_namespace" == ok ]]; then
    status=ready
  elif [[ "$bundled" != ok && "$system" != ok ]]; then
    status=blocked_no_usable_outer_backend
  else
    status=blocked_selected_outer_backend
  fi
}

root=$(git rev-parse --show-toplevel)
muse_bin=${AGENT_CALL_MUSE_BIN:-muse}
minimum_muse_version=1.0.3-R2198.1
expected_selector_sha256=fbd28926c0c483372cddc6652f44f6c2933fa4b0c8780e8a3624b662ee5de7a5
expected_git_guard_sha256=2382c106b8a5e7d351cb722a494678f06cec46d9a30f8d8bd3729d998a5bb7ef
expected_meta_proxy_sha256=d581d0052495ebcca324023f43d91877dd228125c2251cb128dc495a8b9402fa
json=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --muse-bin) muse_bin=${2:-}; shift 2 ;;
    --json) json=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die 'jq is required'
binary=$(resolve_active_elf "$muse_bin")
version=$(binary_version "$binary")
digest=$(sha256sum "$binary" | awk '{print $1}')
version_at_least "$version" "$minimum_muse_version" ||
  die "Muse release $version is below minimum $minimum_muse_version or malformed"
# The digest binds this invocation, not a permanently pinned upstream release.
exec_help=$(timeout 10 "$binary" exec --help 2>/dev/null) || die 'Muse exec capability probe failed'
for capability in --json --api-key-stdin --provider --model --reasoning-effort --base-url \
  --workspace --trust-workspace --approval-mode --approval-judge --no-foreign-personal-context \
  --max-model-steps --session-id --no-session-log --disable-web-tools --disable-shell \
  --sandbox-network --disable-write; do
  grep -Eq -- "(^|[[:space:]])${capability}([[:space:]]|$)" <<<"$exec_help" ||
    die "Muse exec lacks required capability: $capability"
done
selector="$root/scripts/dev/muse-bundled-bwrap.sh"
[[ -f "$selector" && ! -L "$selector" && -x "$selector" ]] ||
  die "bundled Bubblewrap selector is missing or unsafe: $selector"
[[ "$(realpath "$selector")" == "$selector" ]] || die 'selector path must already be canonical'
selector_sha256=$(sha256sum "$selector" | awk '{print $1}')
[[ "$selector_sha256" == "$expected_selector_sha256" ]] ||
  die 'bundled Bubblewrap selector digest changed; review and repin it before workhorse execution'
git_guard="$root/scripts/dev/muse-git-guard.sh"
[[ -f "$git_guard" && ! -L "$git_guard" && -x "$git_guard" ]] ||
  die "Muse Git guard is missing or unsafe: $git_guard"
[[ "$(realpath "$git_guard")" == "$git_guard" ]] || die 'Git guard path must already be canonical'
git_guard_sha256=$(sha256sum "$git_guard" | awk '{print $1}')
[[ "$git_guard_sha256" == "$expected_git_guard_sha256" ]] ||
  die 'Muse Git guard digest changed; review and repin it before workhorse execution'
meta_proxy="$root/scripts/dev/muse-meta-connect-proxy.mjs"
[[ -f "$meta_proxy" && ! -L "$meta_proxy" && -x "$meta_proxy" ]] ||
  die "Muse Meta CONNECT proxy is missing or unsafe: $meta_proxy"
[[ "$(realpath "$meta_proxy")" == "$meta_proxy" ]] || die 'Meta proxy path must already be canonical'
meta_proxy_sha256=$(sha256sum "$meta_proxy" | awk '{print $1}')
[[ "$meta_proxy_sha256" == "$expected_meta_proxy_sha256" ]] ||
  die 'Muse Meta CONNECT proxy digest changed; review and repin it before live execution'

selector_env=(
  MUSE_BUNDLED_BWRAP_ELF="$binary"
  MUSE_BUNDLED_BWRAP_VERSION="$version"
  MUSE_BUNDLED_BWRAP_SHA256="$digest"
)
bwrap_version=$(timeout 10 env "${selector_env[@]}" "$selector" --version 2>/dev/null) ||
  die 'Muse bundled Bubblewrap version probe failed'
[[ "$bwrap_version" == 'bubblewrap built for TBH' ]] ||
  die 'selector did not expose Muse bundled Bubblewrap'
bwrap_help=$(timeout 10 env "${selector_env[@]}" "$selector" --help 2>/dev/null) ||
  die 'Muse bundled Bubblewrap capability probe failed'
[[ "$bwrap_help" == *'--perms OCTAL'* && "$bwrap_help" == *'--ro-bind-data FD DEST'* ]] ||
  die 'Muse bundled Bubblewrap lacks required managed-shell capabilities'

[[ "$(sha256sum "$binary" | awk '{print $1}')" == "$digest" ]] ||
  die 'Muse ELF changed during capability preflight'
capability_probe=ok

# Namespace readiness is a separate fact from capability presence. The probes
# above only read --version/--help; they never ask the kernel for a user
# namespace, so they cannot detect a host that denies UID mapping (for example
# kernel.apparmor_restrict_unprivileged_userns, which transitions an unconfined
# backend into the restrictive `unprivileged_userns` profile). Exercise each
# candidate OUTER guard backend for real, bounded and side-effect free, and
# report each separately. Neither result proves Muse's inner managed-shell
# sandbox operates through the selected combination.
probe_namespace() {
  local label=$1; shift
  local out
  if out=$(timeout 15 "$@" --unshare-user --unshare-pid --unshare-ipc \
    --ro-bind /usr /usr --ro-bind /bin /bin --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 --proc /proc --dev /dev --tmpfs /tmp \
    /bin/true 2>&1); then
    printf 'ok'
  elif [[ "$out" == *'uid map'* || "$out" == *'Permission denied'* ||
          "$out" == *'No permissions to create'*'namespace'* ]]; then
    printf 'denied'
  else
    printf 'failed'
  fi
}

bundled_namespace=$(probe_namespace bundled env "${selector_env[@]}" "$selector")
if [[ -f /usr/bin/bwrap && ! -L /usr/bin/bwrap && -x /usr/bin/bwrap ]]; then
  system_bwrap_namespace=$(probe_namespace system /usr/bin/bwrap)
else
  system_bwrap_namespace=absent
fi

# Never retry a launched provider with another backend. Select only from these
# provider-free probes, before credentials or a model session are involved.
outer_backend_requested=${MUSE_OUTER_BWRAP_SYSTEM-auto}
select_outer_backend "$outer_backend_requested" "$bundled_namespace" "$system_bwrap_namespace"

if [[ "$json" -eq 1 ]]; then
  jq -n \
    --arg binary "$binary" \
    --arg version "$version" \
    --arg minimum_version "$minimum_muse_version" \
    --arg sha256 "$digest" \
    --arg selector "$selector" \
    --arg selector_sha256 "$selector_sha256" \
    --arg git_guard "$git_guard" \
    --arg git_guard_sha256 "$git_guard_sha256" \
    --arg meta_proxy "$meta_proxy" \
    --arg meta_proxy_sha256 "$meta_proxy_sha256" \
    --arg status "$status" \
    --arg capability_probe "$capability_probe" \
    --arg bundled_namespace "$bundled_namespace" \
    --arg system_bwrap_namespace "$system_bwrap_namespace" \
    --arg outer_backend_requested "$outer_backend_requested" \
    --arg outer_backend_selected "$outer_backend_selected" \
    '{status: $status, backend: "muse_bundled_bwrap",
      capability_probe: $capability_probe,
      namespace_probe: {bundled: $bundled_namespace,
        system_bwrap: $system_bwrap_namespace},
      outer_backend_requested: $outer_backend_requested,
      outer_backend_selected: $outer_backend_selected,
      inner_backend: "muse_bundled_bwrap",
      inner_managed_shell_proven: false,
      binary: $binary,
      version: $version, minimum_version: $minimum_version, version_policy: "minimum-with-capability-probes", sha256: $sha256, selector: $selector,
      selector_sha256: $selector_sha256, git_guard: $git_guard,
      git_guard_sha256: $git_guard_sha256,
      meta_proxy: $meta_proxy, meta_proxy_sha256: $meta_proxy_sha256,
      privilege_required: false}'
else
  printf 'status=%s\nbackend=muse_bundled_bwrap\ncapability_probe=%s\nnamespace_probe_bundled=%s\nnamespace_probe_system_bwrap=%s\nouter_backend_selected=%s\ninner_backend=muse_bundled_bwrap\ninner_managed_shell_proven=false\nbinary=%s\nversion=%s\nsha256=%s\nselector=%s\nselector_sha256=%s\ngit_guard=%s\ngit_guard_sha256=%s\nprivilege_required=false\n' \
    "$status" "$capability_probe" "$bundled_namespace" "$system_bwrap_namespace" \
    "$outer_backend_selected" \
    "$binary" "$version" "$digest" "$selector" "$selector_sha256" \
    "$git_guard" "$git_guard_sha256"
fi
