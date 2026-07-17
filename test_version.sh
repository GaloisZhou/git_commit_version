#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=../lib/version.sh
source "${LIB_DIR}/version.sh"

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [ "$got" != "$want" ]; then
    echo "FAIL: ${msg} (got=${got}, want=${want})" >&2
    exit 1
  fi
  echo "OK: ${msg}"
}

assert_eq "$(version_parse_sequence '20260630.120000.0')" "0" "parse sequence 0"
assert_eq "$(version_parse_sequence '20260630.120000.42')" "42" "parse sequence 42"
assert_eq "$(version_parse_sequence 'invalid')" "-1" "parse invalid"

assert_eq "$(version_max_sequence '20260630.120000.3' '20260629.235959.10')" "10" "max sequence"
assert_eq "$(version_max_sequence '')" "-1" "max empty"

next="$(version_compute_next '20260630.120000.5')"
if [[ ! "$next" =~ ^[0-9]{8}\.[0-9]{6}\.6$ ]]; then
  echo "FAIL: compute next (got=${next}, want=*.6)" >&2
  exit 1
fi
echo "OK: compute next -> ${next}"

next_first="$(version_compute_next '')"
if [[ ! "$next_first" =~ ^[0-9]{8}\.[0-9]{6}\.0$ ]]; then
  echo "FAIL: first version (got=${next_first}, want=*.0)" >&2
  exit 1
fi
echo "OK: first version -> ${next_first}"

# merge driver: writes max(seq)+1 into %A
tmp="$(mktemp -d "${TMPDIR:-/tmp}/git-version-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
printf '20260630.120000.3\n' > "${tmp}/ours"
printf '20260630.130000.10\n' > "${tmp}/theirs"
printf '20260630.110000.1\n' > "${tmp}/base"
"${LIB_DIR}/merge-version.sh" "${tmp}/base" "${tmp}/ours" "${tmp}/theirs" >/dev/null
merged="$(tr -d '[:space:]' < "${tmp}/ours")"
if [[ ! "$merged" =~ ^[0-9]{8}\.[0-9]{6}\.11$ ]]; then
  echo "FAIL: merge driver (got=${merged}, want=*.11)" >&2
  exit 1
fi
echo "OK: merge driver -> ${merged}"

echo "all tests passed"
