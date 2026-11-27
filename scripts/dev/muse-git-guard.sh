#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'muse Git guard: %s\n' "$*" >&2
  exit 125
}

binary=${MUSE_GIT_GUARD_ELF:-}
expected_version=${MUSE_GIT_GUARD_VERSION:-}
expected_sha256=${MUSE_GIT_GUARD_SHA256:-}
bundled_bwrap=${MUSE_GIT_GUARD_BWRAP:-}
worktree=${MUSE_GIT_GUARD_WORKTREE:-}
expected_common_dir=${MUSE_GIT_GUARD_COMMON_DIR:-}
target_mode=${MUSE_GIT_GUARD_TARGET_MODE:-}
prompt_file=${MUSE_GIT_GUARD_PROMPT_FILE:-}
inner_bwrap=${MUSE_GIT_GUARD_INNER_BWRAP:-}
state_dir=${MUSE_GIT_GUARD_STATE_DIR:-}
https_proxy=${MUSE_GIT_GUARD_HTTPS_PROXY:-}
settings_file=${MUSE_GIT_GUARD_SETTINGS:-}
tool_gate=${MUSE_GIT_GUARD_TOOL_GATE:-}

for required_path in "$binary" "$bundled_bwrap" "$worktree" "$expected_common_dir" \
  "$prompt_file" "$inner_bwrap"; do
  [[ "$required_path" == /* ]] || die 'every guard path must be absolute'
done
if [[ -n "$state_dir" ]]; then
  [[ "$state_dir" == /* ]] || die 'Muse state path must be absolute'
fi
case "$target_mode" in
  ro|rw) ;;
  *) die 'MUSE_GIT_GUARD_TARGET_MODE must be ro or rw' ;;
esac
[[ "$https_proxy" =~ ^http://127\.0\.0\.1:([1-9][0-9]{0,4})$ ]] ||
  die 'MUSE_GIT_GUARD_HTTPS_PROXY must be a loopback HTTP proxy without credentials'
proxy_port=${BASH_REMATCH[1]}
(( proxy_port <= 65535 )) || die 'Muse proxy port is outside 1..65535'
[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-R[0-9]+(\.[0-9]+)?$ ]] ||
  die 'MUSE_GIT_GUARD_VERSION is missing or malformed'
[[ "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] ||
  die 'MUSE_GIT_GUARD_SHA256 is missing or malformed'
[[ -f "$binary" && ! -L "$binary" && -x "$binary" ]] || die 'Muse ELF is unsafe'
[[ "$(realpath "$binary")" == "$binary" ]] || die 'Muse ELF path must be canonical'
[[ "${binary##*/}" == "muse-bin-$expected_version" ]] || die 'Muse ELF version changed'
[[ "$(sha256sum "$binary" | awk '{print $1}')" == "$expected_sha256" ]] ||
  die 'Muse ELF digest changed'
[[ -f "$bundled_bwrap" && ! -L "$bundled_bwrap" && -x "$bundled_bwrap" ]] ||
  die 'per-run bundled Bubblewrap selector is unsafe'
[[ -d "$worktree" && ! -L "$worktree" && "$(realpath "$worktree")" == "$worktree" ]] ||
  die 'Muse target checkout is unsafe or non-canonical'
git_file="$worktree/.git"
[[ -e "$git_file" && ! -L "$git_file" && "$(realpath "$git_file")" == "$git_file" ]] ||
  die 'Muse target Git metadata is missing or unsafe'
[[ -d "$expected_common_dir" && ! -L "$expected_common_dir" &&
   "$(realpath "$expected_common_dir")" == "$expected_common_dir" ]] ||
  die 'Git common directory is unsafe or non-canonical'
[[ -f "$prompt_file" && ! -L "$prompt_file" && "$(realpath "$prompt_file")" == "$prompt_file" ]] ||
  die 'Muse prompt snapshot is unsafe or non-canonical'
[[ -f "$inner_bwrap" && ! -L "$inner_bwrap" && -x "$inner_bwrap" &&
   "$(realpath "$inner_bwrap")" == "$inner_bwrap" ]] ||
  die 'Muse inner Bubblewrap launcher is unsafe or non-canonical'
if [[ -n "$state_dir" ]]; then
  [[ -d "$state_dir" && ! -L "$state_dir" && "$(realpath "$state_dir")" == "$state_dir" ]] ||
    die 'Muse task state directory is unsafe or non-canonical'
fi

actual_common_dir=$(git -C "$worktree" rev-parse --git-common-dir)
if [[ "$actual_common_dir" == /* ]]; then
  actual_common_dir=$(realpath "$actual_common_dir")
else
  actual_common_dir=$(realpath "$worktree/$actual_common_dir")
fi
[[ "$actual_common_dir" == "$expected_common_dir" ]] || die 'Git common directory changed'

declare -A created_dirs=()
mount_args=(
  --die-with-parent
  --new-session
  --clearenv
  --unshare-pid
  --ro-bind /usr /usr
  --symlink usr/bin /bin
  --symlink usr/sbin /sbin
  --symlink usr/lib /lib
  --symlink usr/lib64 /lib64
  --dir /etc
  --ro-bind /etc/ssl/certs /etc/ssl/certs
  --ro-bind /etc/resolv.conf /etc/resolv.conf
  --ro-bind /etc/hosts /etc/hosts
  --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf
  --ro-bind /etc/passwd /etc/passwd
  --ro-bind /etc/group /etc/group
  --proc /proc
  --dev /dev
  --tmpfs /tmp
  --tmpfs /run
  --tmpfs /home
  --dir /home/sandbox-agent
  --dir /home/sandbox-agent/.config
  --dir /home/sandbox-agent/.config/muse
  --dir /home/sandbox-agent/.local
  --dir /home/sandbox-agent/.local/share
  --dir /opt
  --dir /opt/muse-guard
  --dir /run/muse-input
)
created_dirs[/etc]=1
created_dirs[/home]=1
for directory in /home/sandbox-agent /home/sandbox-agent/.config /home/sandbox-agent/.config/muse /home/sandbox-agent/.local /home/sandbox-agent/.local/share; do created_dirs[$directory]=1; done
created_dirs[/opt]=1
created_dirs[/opt/muse-guard]=1
created_dirs[/run]=1
created_dirs[/run/muse-input]=1
created_dirs[/tmp]=1
created_dirs[/usr]=1

append_parent_dirs() {
  local path=$1 parent current part
  parent=$(dirname "$path")
  current=""
  IFS='/' read -r -a parts <<<"${parent#/}"
  for part in "${parts[@]}"; do
    [[ -n "$part" ]] || continue
    current="$current/$part"
    if [[ -z "${created_dirs[$current]:-}" ]]; then
      mount_args+=(--dir "$current")
      created_dirs[$current]=1
    fi
  done
}

append_parent_dirs "$worktree"
append_parent_dirs "$expected_common_dir"
if [[ -n "$state_dir" ]]; then
  mount_args+=(--dir /state)
fi

if [[ "$target_mode" == rw ]]; then
  mount_args+=(--bind "$worktree" "$worktree")
else
  mount_args+=(--ro-bind "$worktree" "$worktree")
fi
mount_args+=(
  --ro-bind "$git_file" "$git_file"
  --ro-bind "$expected_common_dir" "$expected_common_dir"
  --ro-bind "$binary" /opt/muse-guard/muse
  --ro-bind "$inner_bwrap" /opt/muse-guard/bwrap
  --ro-bind "$prompt_file" /run/muse-input/prompt.txt
)
if [[ -n "$settings_file" || -n "$tool_gate" ]]; then
  for policy_file in "$settings_file" "$tool_gate"; do
    [[ "$policy_file" == /* && -f "$policy_file" && ! -L "$policy_file" ]] || die 'unsafe tool policy'
  done
  mount_args+=(--ro-bind "$settings_file" /home/sandbox-agent/.config/muse/settings.json
    --ro-bind "$tool_gate" /opt/muse-guard/tool-gate.py)
fi
if [[ -n "$state_dir" ]]; then
  mount_args+=(--bind "$state_dir" /state)
fi
mount_args+=(
  --chdir "$worktree"
  --setenv HOME /home/sandbox-agent
  --setenv XDG_CONFIG_HOME /home/sandbox-agent/.config
  --setenv XDG_DATA_HOME "$([[ -n "$state_dir" ]] && printf /state || printf /home/sandbox-agent/.local/share)"
  --setenv PATH /usr/bin:/bin
  --setenv LANG C.UTF-8
  --setenv LC_ALL C.UTF-8
  --setenv TERM dumb
  --setenv MUSE_NO_AUTO_UPDATE 1
  --setenv TBH_BWRAP_EXE /opt/muse-guard/bwrap
  --setenv HTTPS_PROXY "$https_proxy"
  --setenv https_proxy "$https_proxy"
  --unsetenv META_API_KEY
  --unsetenv TBH_INTERNAL_MODE
)

export TBH_BWRAP_EXE="$bundled_bwrap"
export MUSE_BUNDLED_BWRAP_ELF="$binary"
export MUSE_BUNDLED_BWRAP_VERSION="$expected_version"
export MUSE_BUNDLED_BWRAP_SHA256="$expected_sha256"
exec "$bundled_bwrap" "${mount_args[@]}" -- /opt/muse-guard/muse "$@"
