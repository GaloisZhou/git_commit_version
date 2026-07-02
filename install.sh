#!/usr/bin/env bash
set -euo pipefail

MARKER="# installed-by: git-commit-version"
LEGACY_MARKER="# installed-by: git-version-pre-push"

ROOT="$(git rev-parse --show-toplevel)"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="${ROOT}/.git/hooks"
GIT_VERSION_DIR="${ROOT}/.git/git-version"
TARGET_HOOK="${HOOKS_DIR}/pre-push"
USER_HOOK="${HOOKS_DIR}/pre-push.user"
PUSH_WRAPPER="${GIT_VERSION_DIR}/bin/git-push-with-version.sh"
GGPUSH_WRAPPER="${GIT_VERSION_DIR}/bin/ggpush-with-version.sh"

install -d "$HOOKS_DIR" "${GIT_VERSION_DIR}/bin" "${GIT_VERSION_DIR}/lib"
cp "${SRC_DIR}/bin/git-push-with-version.sh" "${PUSH_WRAPPER}"
cp "${SRC_DIR}/lib/version.sh" "${GIT_VERSION_DIR}/lib/"
cp "${SRC_DIR}/lib/push_prepare.sh" "${GIT_VERSION_DIR}/lib/"
chmod +x "${PUSH_WRAPPER}" "${GIT_VERSION_DIR}/lib/"*.sh

# oh-my-zsh ggpush compatibility
cat > "${GGPUSH_WRAPPER}" <<'GGEOF'
#!/usr/bin/env bash
set -euo pipefail
branch="$(git rev-parse --abbrev-ref HEAD)"
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-push-with-version.sh" origin "${branch}"
GGEOF
chmod +x "${GGPUSH_WRAPPER}"

is_our_wrapper() {
  [ -f "$1" ] && { grep -qF "$MARKER" "$1" || grep -qF "$LEGACY_MARKER" "$1"; } 2>/dev/null
}

write_wrapper() {
  cat > "${TARGET_HOOK}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
${MARKER}

HOOKS_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
USER_HOOK="\${HOOKS_DIR}/pre-push.user"

remote="\${1:?missing remote name}"
url="\${2:-}"

stdin_file="\$(mktemp "\${TMPDIR:-/tmp}/git-pre-push.XXXXXX")"
trap 'rm -f "\${stdin_file}"' EXIT
cat > "\${stdin_file}"

if [ -x "\${USER_HOOK}" ]; then
  cat "\${stdin_file}" | "\${USER_HOOK}" "\${remote}" "\${url}" || exit \$?
fi

exit 0
EOF
}

if [ -f "${TARGET_HOOK}" ]; then
  if is_our_wrapper "${TARGET_HOOK}"; then
    echo "Existing git-commit-version wrapper found, updating..."
  else
    backup="${TARGET_HOOK}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "${TARGET_HOOK}" "${backup}"
    mv "${TARGET_HOOK}" "${USER_HOOK}"
    chmod +x "${USER_HOOK}"
    echo "Existing pre-push hook preserved -> ${USER_HOOK}"
    echo "Backup -> ${backup}"
  fi
else
  echo "No pre-push hook found, creating wrapper..."
fi

write_wrapper
chmod +x "${TARGET_HOOK}"

# Built-in git push ignores alias.push on Git 2.x; use pushv / ggpushv
git config --local --unset alias.push 2>/dev/null || true
git config --local alias.pushv "!bash -c 'exec \"${PUSH_WRAPPER}\" \"\$@\"' bash"
git config --local alias.ggpushv "!bash -c 'exec \"${GGPUSH_WRAPPER}\"' bash"

echo ""
echo "Installed. Use these commands to push (not plain git push):"
echo "  git pushv              # like git push, maintains .version"
echo "  git ggpushv            # like git push origin \$(current branch)"
echo ""
echo "Wrapper: ${PUSH_WRAPPER}"
echo "pre-push: ${TARGET_HOOK} (user hook only)"
if [ -x "${USER_HOOK}" ]; then
  echo "User pre-push hook: ${USER_HOOK}"
  if grep -q 'grep -v \${' "${USER_HOOK}" 2>/dev/null; then
    echo ""
    echo "Note: pre-push.user may print grep usage when the repo has no tags; safe to ignore."
  fi
fi
echo ""
echo "For oh-my-zsh, update ~/.zshrc:"
echo "  alias ggpush='git pushv origin \$(git_current_branch)'"
echo ""
echo "Or: alias ggpush='git ggpushv'"
echo ""
echo "Verify: GIT_VERSION_DEBUG=1 git pushv"
echo ""
echo "Optional — plain \`git push\` / GUI clients: run ${SRC_DIR}/install-shim.sh"
