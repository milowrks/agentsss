#!/usr/bin/env bash
# install.sh — install agentsss skills into any Agent Skills-compatible harness.
#
# Usage:
#   ./install.sh                                # -> ~/.claude/skills (default)
#   ./install.sh --target ~/.agents/skills      # any harness's skills directory
#   ./install.sh --target .claude/skills        # project-local install
#   ./install.sh --repo /path/to/agentsss       # run from outside the clone
#   ./install.sh /path/to/agentsss              # legacy positional form
#
# The target can also be set with AGENTSSS_TARGET. Symlinks are used, so a
# `git pull` in the clone keeps every harness in sync without re-installing.
set -euo pipefail

TARGET="${AGENTSSS_TARGET:-$HOME/.claude/skills}"
REPO_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { echo "install.sh: --target needs a directory" >&2; exit 2; }
      TARGET="$2"; shift 2 ;;
    --repo)
      [[ $# -ge 2 ]] || { echo "install.sh: --repo needs a path" >&2; exit 2; }
      REPO_DIR="$2"; shift 2 ;;
    -h|--help)
      awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
      exit 0 ;;
    -*) echo "install.sh: unknown argument '$1'" >&2; exit 2 ;;
    *)  REPO_DIR="$1"; shift ;;
  esac
done

[[ -n "$REPO_DIR" ]] || REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -z "$TARGET" ]]; then
  echo "install.sh: --target needs a directory" >&2
  exit 2
fi

if [[ ! -d "$REPO_DIR/skills" ]]; then
  echo "install.sh: no skills/ directory found in $REPO_DIR" >&2
  echo "usage: ./install.sh [--target DIR] [--repo path-to-agentsss-clone]" >&2
  exit 1
fi

mkdir -p "$TARGET"
# Resolve after mkdir so the printed paths are absolute even for a relative --target.
TARGET="$(cd "$TARGET" && pwd)"

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

echo "Done: $count skill(s) installed to $TARGET."
[[ "$blocked" -gt 0 ]] && echo "Note: $blocked skill(s) skipped -- see the messages above." >&2
exit 0
