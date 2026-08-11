---
name: issue-kick-off
description: 'Use when picking up a GitHub issue (story, bug, spike) before an agent starts building it -- validates the issue is build-ready, resolves any open questions with concrete code/framework evidence, checks for relevant or blocking related issues, and equips the human implementer to review the eventual agent implementation. Triggers on "kick off issue", "investigate this issue", "is this issue ready to build", "help me understand this ticket before we build it", "read issue #N and check it''s ready".'
license: MIT
compatibility: pi, claude-code, any agent-skills-compatible harness
requires: gh (authenticated, repo scope) — optionally a spec/document CLI such as lazyspec, see "If your project has a document tool"
metadata:
  author: Milo Z.
  version: "1.0.0"
  status: stable
---

# Issue Kick-Off

```
VALIDATE THE ISSUE, GROUND IT IN CODE, EQUIP THE HUMAN TO REVIEW
```

Issue-kick-off sits between "issue exists" and "agent starts building." It has two jobs, run in order: **validate** the issue is actually ready for an agent to build against, and **equip the human** who will review that build -- at an architecture level, in plain language for stakeholders if the issue is user-facing, and against any adjacent work already in flight.

This is investigation and (with confirmation) light issue-grooming. It is never implementation -- do not write application code from this skill.

<HARD-GATE>
Read before mutating. Never edit an issue body, its metadata, or its relations without first reading the current version (`gh issue view <n> --json body,title,labels,comments`, or your project's document CLI if it has one).
Confirm before mutating. Editing the issue body, linking a related issue, or posting a GitHub comment are all visible, hard-to-reverse actions. Present what you found and what you propose to change, and get an explicit go-ahead before running the mutating command -- unless the human's request already names the specific action (e.g. "post a comment explaining X" is authorization for that comment, not a license to also edit the body unasked).
Ground claims in code, not memory. Any claim about how a framework, adapter, or library behaves (e.g. "does X support external URLs") must be verified by reading the actual installed source at the pinned version (`node_modules`, `vendor/`, `site-packages`, or your ecosystem's equivalent) or the repo's own code -- never asserted from training-data recall. This is what turns an "open question" in an issue into resolved context instead of a guess.
</HARD-GATE>

<NEVER>
- Do NOT hand-edit files that a document/spec CLI manages. Such tools own their frontmatter and relation graph, so go through their own update/link commands -- see **If your project has a document tool** below. This holds even though the file looks like ordinary Markdown on disk.
- Do NOT post a comment or body edit via `--body-file` when the account posting is the human's own and an authorship disclosure is required. Any pre-post check that inspects the command text cannot see inside a file argument, so it will either block the call or wave through an undisclosed comment. Inline the full text into `--body` with the disclosure in that same text (e.g. `*Comment drafted by <name yourself>, reviewed and posted by @<user>.*`), and check the repo's agent-instruction file -- `AGENTS.md`, `CLAUDE.md`, or the equivalent -- in case it mandates specific wording.
- Do NOT let a resolved answer live only in a comment while the issue body still frames it as open. If a comment resolves something the body calls out as unresolved (a spike, a "TBD", an "open at kickoff" note), also edit the body to a short pointer ("Resolved -- see comment below") so the body and the comment thread never disagree about current state.
</NEVER>

## 1. Read the issue

```bash
gh issue view <number> --repo <owner>/<name> --json number,title,body,labels,comments,state,url
```

Use the API, not a web fetch of the issue page -- rendered HTML drops structure and truncates long threads.

**Read the comments, not just the body.** Confirm the `comments` array is genuinely populated (or legitimately `[]`) rather than assuming the body is the only context a downstream agent will see. A decision reversed in comment 7 that the body still contradicts is the single most common way an agent builds the wrong thing.

Read the full chain, not just the leaf issue: follow links to the parent epic/RFC the issue implements and to sibling issues. If the project has a document tool that models those relations, prefer it -- see **If your project has a document tool** below.

## 2. Validate build-readiness

Check each of these against the issue text, and -- critically -- against the actual repo, not just against itself:

- **Context is accurate and helpful.** Every file, function, or behavior the issue names should exist and do what's claimed. Open each named file and confirm. An issue that cites a file that doesn't exist, or describes behavior a recent refactor already changed, is not ready -- flag it before anything else.
- **Intended outcome is singular and clear.** The Goal/story statement and the acceptance criteria should describe one coherent change, not a bundle. If ACs test things the Goal doesn't mention (or vice versa), that's a gap to surface.
- **Acceptance criteria are testable.** Given/When/Then rows should be concrete enough that another agent (or a human reviewer) can write a test straight from them, with no invented interpretation. Watch specifically for validation/parsing rules stated loosely ("an external URL," "a valid value") where the real requirement is narrower (e.g. "http/https only, not any string containing `://`") -- tighten these before build, since a loose acceptance criterion becomes a loose implementation.
- **No unresolved "open questions" are left for the agent to guess at.** If the issue flags something as open/TBD/a spike, treat resolving it as this skill's job, not the implementer's -- see step 3.
- **Test plan matches the ACs.** Manual steps are fine if that's this repo's norm, but every AC should have a corresponding step.

## 3. Resolve open questions with evidence, not speculation

When an issue defers a question ("open at kickoff," "TBD," "needs a spike"), try to close it before the agent starts, using the same technique regardless of what the question is about:

1. Identify exactly which code path the question depends on.
2. Read the *installed* source for anything framework/library/adapter-related, at the version this project actually pins -- `node_modules/<package>/`, `vendor/`, the virtualenv's `site-packages/`, `~/.cargo/registry/`, whatever your ecosystem uses -- rather than relying on trained knowledge of that library, which may be stale or wrong for the pinned version. Trace the real call chain (e.g. config option -> core renderer -> adapter transform -> platform output) and cite exact files/functions.
3. If the answer is genuinely undecidable from code (a product decision, an unverifiable-until-deployed behavior), say so plainly instead of forcing a resolution -- don't manufacture false confidence.
4. Once resolved, post the evidence as a comment (see step 6 for the disclosure/inlining rule) and edit the body's mention of the open question down to a short "resolved, see comment" pointer -- never leave both saying different things.

## 4. Build the architecture-level picture

Produce (in the chat reply, not necessarily written anywhere unless asked) a walkthrough the human implementer can hold onto through the build and the review:

- The full data/control flow the change touches, end to end (e.g. CMS schema -> build-time loader -> framework config -> adapter transform -> platform runtime) -- not just the files the issue happens to mention.
- Which files change and *why*, distinct from files that look related but are out of scope.
- Any non-obvious mechanism worth knowing for review (framework internals, a caching layer, a validation gate) with file/function citations so the human can independently verify rather than take it on faith.

This is what lets the human "reason about it with the agent or a fellow developer during implementation" and "review the agent implementation" afterward -- the goal is a mental model, not a document dump.

## 5. Check for relevant or blocking adjacent work

Search the tracker for anything touching the same files, behavior, or area:

- `gh issue list --repo <owner>/<name> --search "<topic>" --state all --json number,title,state,labels,url`, plus a code search for the files the issue touches (`gh search issues`, or the tracker's own search). Check whatever relation/link fields your tracker exposes on anything found.
- For each candidate, read it fully and classify explicitly as **blocking**, **relevant but not blocking**, or **unrelated** -- don't conflate "touches the same file" with "blocks this work." A dependency is blocking only if this issue's acceptance criteria cannot be satisfied, or would need to be redone, without the other issue landing first.
- For anything relevant, state the *concrete* implementation-order or design implication (shared function should be factored for reuse, a name/API choice to avoid, which one should land first to minimize rework) -- not just "these are related."
- If a relation exists one-directionally (the other issue links here but this one doesn't link back), propose adding the reciprocal link and get confirmation before making it. A one-way link is invisible from exactly the side that needs it -- the issue being built.

## 6. Write back to the issue (only what's confirmed)

Everything here is a real mutation -- confirm scope with the human first unless they've already named the exact action:

- **Body edits**: `gh issue edit <number> --repo <owner>/<name> --body "<full new body>"` for AC tightening, resolving stale open-question framing, or adding a missing test-plan step. Note this replaces the body wholesale, so build the new text from the version you just read rather than from memory.
- **Comments**: `gh issue comment <number> --repo <owner>/<name> --body "<inline text>"` with the text passed inline, not `--body-file`, and the authorship disclosure in that same text whenever the account posting is the human's own. Use comments for evidence, discussion, and rationale (framework findings, why an adjacent issue is or isn't blocking); use body edits for anything that is actually part of the spec (ACs, Goal, Context).
- **Relations**: however your tracker models them -- a link in the body, a GitHub sub-issue/tracking list, or a document tool's link command.

If the project has a document tool that owns the issue, use its commands for all three instead -- see below.

## 7. Plain-language summary (only if user-facing)

If the issue describes a user-facing bug or feature, write a short, jargon-free paragraph the human can hand to a non-technical stakeholder: what breaks or changes for the end user, why, and what "fixed" looks like. Skip this step entirely for internal/technical-only issues (infra, refactors, tooling) -- don't force a stakeholder framing where there's no stakeholder.

## If your project has a document tool

Some repos front their tracker with a spec/document CLI (lazyspec and similar) that models issues as documents with typed relations. Where one exists it is the source of truth, and the GitHub issue is its projection -- so read and write through the tool, and treat the `gh` commands above as the fallback. Check for one before step 1: look for its config in the repo root, or a mention in the repo's agent-instruction file (`AGENTS.md`, `CLAUDE.md`, or equivalent).

Two rules hold for any such tool:

- **Never hand-edit the managed file**, even though it looks like ordinary Markdown. The tool owns frontmatter and the relation graph, and a hand edit desynchronises them.
- **Pass prose only when updating a body.** These tools separate body from frontmatter and re-serialize the frontmatter themselves; including the frontmatter block in the new body duplicates it.

Worked example, lazyspec:

```bash
lazyspec show <id> --json        # body, comments, related, status, assignee as separate fields
lazyspec context <id> --json     # the parent/related chain, not just the leaf document
lazyspec search "<topic>" --json # step 5's adjacent-work sweep
lazyspec update <id> --body-file <path>   # prose only, no frontmatter block
lazyspec link <from> <rel-type> <to>      # relations
```

## Output shape

Reply directly in chat with: a build-readiness verdict (ready / needs tightening, with specifics), the architecture walkthrough, the relevant/blocking assessment of any adjacent issues found, and -- only if the issue is user-facing -- the plain-language summary. Propose any tracker mutations explicitly and wait for confirmation before running them, unless the human's own request already specified the action.
