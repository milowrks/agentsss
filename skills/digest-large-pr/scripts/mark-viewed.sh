#!/usr/bin/env bash
# Mark (or unmark) PR files as viewed. Viewed state is PER-REVIEWER: it only ever
# changes the file list of the account holding the gh token. Nobody else sees it,
# and GitHub clears it for any file that changes in a later push.
#
# Usage: mark-viewed.sh [--repo owner/name] [--pr 123] [--unmark] [--dry-run] path [path...]
#        mark-viewed.sh [--repo owner/name] [--pr 123] --stdin < paths.txt
#
# Exits non-zero if any path failed, after attempting all of them.
#
# Requires: bash 3.2+ and an authenticated `gh` on PATH.
set -uo pipefail

command -v gh >/dev/null 2>&1 || {
  echo "mark-viewed.sh: needs 'gh' on PATH -- see the skill's 'Doing this without the scripts' section for the raw GraphQL" >&2
  exit 127
}

repo=""
pr=""
mutation="markFileAsViewed"
dry_run=0
read_stdin=0
paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    repo="${2:-}"; shift 2 ;;
    --pr)      pr="${2:-}";   shift 2 ;;
    --unmark)  mutation="unmarkFileAsViewed"; shift ;;
    --dry-run) dry_run=1; shift ;;
    --stdin)   read_stdin=1; shift ;;
    -h|--help)
      awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
      exit 0 ;;
    -*) echo "mark-viewed.sh: unknown argument '$1'" >&2; exit 2 ;;
    *)  paths+=("$1"); shift ;;
  esac
done

if [[ $read_stdin -eq 1 ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && paths+=("$line")
  done
fi

if [[ ${#paths[@]} -eq 0 ]]; then
  echo "mark-viewed.sh: no paths given" >&2
  exit 2
fi

[[ -n "$repo" ]] || repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
[[ -n "$pr" ]]   || pr=$(gh pr view --json number -q .number)

owner="${repo%%/*}"
name="${repo##*/}"

pr_id=$(gh api graphql \
  -f query='query($o:String!, $n:String!, $p:Int!) {
    repository(owner: $o, name: $n) { pullRequest(number: $p) { id } }
  }' \
  -F o="$owner" -F n="$name" -F p="$pr" \
  --jq '.data.repository.pullRequest.id')

if [[ -z "$pr_id" || "$pr_id" == "null" ]]; then
  echo "mark-viewed.sh: could not resolve $repo#$pr" >&2
  exit 1
fi

failed=0
for path in "${paths[@]}"; do
  if [[ $dry_run -eq 1 ]]; then
    echo "DRY-RUN  $mutation  $path"
    continue
  fi

  # Each path is a separate call so one bad path can't silently drop the rest.
  if err=$(gh api graphql \
        -f query="mutation(\$id:ID!, \$path:String!) {
          $mutation(input: {pullRequestId: \$id, path: \$path}) {
            pullRequest { number }
          }
        }" \
        -F id="$pr_id" -F path="$path" 2>&1 >/dev/null); then
    echo "ok       $path"
  else
    echo "FAILED   $path -- $(echo "$err" | tr '\n' ' ' | cut -c1-200)" >&2
    failed=1
  fi
done

exit $failed
