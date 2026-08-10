#!/usr/bin/env bash
# List every changed file in a PR as TSV: path, changeType, additions, deletions, viewedState.
# Paginates past the 100-file limit that `gh pr view --json files` and the REST files
# endpoint quietly truncate at.
#
# Usage: pr-files.sh [--repo owner/name] [--pr 123]
#        Both default to the PR for the current branch in the current repo.
#
# Requires: bash 3.2+, an authenticated `gh`, and `jq` on PATH.
set -euo pipefail

for dep in gh jq; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "pr-files.sh: needs '$dep' on PATH -- see the skill's 'Doing this without the scripts' section for the raw GraphQL" >&2
    exit 127
  }
done

repo=""
pr=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="${2:-}"; shift 2 ;;
    --pr)   pr="${2:-}";   shift 2 ;;
    -h|--help)
      awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
      exit 0 ;;
    *) echo "pr-files.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

[[ -n "$repo" ]] || repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
[[ -n "$pr" ]]   || pr=$(gh pr view --json number -q .number)

owner="${repo%%/*}"
name="${repo##*/}"

read -r -d '' query <<'GQL' || true
query($o:String!, $n:String!, $p:Int!, $c:String) {
  repository(owner: $o, name: $n) {
    pullRequest(number: $p) {
      files(first: 100, after: $c) {
        pageInfo { hasNextPage endCursor }
        nodes { path changeType additions deletions viewerViewedState }
      }
    }
  }
}
GQL

cursor=""
while :; do
  args=(-f query="$query" -F o="$owner" -F n="$name" -F p="$pr")
  # Omit $c entirely on the first page so GraphQL sees null, not "".
  [[ -n "$cursor" ]] && args+=(-F c="$cursor")

  resp=$(gh api graphql "${args[@]}")

  echo "$resp" | jq -r '
    .data.repository.pullRequest.files.nodes[]
    | [.path, .changeType, .additions, .deletions, .viewerViewedState]
    | @tsv'

  [[ $(echo "$resp" | jq -r '.data.repository.pullRequest.files.pageInfo.hasNextPage') == "true" ]] || break
  cursor=$(echo "$resp" | jq -r '.data.repository.pullRequest.files.pageInfo.endCursor')
done
