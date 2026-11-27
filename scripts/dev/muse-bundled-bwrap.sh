#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'muse bundled Bubblewrap selector: %s\n' "$*" >&2
  exit 125
}

binary=${MUSE_BUNDLED_BWRAP_ELF:-}
expected_version=${MUSE_BUNDLED_BWRAP_VERSION:-}
expected_sha256=${MUSE_BUNDLED_BWRAP_SHA256:-}

[[ "$binary" == /* ]] || die 'MUSE_BUNDLED_BWRAP_ELF must be an absolute path'
[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-R[0-9]+(\.[0-9]+)?$ ]] ||
  die 'MUSE_BUNDLED_BWRAP_VERSION is missing or malformed'
[[ "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] ||
  die 'MUSE_BUNDLED_BWRAP_SHA256 is missing or malformed'
[[ -f "$binary" && ! -L "$binary" && -x "$binary" ]] ||
  die 'Muse ELF must be an executable regular non-symlink file'
[[ "$(realpath -- "$binary")" == "$binary" ]] || die 'Muse ELF path must already be canonical'
[[ "${binary##*/}" == "muse-bin-$expected_version" ]] ||
  die 'Muse ELF filename does not match the expected release version'
[[ "$(od -An -tx1 -N4 "$binary" | tr -d ' \n')" == 7f454c46 ]] ||
  die 'Muse binary is not an ELF'
[[ "$(sha256sum "$binary" | awk '{print $1}')" == "$expected_sha256" ]] ||
  die 'Muse ELF digest changed after sandbox preflight'

export TBH_INTERNAL_MODE=bwrap
exec "$binary" __tbh_internal_bwrap "$@"
