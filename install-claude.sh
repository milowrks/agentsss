#!/usr/bin/env bash
# install-claude.sh — install agentsss skills into Claude Code personal skills.
#
# Usage:
#   ./install-claude.sh                 # from inside the agentsss repo
#   ./install-claude.sh /path/to/agentsss
#
# Symlinks are used so `git pull` in the clone keeps Claude Code in sync.
set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
TARGET="$HOME/.claude/skills"

if [[ ! -d "$REPO_DIR/skills" ]]; then
  echo "error: no skills/ directory found in $REPO_DIR" >&2
  echo "usage: ./install-claude.sh [path-to-agentsss-clone]" >&2
  exit 1
fi

mkdir -p "$TARGET"

count=0
for skill_md in "$REPO_DIR"/skills/*/SKILL.md; do
  [[ -e "$skill_md" ]] || continue
  skill_dir="$(dirname "$skill_md")"
  name="$(basename "$skill_dir")"
  ln -sfn "$skill_dir" "$TARGET/$name"
  echo "linked $name -> $TARGET/$name"
  count=$((count + 1))
done

if [[ "$count" -eq 0 ]]; then
  echo "warning: no skills found under $REPO_DIR/skills" >&2
  exit 1
fi

echo "Done: $count skill(s) installed to $TARGET. Restart Claude Code, then use /skills."
