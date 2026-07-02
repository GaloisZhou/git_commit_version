#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIM_HOME="${GIT_COMMIT_VERSION_SHIM_HOME:-${HOME}/.git-commit-version}"
SHIM_BIN="${SHIM_HOME}/bin"
SHIM_GIT="${SHIM_BIN}/git"
REAL_GIT_FILE="${SHIM_HOME}/real-git-path"

mkdir -p "$SHIM_BIN"

if [ -f "$REAL_GIT_FILE" ]; then
  real_git="$(tr -d '[:space:]' < "$REAL_GIT_FILE")"
else
  real_git="$(command -v git)"
  if [ -z "$real_git" ]; then
    echo "git-commit-version: git not found in PATH" >&2
    exit 1
  fi
  # Resolve if real_git is already a previous shim
  if [ "$(basename "$real_git")" = "git" ] && [ -L "$real_git" ] && [ -f "${SHIM_HOME}/real-git-path" ]; then
    real_git="$(tr -d '[:space:]' < "$REAL_GIT_FILE")"
  fi
  printf '%s\n' "$real_git" > "$REAL_GIT_FILE"
fi

if [ ! -x "$real_git" ]; then
  echo "git-commit-version: real git not executable: ${real_git}" >&2
  exit 1
fi

cp "${SRC_DIR}/bin/git-shim" "$SHIM_GIT"
chmod +x "$SHIM_GIT"

echo "Installed git shim -> ${SHIM_GIT}"
echo "Real git saved -> ${real_git}"
echo ""
echo "Add to ~/.zshrc or ~/.bashrc (before other PATH entries):"
echo "  export PATH=\"${SHIM_BIN}:\$PATH\""
echo ""
echo "Or set your Git GUI client \"Git executable\" to:"
echo "  ${SHIM_GIT}"
echo ""
echo "Then plain \`git push\` uses the wrapper in repos where install.sh was run."
echo "Other repos are unaffected (shim falls back to real git)."
