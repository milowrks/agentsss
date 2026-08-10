#!/usr/bin/env bash
# install-claude.sh — thin wrapper kept so older instructions keep working.
# Equivalent to: ./install.sh --target "$HOME/.claude/skills"
#
# Prefer install.sh directly; it takes --target and works for any harness.
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
echo "note: install-claude.sh now delegates to install.sh --target \"\$HOME/.claude/skills\"" >&2
exec "$dir/install.sh" --target "$HOME/.claude/skills" "$@"
