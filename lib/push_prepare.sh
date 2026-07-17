#!/usr/bin/env bash
# Before push: fetch / rebase / update .version / amend
# Must run before push negotiation (amending inside pre-push leaves stale push SHAs)

LIB_DIR="${GIT_VERSION_HOOK_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=version.sh
source "${LIB_DIR}/version.sh"

rebase_has_version_conflict() {
  git diff --name-only --diff-filter=U 2>/dev/null | grep -qx '.version'
}

resolve_version_rebase_conflict() {
  local upstream theirs
  upstream="$(git show :2:.version 2>/dev/null | tr -d '[:space:]' || true)"
  theirs="$(git show :3:.version 2>/dev/null | tr -d '[:space:]' || true)"
  local next_version
  next_version="$(version_compute_next "$upstream" "$theirs")"
  echo "$next_version" > .version
  git add .version
  GIT_EDITOR=true git rebase --continue
}

integrate_remote_branch() {
  local remote="$1"
  local branch="$2"

  # First push of a new branch: remote ref does not exist yet — skip fetch/rebase
  if ! git ls-remote --exit-code --heads "$remote" "refs/heads/${branch}" >/dev/null 2>&1; then
    echo "git-version: remote '${remote}/${branch}' does not exist yet; skipping fetch/rebase"
    return 0
  fi

  git fetch "$remote" "$branch"

  local remote_sha local_sha
  if ! remote_sha="$(git rev-parse "refs/remotes/${remote}/${branch}" 2>/dev/null)"; then
    return 0
  fi

  local_sha="$(git rev-parse HEAD)"

  if [ "$local_sha" = "$remote_sha" ]; then
    return 0
  fi

  # Re-read remote after fetch: stale local tracking refs must not skip rebase
  if git merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null; then
    return 0
  fi

  if git rebase "${remote}/${branch}"; then
    return 0
  fi

  while [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; do
    if rebase_has_version_conflict; then
      resolve_version_rebase_conflict
    else
      echo "git-version: rebase conflict (non-.version files); resolve manually before push" >&2
      return 1
    fi
  done
}

update_version_in_last_commit() {
  local branch="$1"
  local remote="$2"

  local head_version remote_version file_version
  head_version="$(version_read_from_ref HEAD)"
  remote_version="$(version_read_from_ref "${remote}/${branch}" 2>/dev/null || true)"
  file_version="$(version_read_from_file || true)"

  local next_version
  next_version="$(version_compute_next "$head_version" "$remote_version" "$file_version")"

  echo "$next_version" > .version
  git add .version
  git commit --amend --no-edit --no-verify

  echo "git-version: .version -> ${next_version}"
}

# Parse git push args; sets _GP_REMOTE and _GP_BRANCH on success
push_prepare_parse_args() {
  _GP_REMOTE=""
  _GP_BRANCH=""

  local positional=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --all|--tags|--mirror|-d|--delete)
        return 1
        ;;
      -*) shift ;;
      *) positional+=("$1"); shift ;;
    esac
  done

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"

  if [ "${#positional[@]}" -eq 0 ]; then
    local upstream
    if upstream="$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null)"; then
      _GP_REMOTE="${upstream%%/*}"
      _GP_BRANCH="${upstream#*/}"
    else
      local remote merge_ref
      remote="$(git config "branch.${current_branch}.remote" 2>/dev/null || true)"
      merge_ref="$(git config "branch.${current_branch}.merge" 2>/dev/null || true)"
      if [ -z "$remote" ] || [ -z "$merge_ref" ]; then
        return 1
      fi
      _GP_REMOTE="$remote"
      _GP_BRANCH="${merge_ref#refs/heads/}"
    fi
  elif [ "${#positional[@]}" -eq 1 ]; then
    _GP_REMOTE="${positional[0]}"
    _GP_BRANCH="$current_branch"
  else
    _GP_REMOTE="${positional[0]}"
    local refspec="${positional[1]}"
    local local_part="${refspec%%:*}"
    local remote_part="${refspec#*:}"

    if [[ "$refspec" == *:* ]]; then
      if [ "$local_part" = "HEAD" ] || [ "$local_part" = "$current_branch" ] || [ "$local_part" = "refs/heads/${current_branch}" ]; then
        _GP_BRANCH="${remote_part#refs/heads/}"
      else
        return 1
      fi
    else
      if [ "$refspec" = "HEAD" ] || [ "$refspec" = "$current_branch" ] || [ "$refspec" = "refs/heads/${current_branch}" ]; then
        _GP_BRANCH="$current_branch"
      else
        return 1
      fi
    fi
  fi

  if [ "$_GP_BRANCH" != "$current_branch" ]; then
    return 1
  fi

  return 0
}

is_local_ahead_of_remote() {
  local remote="$1"
  local branch="$2"
  local local_sha remote_sha

  local_sha="$(git rev-parse HEAD)"
  if ! remote_sha="$(git rev-parse "refs/remotes/${remote}/${branch}" 2>/dev/null)"; then
    return 0
  fi

  if [ "$local_sha" = "$remote_sha" ]; then
    return 1
  fi

  git merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null
}

push_prepare_for_args() {
  GIT_VERSION_PRE_AMEND_HEAD=""

  if ! push_prepare_parse_args "$@"; then
    # --delete / --tags / etc.: skip quietly (not an error)
    if [[ " $* " == *" --delete "* ]] || [[ " $* " == *" -d "* ]]; then
      return 0
    fi
    echo "git-version: skipping version update (unrecognized push target; use git pushv or git pushv origin <branch>)" >&2
    return 0
  fi

  integrate_remote_branch "$_GP_REMOTE" "$_GP_BRANCH"

  if ! is_local_ahead_of_remote "$_GP_REMOTE" "$_GP_BRANCH"; then
    echo "git-version: no unpushed commits, skipping .version update"
    return 0
  fi

  GIT_VERSION_PRE_AMEND_HEAD="$(git rev-parse HEAD)"
  update_version_in_last_commit "$_GP_BRANCH" "$_GP_REMOTE"
}
