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
blocked=0
for skill_md in "$REPO_DIR"/skills/*/SKILL.md; do
  [[ -e "$skill_md" ]] || continue
  skill_dir="$(dirname "$skill_md")"
  name="$(basename "$skill_dir")"

  # A real directory already at the target is someone's own copy of the skill.
  # `ln -sfn` would quietly create the link *inside* it rather than replacing it,
  # so refuse and let them decide which copy wins.
  if [[ -d "$TARGET/$name" && ! -L "$TARGET/$name" ]]; then
    echo "skipped $name -- $TARGET/$name is a real directory, not a symlink." >&2
    echo "        Move or delete it first, then re-run:  rm -rf '$TARGET/$name'" >&2
    blocked=$((blocked + 1))
    continue
  fi

  ln -sfn "$skill_dir" "$TARGET/$name"
  echo "linked $name -> $TARGET/$name"
  count=$((count + 1))
done

if [[ "$count" -eq 0 ]]; then
  echo "warning: no skills installed from $REPO_DIR/skills" >&2
  exit 1
fi

echo "Done: $count skill(s) installed to $TARGET. Restart Claude Code, then use /skills."
[[ "$blocked" -gt 0 ]] && echo "Note: $blocked skill(s) skipped -- see the messages above." >&2
exit 0
