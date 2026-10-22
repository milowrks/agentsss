---
name: evidence-test-plan
description: >-
  Use when posting the evidence for a completed test plan run to its tracker
  issue or task (GitHub or ClickUp). Reads the test plan verbatim from the
  tracker and the execution note plus evidence folder from the user's notes,
  uploads the screenshots itself, and posts one comment where every plan item is
  a heading with its evidence under it. Triggers on "post the evidence", "write
  up the test plan evidence", "post test plan execution to the issue",
  "evidence comment".
license: MIT
compatibility: claude-code, any harness with a Playwright MCP server
requires: gh (authenticated) for GitHub, or a ClickUp connector; a Playwright MCP server for GitHub image uploads; sips (macOS) to convert screenshots
metadata:
  author: Milo Z.
  version: "2.0.0"
  status: stable
---

# Test plan evidence comment

Turn a finished test plan run into a comment where every plan item is a heading,
and every artefact sits under a statement of why it passes that item.

Running the tests is `browser-qa-verification`. This skill publishes the result,
and inherits that skill's principle that **the test plan is the spine of the
report, not the acceptance criteria** — quote the plan, don't restate ACs.

```
ONE APPROVED POST. EVERY PLAN ITEM A HEADING, EVERY ARTEFACT UNDER ITS CLAIM.
```

**Get approval before anything reaches the tracker.** Draft the comment, show it,
and wait for an explicit yes. That covers every write: posting, patching a comment
you posted a minute ago, and deleting a superseded one. Check what you are about
to destroy first — a comment may have picked up attachments or replies since.

## 1. Gather

- **The plan, verbatim.** GitHub: `gh issue view <n> --json body`. ClickUp: the
  task description or the test-plan comment. Copy the wording exactly; never
  paraphrase it.
- **The execution note and evidence**: the dated `<YYYY-MM-DD ticket title>/`
  folder in the user's notes (ask once where), with attachments in its
  `evidence/` subfolder. A run from `cross-browser-ticket-qa` lives instead in
  `Tests/<YYYY-MM-DD>-<TICKET>-<Short-description>/` in the Obsidian vault: the
  plan in `Plans/`, the run note and screenshots together in `Results/`. Each
  file is named for the procedure step it shows (`step1-…`). If the notes sit
  outside the sandbox, reading them needs it disabled.
- Look at each artefact before writing about it. A filename is not evidence of
  what an image contains.

## 2. Map artefacts to plan items

Group the evidence files per plan item and **reconcile the count**: every file
lands under exactly one item, and every item has at least one file. A leftover is
a signal, not a rounding error: a mislabelled artefact usually shows up as one
file too many under one item and an item with none.

## 3. Upload the screenshots

Convert to JPEG and downsize first: `sips -s format jpeg -s formatOptions 70 -Z 2000 in.png --out out.jpg`
(side-by-sides at 2000px stay legible). Work on copies in the scratchpad, never
the originals.

**GitHub** has no REST API for comment attachments, but the comment box's file
chooser does the job, driven through Playwright. It's the only cheap path: GitHub's
CSP blocks a local file server, and injecting base64 through `browser_evaluate`
costs tens of thousands of tokens per image.

1. `browser_navigate` to the issue. A private repo reads as **404** when the
   browser profile is signed out — that is the signal to hand sign-in to the
   human, not evidence the issue is gone.
2. Stage the files where the upload tool may read them. `browser_file_upload`
   refuses paths outside its allowed roots (the working directory,
   `.playwright-mcp/`), so copy them in and delete them afterwards.
3. `browser_click` the "Paste, drop, or click to add files" control → the tool
   reports a file-chooser modal → `browser_file_upload` with **every** path in one
   call. They upload in the order given.
4. Wait, then read the textarea. GitHub has written one
   `<img src="https://github.com/user-attachments/assets/…">` per file, in that
   order. Map URLs to files by position, cross-checking the `width`/`height`
   attributes: captures at different viewports have distinct dimensions, which
   catches an off-by-one.
5. Clear the textarea **without submitting**. The URLs stay valid; you post the
   comment in step 5.

Write real alt text saying what each image shows. On a private repo GitHub serves
these from `private-user-images.githubusercontent.com`, so they inherit repo
access. Never move client screenshots to a public image host to route around an
auth problem.

**ClickUp**: `clickup_request_attachment_upload` per file → multipart `POST` to the
returned `upload_url` with header `X-Upload-Ticket: <ticket>` and field
`attachment`, using a native HTTP client or argument array; never interpolate the
path into a shell string. The response `url` ends in the filename, so map by name,
not position. Uploads land in the task's Attachments list and must stay there for
the links to work.

If the browser can't be signed in, fall back: give the human the upload order as
a numbered list of filenames, let them post a bare comment with the attachments,
then fetch it, extract the attachment lines byte-identically, and `PATCH` it into
the format below. Say which mappings you inferred by position — only the human can
confirm them.

## 4. Write the comment

GitHub format:

```md
## Test plan execution

One paragraph: the environment, what drove the run, what the human did by hand,
and that test data was cleaned up and the cleanup verified.

### 1. <plan item 1, quoted verbatim>

Why this artefact passes the item — not a description of the screenshot.

![what it shows](https://github.com/user-attachments/assets/…)

### 2. <plan item 2, quoted verbatim>

Statement for the first artefact.

![…](…)

<hr>

Statement for the second artefact.

![…](…)
```

- **`<hr>` between evidence pairs inside a section**, so each statement is
  visibly coupled to its own artefact. None straight after a heading.
- **Deviations go inline**, under the point they affect, not in a trailing
  section: more fixtures than specified, a narrower query than implied, a step
  you couldn't perform.
- **Attribution**: in the format the user's agent instructions give for an
  issue comment (for Claude Code, `~/.claude/CLAUDE.md`).

ClickUp comment markdown is partial. Headings, task lists, bullets, bold, inline
and fenced code, and plain links render. Images don't: `![](url)` becomes a
broken attachment chip, `<img>` shows as raw HTML, and tables are stored as the
word `undefined`. So on ClickUp:

- Use the same headings and statements, with each screenshot as a named link,
  `[📷 what it shows](url)`, and bullets instead of `<hr>` or tables.
- Put the attribution the user's instructions give for ClickUp first, as plain
  text.
- Don't edit someone else's test-plan comment to tick its boxes. Post a threaded
  reply (`clickup_create_comment` with `reply_to_id`) copying each item verbatim
  with `- [x]` / `- [ ]`. A comment *you* posted can be fixed in place with
  `clickup_update_comment` (still an approved write).

## 5. Post it

Write the body to a file in the scratchpad, check the attribution is there, show
it, and post once approved:

```bash
grep -q "<attribution marker>" "$f" || { echo "no attribution"; exit 1; }
gh issue comment <n> --repo <owner>/<repo> --body-file "$f"
```

Then check it rendered rather than trusting the call. GitHub: reload and confirm
each image has `naturalWidth > 0`. ClickUp: read it back with
`clickup_get_threaded_comments` — `undefined` or a raw `<img` means it didn't
render — and ask the human to eyeball the links.

## Writing the statements

- **Claim only what the artefact shows.** The commonest failure is asserting a
  sequence a single frame cannot contain — "clicking *Delete anyway* fails" under
  a screenshot showing only an error and a surviving record. Put each claim on the
  artefact that evidences it; if the claim needs two, say which one carries which
  half; if nothing in the pack evidences it, don't assert it.
- **Say why it passes, not what it depicts.** "An order matching neither
  ascending nor descending sort, so a preserved order cannot be mistaken for a
  sort" earns its place. "Screenshot of the moments field" does not.
- **Name documents in full.** Spell out the referenced document's title or id as
  it appears in the artefact, so the reader can match sentence to screenshot.
- **One artefact can serve two items.** Repeat it under both and say so —
  self-contained sections are the point.
- **Don't import requirements** from a different document and report them as
  gaps against this ticket; note them separately if they matter.
