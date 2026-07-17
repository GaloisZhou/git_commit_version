#!/usr/bin/env bash
# Git merge driver for .version
# Invoked as: merge-version.sh %O %A %B
# Writes resolved content into %A; exit 0 = merged cleanly.

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=version.sh
source "${LIB_DIR}/version.sh"

if [ "$#" -lt 3 ]; then
  echo "git-version: merge-version expects %O %A %B" >&2
  exit 1
fi

ours_file="$2"
theirs_file="$3"

ours="$(tr -d '[:space:]' < "$ours_file" 2>/dev/null || true)"
theirs="$(tr -d '[:space:]' < "$theirs_file" 2>/dev/null || true)"

next_version="$(version_compute_next "$ours" "$theirs")"
printf '%s\n' "$next_version" > "$ours_file"

echo "git-version: merge .version -> ${next_version}" >&2
exit 0
