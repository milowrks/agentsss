#!/bin/bash
# Read-only inventory of a Claude Code setup: hooks, plugins, memories, rules, skills, leftovers.
# Usage: inventory.sh [repo-root ...]
# Default roots: git repos directly under ~/Developer plus live project folders known to ~/.claude.json.
set -u
C="$HOME/.claude"
CJ="$HOME/.claude.json"
IP="$C/plugins/installed_plugins.json"
roots=("$@")
if [ ${#roots[@]} -eq 0 ]; then
  while IFS= read -r d; do roots+=("$d"); done < <(
    { for d in "$HOME"/Developer/*/; do [ -e "$d.git" ] && echo "${d%/}"; done
      jq -r '.projects // {} | keys[]' "$CJ" 2>/dev/null | grep -v '/\.claude/worktrees/' |
        while IFS= read -r p; do [ -e "$p/.git" ] && echo "$p"; done
    } | sort -u)
fi
enc() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
rel() { printf '%s' "${1#$HOME/}"; }

hooks_of() { # file
  jq -r '.hooks // {} | to_entries[] | .key as $e | .value[] | (.matcher // "*") as $m
    | .hooks[] | "  \($e) [\($m)] \(.type): \((.command // .prompt // "") | gsub("\n"; " ") | .[0:110])"' "$1" 2>/dev/null
}

echo "## Hooks"
echo "### global ~/.claude/settings.json"; hooks_of "$C/settings.json"
for r in "${roots[@]}"; do
  for f in "$r/.claude/settings.json" "$r/.claude/settings.local.json"; do
    [ -f "$f" ] || continue
    h=$(hooks_of "$f"); [ -n "$h" ] || continue
    tracked=$(git -C "$r" ls-files --error-unmatch "${f#$r/}" >/dev/null 2>&1 && echo "committed, team file" || echo "local")
    echo "### $(rel "$f") ($tracked)"; echo "$h"
  done
done

echo; echo "## Permission allow rules naming MCP servers (check each server still exists under that name)"
jq -r '.permissions.allow // [] | .[] | select(startswith("mcp__")) | split("__")[1]' "$C/settings.json" 2>/dev/null | sort | uniq -c | sed 's/^/ /'
echo "  configured local MCP servers: $(jq -r '.mcpServers // {} | keys | join(", ")' "$CJ" 2>/dev/null)"
echo "  (connector servers in the desktop app are named by UUID, not mcp__claude_ai_<Name>)"

echo; echo "## Plugins"
echo "### enabled globally"; jq -r '.enabledPlugins // {} | to_entries[] | "  \(.key): \(.value)"' "$C/settings.json"
for r in "${roots[@]}"; do
  e=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$r/.claude/settings.json" 2>/dev/null)
  [ -n "$e" ] || continue
  echo "### enabled in $(rel "$r")"
  while IFS= read -r k; do
    ok=$(jq -r --arg k "$k" --arg r "$r" '[.plugins[$k] // [] | .[] | select(.scope=="user" or .projectPath==$r)] | length' "$IP" 2>/dev/null)
    [ "${ok:-0}" -gt 0 ] && echo "  $k" || echo "  $k  <- enabled here but not installed for this repo or user"
  done <<< "$e"
done
echo "### installs (version, scope, project paths still on disk / total)"
jq -r '.plugins | to_entries[] | .key as $k | .value | group_by(.version + (.scope // ""))[]
  | "\($k)\t\(.[0].version)\t\(.[0].scope // "-")\t\([.[].projectPath // empty] | join("|"))"' "$IP" 2>/dev/null |
while IFS=$'\t' read -r k v s paths; do
  if [ -n "$paths" ]; then
    total=0; live=0; IFS='|' read -r -a arr <<< "$paths"
    for p in "${arr[@]}"; do total=$((total+1)); [ -d "$p" ] && live=$((live+1)); done
    echo "  $k $v ($s) projects: $live/$total"
  else
    echo "  $k $v ($s)"
  fi
done
echo "### plugin cache (hooks per version; versions with no install record are not loaded)"
for f in "$C"/plugins/cache/*/*/*/; do
  vdir=${f%/}; v=$(basename "$vdir"); pl=$(basename "$(dirname "$vdir")"); mk=$(basename "$(dirname "$(dirname "$vdir")")")
  used=$(jq -r --arg k "$pl@$mk" --arg v "$v" '[.plugins[$k] // [] | .[] | select(.version==$v)] | length' "$IP" 2>/dev/null)
  tag=""; [ "${used:-0}" -eq 0 ] && tag="  (not installed: dead cache, $(du -sh "$vdir" 2>/dev/null | cut -f1))"
  n=$(ls "$vdir"/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
  echo "  $mk/$pl/$v: $n skills$tag"
  [ -f "$vdir/hooks/hooks.json" ] || continue
  jq -r '.hooks // {} | to_entries[] | "    hook \(.key) [\([.value[].matcher // "*"] | join(","))]"' "$vdir/hooks/hooks.json" 2>/dev/null
  jq -e '.modules' "$vdir/hooks/hooks.json" >/dev/null 2>&1 && echo "    hook module: $(jq -c .modules "$vdir/hooks/hooks.json")"
done

echo; echo "## Memories (loaded only when a session starts in that exact folder)"
found=0
for m in "$C"/projects/*/memory; do
  [ -d "$m" ] || continue
  n=$(find "$m" -maxdepth 1 -type f -name '*.md' ! -name MEMORY.md | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] || continue
  found=1; echo "### $(basename "$(dirname "$m")") ($n files)"
  find "$m" -maxdepth 1 -type f -name '*.md' ! -name MEMORY.md -exec stat -f '  %Sm %N' -t %F {} \; | sed "s#$m/##" | sort
done
[ $found -eq 1 ] || echo "  none: skip the memory checks"

echo; echo "## Rules"
show_rules() { # file label
  local f=$1 dir; dir=$(dirname "$f")
  echo "  $(rel "$f") ($(wc -l < "$f" | tr -d ' ') lines$2)"
  grep -oE '^@[^[:space:]]+' "$f" 2>/dev/null | while IFS= read -r imp; do
    t=${imp#@}; t=${t/#\~/$HOME}; case "$t" in /*) ;; *) t="$dir/$t";; esac
    if ls "$(dirname "$t")" 2>/dev/null | grep -qxF "$(basename "$t")"; then echo "    imports $imp (ok)"
    else echo "    imports $imp  <- no file with that exact name (case matters off macOS)"; fi
  done
}
[ -f "$C/CLAUDE.md" ] && { show_rules "$C/CLAUDE.md" ""; grep -n '^## ' "$C/CLAUDE.md" | sed 's/^/    /'; }
for r in "${roots[@]}"; do
  for f in "$r/CLAUDE.md" "$r/AGENTS.md" "$r/.claude/CLAUDE.md"; do
    [ -f "$f" ] && show_rules "$f" ", team file$( [ -L "$f" ] && echo ", symlink to $(readlink "$f")")"
  done
done

echo; echo "## Skills"
echo "### personal ~/.claude/skills"
for d in "$C"/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  printf '  %-28s %5sw  %s\n' "$(basename "$d")" "$(wc -w < "$d/SKILL.md" | tr -d ' ')" "$(stat -f %Sm -t %F "$d/SKILL.md")"
done
for x in "$C"/skills/.*/; do
  b=$(basename "$x"); [ "$b" = . ] || [ "$b" = .. ] && continue
  echo "  extra folder $b/ ($(ls -A "$x" | wc -l | tr -d ' ') items, not loaded)"
done
s=$(find "$C/skills/synced" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
[ "$s" -gt 0 ] && echo "  synced/: $s claude.ai account skills (managed in claude.ai, not here)"
for r in "${roots[@]}"; do
  [ -d "$r/.claude/skills" ] || continue
  echo "### $(rel "$r")/.claude/skills (team file): $(ls "$r/.claude/skills" | tr '\n' ' ')"
done

echo; echo "## Leftovers"
echo "### ~/.claude.json project entries whose folder is gone"
jq -r '.projects // {} | keys[]' "$CJ" 2>/dev/null | while IFS= read -r p; do [ -d "$p" ] || echo "  $(rel "$p")"; done
echo "### transcript folders in ~/.claude/projects with no live folder"
live=$(jq -r '.projects // {} | keys[]' "$CJ" 2>/dev/null | while IFS= read -r p; do [ -d "$p" ] && enc "$p" && echo; done)
for d in "$C"/projects/*/; do
  b=$(basename "$d"); echo "$live" | grep -qxF -- "$b" && continue
  echo "  $(cd "$C/projects" && du -sh "./$b" 2>/dev/null | cut -f1)  $b"
done
echo "### backups"
ls -d "$C"/*.bak "$C"/*.bak.* "$C"/*.bak/ "$HOME"/.claude.json.*.bak 2>/dev/null | sed 's#/$##' | sort -u | sed "s#$HOME/#  ~/#"
true
