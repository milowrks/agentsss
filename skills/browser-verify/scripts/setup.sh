#!/bin/sh
# Prepare a ticket folder for a cross-browser QA run.
#
#   setup.sh "<vault>/Tests/<YYYY-MM-DD>-<TICKET>-<Short-description>"
#
# Installs Playwright once into a shared folder outside the vault (it may be
# synced, and node_modules would sync with it), then gives the ticket
# folder a hidden .qa/ with the harness and a node_modules link to that install.
# Re-running refreshes the harness files and leaves plan.spec.ts alone.
set -eu

ticket=${1:?usage: setup.sh "<ticket folder>"}
skill_dir=$(cd "$(dirname "$0")/.." && pwd)
harness="$skill_dir/harness"
version=$(node -p "require('$harness/package.json').devDependencies['@playwright/test']")
shared="${XDG_CACHE_HOME:-$HOME/.cache}/browser-verify/$version"

if [ ! -d "$shared/node_modules/@playwright/test" ]; then
  mkdir -p "$shared"
  cp "$harness/package.json" "$shared/package.json"
  (cd "$shared" && pnpm install --silent)
fi
# No-op for browsers already downloaded for this version.
(cd "$shared" && pnpm exec playwright install chromium webkit firefox)

mkdir -p "$ticket/.qa" "$ticket/Plans" "$ticket/Results"
for f in playwright.config.ts qa.ts report.mjs; do
  cp "$harness/$f" "$ticket/.qa/$f"
done
[ -e "$ticket/.qa/plan.spec.ts" ] || cp "$harness/plan.spec.ts" "$ticket/.qa/plan.spec.ts"
ln -sfn "$shared/node_modules" "$ticket/.qa/node_modules"

printf 'Ready: %s/.qa (Playwright %s)\n' "$ticket" "$version"
printf 'Run:   "%s/.qa/node_modules/.bin/playwright" test --config "%s/.qa/playwright.config.ts"\n' "$ticket" "$ticket"
