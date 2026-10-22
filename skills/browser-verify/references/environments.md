# Reaching the environment

## Find the build and the dataset

- Find which deployment has the change. For Vercel, `vercel inspect <domain>
  --scope <team>` names the deployment behind a domain, and its git ref and
  commit show whether the change is in it.
- Find which CMS dataset that deployment reads, and which Studio writes to it.
  A Studio's title or dataset menu is a hint, not proof (see below).

## Public URL

Just navigate.

## Vercel Deployment Protection

A navigation that redirects to `vercel.com/sso-api` or `vercel.com/login` is
protected. Mint a temporary Protection Bypass for Automation secret with
`scripts/vercel-bypass.mjs` (usage in its header):

1. `vercel whoami` first. The CLI token expires, and this refreshes it. A raw
   API call with a stale token returns `403 invalidToken`.
2. `node scripts/vercel-bypass.mjs baseline <project> <team>` records how many
   secrets exist before you start.
3. `node scripts/vercel-bypass.mjs create <project> <team> "<ticket> QA <date>"`
   adds a secret and writes it to `<os tmpdir>/vbypass-<project>.secret`. It
   prints counts and notes, never the value, and keeps existing secrets.
4. Check it before driving a browser. Allow a few seconds, because a new secret
   can still redirect:
   `curl -s -o /dev/null -w "%{http_code}\n" -H "x-vercel-protection-bypass: $(cat <file>)" <url>`
   should print `200`.
5. A site and its Studio are often separate projects. Mint one per project.
6. At teardown, `revoke` each, then `baseline` again to confirm the count is
   back where it started, and check a request with the old secret redirects.

In the script, read the secret file with `fs` and add
`?x-vercel-protection-bypass=<secret>&x-vercel-set-bypass-cookie=true` to the
first `goto` in each browser context. Vercel then sets a cookie, so later URLs
stay clean and screenshots never show the secret.

In the MCP browser, the same query string on the first `browser_navigate` does
the job. The secret appears once in the transcript, which is why it is throwaway
and revoked. A request-header route through `browser_run_code_unsafe` is the
fallback for a non-Vercel gate that needs a header; it prompts every time.

## Signed-in apps and CMS Studios

- The human signs in, always. Open the login page and hand it over. Never ask
  for, read or type credentials.
- Google sign-in often refuses automated browsers. Offer the app's other
  providers.
- An isolated MCP browser keeps the sign-in only until the browser closes.
- A per-branch preview whose URL isn't in the auth provider's allowed callbacks
  fails with `redirect_mismatch`. Fall back to a local run.

## A local app

Confirm which environment the process will talk to before opening it. Start
the server only if the project allows it, otherwise ask the human to. Stop only
servers you started.

## Confirm the target from the requests, not the config

An env file, a window title and an in-app selector can all agree and still be
wrong. Read the request URLs and check the dataset or environment segment on
the write endpoints. That records where a write actually went.

- In the script, record the write requests and assert they all went to the
  expected dataset. Also refuse writes elsewhere; `references/sanity-studio.md`
  has the route for Sanity.
- Where the target shares a store with production, finish with a negative
  check: query production and any sibling environment for your fixture ids and
  confirm nothing is there.
