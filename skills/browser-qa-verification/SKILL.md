---
name: browser-qa-verification
description: >-
  Use when verifying a code change in a real browser — against a deployed
  environment (staging or preview), or a locally-run app or CMS Studio — not
  just unit tests. Drives Playwright to execute a written test plan or
  smoke-test the surfaces the change touches, handles Vercel Deployment
  Protection with a temporary bypass secret, hands off interactions it cannot
  drive reliably, verifies results against the data store rather than the UI,
  captures screenshot and payload evidence, and reports against the plan.
  Triggers on "browser QA", "verify in browser", "run the test plan against
  staging/preview", "check it works on the deployment", "verify in the Studio",
  "run the manual test steps".
license: MIT
compatibility: claude-code, any harness with a Playwright MCP server
requires: a Playwright MCP server; Node and a signed-in Vercel CLI when the target sits behind Vercel Deployment Protection
metadata:
  author: Milo Z.
  version: "1.5.0"
  status: stable
---

# Browser QA verification

Drive a real browser against a deployed environment, or a locally-run app or CMS
Studio, to confirm a change behaves correctly, and capture the evidence. Posting
it to the tracker is the `evidence-test-plan` skill's job.

Project-specific details (deployment URLs, project/team slugs, auth provider,
credential locations, tracker IDs) belong in the repo's `CLAUDE.md`, not here.
This skill is the reusable flow.

```
TEST ONLY WHAT THE CHANGE TOUCHES. A DEPENDENCY/REFACTOR PASS IS A REGRESSION CHECK:
PAGES RENDER, JOURNEYS WORK, NO NEW REAL CONSOLE ERRORS — BEHAVIOUR UNCHANGED.
```

## Autonomy (run once, not per-tool)

Driving a browser means dozens of `navigate` / `snapshot` / `click` calls, and
approving each one defeats the flow. Pre-allow the driving tools for
your Playwright MCP server in the user-level settings (`~/.claude/settings.json`
for Claude Code) so they apply in every repo. If a run keeps prompting, add the
missing tool there by name,
never the whole server, so a future tool is never auto-approved by accident.

**Deliberately NOT allowed: `browser_run_code_unsafe`.** It runs arbitrary JS in
the page. The happy path (Vercel bypass via query string, step 3) never needs
it, so it stays a rarely-used, always-prompting escape hatch.

## Principles

- **Scope to the diff.** Derive test surfaces from the changed packages/files.
  Don't smoke the whole app for a change that touches two packages. Ignore
  dev/build/test tooling — it doesn't ship to a runtime.
- **Execute the test plan, not the acceptance criteria.** If the ticket carries a
  numbered test plan, that is the procedure to run and to report against. The ACs
  are the contract; the plan is the method. Reporting against the wrong one can
  invent gaps that don't exist — a step from some other document read as an
  outstanding requirement.
- **Verify in the store, not the form.** A UI can show partially-rendered state,
  or a draft where you assumed published, and both look exactly like a defect.
  Confirm what persisted by querying the datastore — an in-app query console or
  the HTTP API — before asserting anything about it.
- **Fixtures have to make the assertion possible.** Two items cannot prove order
  is preserved: any two-element sequence matches some sort. Use three, matching
  neither ascending nor descending on any plausible key. Likewise give per-item
  settings distinguishable values, or the test passes on a default.
- **The human approves every tracker write.** Drafting, capturing and uploading
  are yours; posting, editing and deleting on the ticket are theirs to approve,
  every time — not once at the start of the run.
- **Evidence is what the picture shows, not what the file is called.** Open each
  image and caption it from its contents. An unverified caption launders a bad
  screenshot into a claim.
- **Hand off what you cannot drive.** Some interactions can't be faked reliably
  (see step 3). Ask the human rather than attempting it silently — a check that
  reports success without exercising the mechanism is worse than a skipped one.
- **Your own fixtures for destructive checks.** Anything that deletes, unpublishes
  or overwrites gets tested against records you created, so you can click through
  a confirmation without risking someone else's data.
- **Separate real errors from environmental noise.** On staging/preview the
  console is full of non-defects: analytics cookie-domain rejections (`_ga`,
  `_hj*`), third-party CORS, `favicon.ico` 404s, dev-deprecation warnings. Only
  app-origin errors and broken renders count as failures.
- **Minted secrets are temporary.** Any bypass secret you create: verify → use →
  **revoke**. Never modify or remove secrets you didn't create.
- **Leave no trace, and check it.** Everything you started or minted, you stop or
  revoke — processes included, not just files. Step 6 is the checklist; run it as
  the last act of the run, not "later".
- **Don't run dev servers yourself** if the project forbids it. Test against a
  deployment, or ask the human to start the server, then drive it.

## Flow

### 1. Scope the run

From the change, list the runtime-reachable surfaces and map each changed
package to the pages/journeys that exercise it. Write the checklist before
touching a browser. Prefer a checklist already agreed with the team (e.g. a QA
comment on the ticket) — and if the ticket has a numbered test plan, that *is*
the checklist; work through it in order rather than composing your own.

### 2. Reach the environment

- **Public URL** → just navigate.
- **Vercel Deployment Protection** (navigation 302s to `vercel.com/sso-api` or
  `vercel.com/login`) → mint a temporary Protection Bypass for Automation secret
  with `scripts/vercel-bypass.mjs` (usage in its header). In short:
  1. `vercel whoami` first — the CLI token in the vercel-cli `auth.json` expires;
     this refreshes it. A raw API call with a stale token returns
     `403 invalidToken`.
  2. `node scripts/vercel-bypass.mjs create <project> <team-slug>` → writes the
     secret to a file and prints only counts/notes, never the value. It **adds**
     a secret; existing ones are preserved.
  3. Verify with curl before driving the browser — allow a few seconds for
     propagation, a just-created secret can still 302:
     `curl -s -o /dev/null -w "%{http_code}\n" "<url>?x-vercel-protection-bypass=$(cat <file>)"` → expect `200`.
  4. Reach the deployment by navigating with the bypass query params (step 3),
     then **revoke** when done:
     `node scripts/vercel-bypass.mjs revoke <project> <team-slug>`.
- **Auth-gated (OAuth / SSO / next-auth)** → open the login page and **hand the
  sign-in to the human**, as for a local app below; don't read credentials
  yourself. The profile persists, so it's a one-time cost. If a per-branch
  preview URL isn't in the auth provider's allowed callback list (common →
  `redirect_mismatch`), fall back to a local run with a populated `.env.local`.
- **Local app or CMS Studio** → confirm which environment the process will talk
  to *before* opening it (below), start the server, then navigate. A fresh
  Playwright profile is logged out and the app's own login will block you: open
  the login page, **hand the credentials step to the human**, and take over once
  they're through. Never ask for or handle credentials. The MCP browser profile
  persists across dev-server restarts, so this handoff is normally once per
  session, not once per run.

**Confirm the target from its API calls, not its config.** An env file, a window
title and an in-app environment selector can all agree and still not be proof.
Read the actual request URLs (`browser_network_requests`, or the console) and
check the environment/dataset segment on the *mutation* endpoints — that is the
API recording where a write went, rather than configuration you're interpreting.
Where the target shares a datastore family with production, finish with a
negative check: query production and any other sibling environment for your
test-data ids and confirm zero rows.

### 3. Drive the browser (Playwright MCP)

For a Vercel-protected deployment, pass the bypass secret in the **URL query
string** on the first navigation — Vercel accepts `x-vercel-protection-bypass`
as a query parameter as well as a header, so no request-header injection (and no
`browser_run_code_unsafe`) is needed:

```
browser_navigate → https://<host>/?x-vercel-protection-bypass=<secret>&x-vercel-set-bypass-cookie=true
```

`x-vercel-set-bypass-cookie=true` makes Vercel set the bypass as a cookie (via a
`Set-Cookie` redirect), so every follow-up request in the session is already
authorized. After the first navigation, navigate to **clean URLs** (no secret)
for the rest of the run — the cookie carries the session, and screenshots won't
show the secret in the address bar. The secret still appears once in the
transcript (that first nav URL), which is why it is throwaway and revoked.

Use `browser_run_code_unsafe` (`page.context().setExtraHTTPHeaders(...)`) only as
a fallback for a non-Vercel gate that genuinely needs a request header. It runs
arbitrary JS in the page — its VM is ESM with no `require`/`import`/`fs`, and the
MCP echoes the code — so it is intentionally left out of the autonomy allowlist
and prompts each time. The query-string path above avoids it entirely.

Per checklist item: `browser_navigate` → `browser_snapshot` (accessibility tree,
better than a screenshot for asserting structure) → interact (`browser_click` /
`browser_type`) → assert with `browser_evaluate` (e.g. result count, every row
matches the filter, image `naturalWidth > 0`) → check `browser_console_messages`
(level `error`). Capture API status + payloads with `browser_network_requests`
or a `fetch` inside `browser_evaluate`.

**Interactions you cannot drive reliably.** Synthetic drag-and-drop against
modern DnD libraries (dnd-kit, react-beautiful-dnd) often reports success while
nothing moved — the worst failure mode, because it reads as a pass. Tell the
human what to drag and to what target order, in the browser already open, then
verify the *result* in the store. The accessibility live region usually announces
the outcome ("Draggable item X was dropped over droppable area Y") — evidence the
gesture happened.

**Debounced writes.** Editors that autosave batch their patches, so publishing or
asserting immediately after a change can drop it silently — a race with your own
tooling that looks like a defect. Wait for the write to settle (the saved/edited
indicator, or `browser_wait_for`).

### 4. Capture evidence (representative, not exhaustive)

- **Screenshots**: `browser_take_screenshot`. The file lands relative to the
  Playwright server's working directory (the folder the session started in:
  a shared parent folder, the repo, or the worktree root), **not** the `.playwright-mcp/`
  path the tool result implies — `ls` it before citing it, or you will report a
  screenshot that isn't there. Move it into the evidence folder rather than citing
  it in place.
- **Payloads**: capture API JSON inline as evidence. A store query showing the
  persisted result is stronger than a screenshot of the UI that wrote it.
- **Naming**: name each artefact for the test plan step it evidences
  (`step1-…`, `step5-…`), and keep a single scheme across the folder — a mix of
  step- and AC-named files makes the set unreadable.
- **Capture the evidence, not the page.** A viewport shot of the right URL is
  usually the page header and misses the thing under test. Scroll the asserted
  element into view first, offset for the sticky header, or raise the viewport
  with `browser_resize` so the whole block and its pagination fit in one frame.
  Dismiss cookie banners and survey pop-ups before the shot — they park
  themselves over the exact card you are photographing.
- **Open every image before you caption it.** A filename is a claim, not
  evidence. This applies hardest to captures inherited from an earlier run: a
  confident caption on an image that shows something else is worse than no
  screenshot, because it survives review. Check the picture, not the DOM
  assertion you made at capture time.
- **Placement**: evidence belongs in the user's notes (ask once where), under a dated folder
  with an `evidence/` subdirectory, not committed to the repo.

### 5. Report the result

Lead with the **test plan**: one row per numbered step, its result, and how it
was checked. Add an AC-to-step traceability line if it's useful, but the plan is
the spine of the report.

**Disclose deviations from the plan as written** — more fixtures than specified, a
narrower query than implied, a step you couldn't perform. A justified deviation,
stated, is part of the evidence; an unstated one is a hole in it.

Report it to the human in chat, and save the execution note and screenshots to
the user's notes (a dated `<YYYY-MM-DD ticket title>/` folder, screenshots in
`evidence/`, each named for its step). Posting it to the tracker is the
`evidence-test-plan` skill's job: hand over to it when the human asks for the
evidence to go on the issue or task.

### 6. Tear down (both processes, not one)

The habitual half-finish is killing the dev server and leaving the browser open:
a Playwright window parked on a now-dead `localhost`, sitting on the user's
desktop until they close it themselves. Close the browser **and** stop the
server, every run.

- `browser_close` first, then kill the server — a browser polling a dying server
  just adds noise. The MCP browser profile lives on disk, so the credentials
  handoff from step 2 survives the close; reopening is one `browser_navigate`.
- Stop only servers **you** started. One the human started is theirs — say you're
  done with it and leave it running.
- **Revoke** any bypass secret you minted; never touch ones you didn't.
- Delete the secret file, and the screenshots, snapshots and console logs **this
  run** created — all untracked and *not* gitignored, so they surface in
  `git status`. Never delete the `.playwright-mcp/` folder wholesale: when the
  session started in a shared parent folder, it holds other sessions'
  files too.
- Delete test data you created in a shared datastore, then *verify* it's gone with
  a query that includes drafts and unpublished revisions. Don't assume.
- Then check, don't assert: `git status` clean, nothing still listening on the dev
  port, secret list back to its prior count.

## Gotchas (learned the hard way)

- Vercel CLI auth token expires mid-session → `vercel whoami` to refresh before
  any raw Vercel API call.
- A freshly-minted bypass secret needs a few seconds before it returns `200`.
- Prefer the bypass **query string** over a request header — `browser_navigate`
  reaches it directly. Once the first navigation sets the cookie, drop the secret
  from later URLs so it stays out of screenshots.
- If another session already holds the browser profile ("Browser is already in
  use"), switch to another browser server if your setup has one (e.g. WebKit). Don't close the other session's window.
- Thin fixture data makes working code look broken: a seeded record missing the
  field your query filters on means a correct filter returns nothing. Rule out
  "the fixtures are incomplete" before filing a defect, and flag it downstream.
- A dialog offering "do it anyway" is not proof the action is permitted. Click
  through on your own fixture and read the API response — a backend `409` and a
  blocked button are different findings.
- Distinguish "the changed code executes" from "the page merely loads" — assert
  the behaviour the change affects, not just HTTP 200.
- Never drive the human's own logged-in browser.
  Sign the Playwright profile in through a handoff instead. That profile
  persists, so it is a one-time cost.
- Shared staging content moves between runs. Re-shooting an old screenshot means
  re-running its check too, or the counts in your table will contradict the new
  image.
- Fixtures you delete at teardown are gone from any screenshot you take
  afterwards. If a step's rendered evidence depends on them, capture it before
  cleanup — or say plainly in the caption that the claim rests on the store-level
  check instead.
