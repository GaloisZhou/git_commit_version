#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "git-version: not inside a git repository" >&2
  exit 1
}

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GIT_VERSION_HOOK_LIB="${SRC_DIR}/lib"

# shellcheck source=../lib/push_prepare.sh
source "${SRC_DIR}/lib/push_prepare.sh"

cd "$ROOT"

if [ "${GIT_VERSION_DEBUG:-}" = "1" ]; then
  echo "git-version: wrapper ran, push args=$*" >&2
fi

push_prepare_for_args "$@"

pre_amend_head="${GIT_VERSION_PRE_AMEND_HEAD:-}"

set +e
git -c 'alias.push=' push "$@"
push_exit=$?
set -e

if [ "$push_exit" -ne 0 ] && [ -n "$pre_amend_head" ]; then
  current_head="$(git rev-parse HEAD)"
  if [ "$current_head" != "$pre_amend_head" ]; then
    git reset --hard "$pre_amend_head"
    echo "git-version: push failed, restored pre-amend commit ($(git rev-parse --short "$pre_amend_head"))" >&2
  fi
fi

exit "$push_exit"
