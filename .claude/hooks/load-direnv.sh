#!/usr/bin/env bash
set -euo pipefail

if ! command -v direnv &>/dev/null; then
  echo "direnv not found in PATH" >&2
  exit 1
fi

# Allow the .envrc so direnv doesn't block on approval
direnv allow "$CLAUDE_PROJECT_DIR" 2>/dev/null || true

# Evaluate direnv for the project directory
eval "$(direnv export zsh 2>/dev/null)"

# Persist environment variables for all subsequent Bash calls in this session
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  export -p | sed 's/^declare -x /export /' >>"$CLAUDE_ENV_FILE"
fi

exit 0
