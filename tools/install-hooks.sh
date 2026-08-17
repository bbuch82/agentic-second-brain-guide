#!/usr/bin/env bash
# Enables this repository's publication checks as git hooks.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
chmod +x .githooks/pre-commit tools/privacy-check.sh tools/install-hooks.sh
git config core.hooksPath .githooks

echo "Hooks enabled: core.hooksPath = .githooks"
echo
DENYLIST="${ASBG_DENYLIST:-$HOME/.config/asbg/denylist.txt}"
if [[ -r "$DENYLIST" ]]; then
  echo "Denylist found: $DENYLIST"
else
  echo "Denylist MISSING: $DENYLIST"
  echo "Commits will be blocked until it exists. Start from tools/denylist.example.txt:"
  echo "  mkdir -p \"\$(dirname \"$DENYLIST\")\" && cp tools/denylist.example.txt \"$DENYLIST\""
fi
