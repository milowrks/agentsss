# Sanity Studio in a QA run

Studio markup and wording change between versions. Treat every locator here as
a starting point, and confirm it against the accessibility outline from a first
run (`.qa/debug/*.aria.yml`) or the MCP browser.

## Signing in

- The human signs in through the Studio's own login screen in the window
  `qa.signIn` opens. They pick the provider; you never type into it.
- Google sign-in often refuses automated browsers ("This browser or app may not
  be secure"). If it does, the human uses the Sanity email login or GitHub
  instead. A client that enforces company single sign-on may only offer that
  provider, which usually works.
- `ready` should be something only a signed-in editor sees, such as the
  structure pane's document list or the Create button. The login screen must
  not match it.

## Block writes to anything but the expected dataset

Confirm the dataset from the requests, as `browser-qa-verification` says. Also
make the script refuse writes elsewhere, so a misconfigured Studio can't touch
production. Register this straight after `qa.signIn` returns:

```ts
const dataset = 'staging';
await studio.route(/\.api\.sanity\.io\/v[^/]+\/data\/(mutate|actions)\//, (route) => {
  const target = new URL(route.request().url()).pathname.split('/')[4];
  return target === dataset ? route.continue() : route.abort();
});
```

An aborted write fails the step that made it, which is the right outcome. Say
so in the report.

## Fixtures

- Create documents only for the run, titled `QA <ticket> <time>`, so parallel
  runs and old leftovers can't be mistaken for them.
- Prefer a fixture nothing else references. Studio won't delete a referenced
  document, so if a fixture must be referenced (a page in a menu, say), remove
  the reference first and delete in reverse order of creation.

## Editing and publishing

- Studio saves edits as a draft, in batches, shortly after typing stops.
  Publishing straight after typing can publish without the last edit. Wait for
  the document's status to show the save landed, and for the Publish button to
  be enabled, before clicking it.
- After publishing, wait for the published status before moving to the site.
- A step that edits is one plan step. Its region is the document pane or the
  field group that changed, not the whole Studio.

## Checking the site

- The public site shows published content only, after it revalidates (a webhook
  or a time-based cache). Use `expect(...).toPass` with a reload inside and a
  timeout of a minute or two.
- If it still hasn't updated after that, revalidation itself may be the
  finding, or it may not be set up on this environment. Report it as such
  rather than raising the timeout until it passes.
- Draft mode or the Presentation tool shows drafts immediately. That is a
  different surface; test it only if the ticket is about previews.

## Cleanup and its proof

- Delete each fixture from the document's menu and confirm the dialog. Then
  check the store, not the document list. A query for the id must return
  nothing for the published id, its `drafts.` id, and any release version.
  Use Vision if the Studio has it.
- Capture the empty query result as the cleanup step's evidence region.
