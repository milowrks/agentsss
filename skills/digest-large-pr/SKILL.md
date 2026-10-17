---
name: digest-large-pr
description: 'Use when a pull request is too big to review front-to-back and the human needs a way in. Reads the whole PR, marks genuinely auxiliary files (configs, fixtures, lockfiles, generated output) as viewed so they collapse out of the file list, then starts a review -- inline comments on what it noticed, and a reading guide as the review body covering what the auxiliary files were, the architecture of the implementation, and the substantive files grouped into an ordered set of review batches -- for the human to continue and approve. Triggers on "digest this PR", "review this large PR", "big PR", "help me review PR #N", "this PR has too many files", "give me a reading guide for this PR".'
license: MIT
compatibility: pi, claude-code, any agent-skills-compatible harness
requires: gh (authenticated, repo scope), jq, POSIX shell — or any GraphQL-capable GitHub access, see "Doing this without the scripts"
metadata:
  author: Milo Z.
  version: "1.1.0"
  status: stable
---
# Digest Large PR

```
SHRINK THE FILE LIST, EXPLAIN THE SHAPE, HAND OVER AN ORDERED PLAN
```

A 60-file PR is not 60 files of review. It is usually 8 files that decide whether the change is correct and 52 that just have to be *not wrong*. This skill separates those two piles, clears the second one out of the human's way, and turns the first into a sequenced reading plan with a stated architecture behind it.

The deliverable is a **started review**, not a verdict: inline comments on what you noticed, and the reading guide as the review body, submitted as a comment for the human to continue and approve. Never approve or request changes -- the human is the reviewer and this makes them faster, it does not replace them. Flag anything alarming you happen to notice, but finding bugs is a dedicated code-review pass's job, not this one's, so an inline comment here poses a question rather than demanding a change.

<HARD-GATE>
Read every file before you mark it viewed. "Viewed" is a claim that a human's eyes are not needed on it. A glob is not evidence -- `*.json`, `fixtures/`, and `*.lock` all routinely hide load-bearing changes. If you did not read the diff, do not mark it.
Confirm before posting. The review is visible to the whole team and posts as the human. Show them the full body text and every inline comment, and get an explicit go-ahead. Marking files viewed is per-account and invisible to others, so it needs no separate confirmation once the human has invoked this skill -- that is what they asked for.
Disclose authorship. Anything posted while authenticated as the human must say that an AI assistant generated it -- name yourself as that assistant, whichever one you are. Use the exact format from the user's own agent instructions (for Claude Code, `~/.claude/CLAUDE.md`) or the repo's `AGENTS.md`/`CLAUDE.md`; the format can differ between the review body and inline comments.
</HARD-GATE>

<NEVER>
- Do NOT mark a substantive file viewed because it is small, or because you already understood it. Understanding it is exactly why it belongs in a batch with your notes attached.
- Do NOT classify from the file table alone. `additions/deletions` and a path tell you nothing about whether a config change flips a production default.
- Do NOT let the batch plan be an alphabetical or directory-order relabelling of the file list. If the order carries no argument about what depends on what, it is not worth posting.
- Do NOT rewrite, fix, or push to the branch. This skill reads and reports.
- Do NOT repeat anything the PR page already shows -- the changed-file count, the `+X/-Y` diffstat, branch names, or a restatement of the PR description or linked issue. GitHub renders all of it inches above your review. Every duplicated line is reading overhead the human has to skip before reaching what only you can tell them, which is the exact cost this skill exists to remove.
</NEVER>

## 0. Check you can actually finish

This skill needs the GitHub CLI authenticated against the host (`gh auth status`, with `repo` scope), `jq`, and a POSIX shell to run the two helper scripts. Verify that up front. Failing at step 3 with 60 files already classified wastes the entire pass, and marking files viewed is the half of this skill the human cannot easily do themselves.

The helper scripts live in `scripts/` **inside this skill's own directory**, not the repo under review. Different agents install skills in different places, so resolve that directory once and prefix every invocation with it -- your working directory will be the project:

```bash
SKILL_DIR=$(find ~/.claude/skills ~/.config/claude/skills ./.claude/skills ./.agent/skills /mnt/skills \
  -maxdepth 4 -type d -name digest-large-pr -print -quit 2>/dev/null)
```

If your runtime already tells you where the loaded skill lives, use that instead, and if the search comes back empty, ask the human where the skill is installed rather than running the scripts from a guessed path. If you cannot run shell scripts at all -- no shell, a non-POSIX one, or GitHub reachable only through an API client -- do not abandon the skill: the two GitHub operations it wraps are in **Doing this without the scripts** at the end, and every other step is reading and judgement.

## 1. Scope the PR

```bash
gh pr view <n> --repo <owner>/<name> --json title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,url
"$SKILL_DIR/scripts/pr-files.sh" --repo <owner>/<name> --pr <n>   # TSV: path, changeType, additions, deletions, viewedState
```

Use `pr-files.sh` rather than `gh pr view --json files` -- the latter and the REST endpoint both truncate at 100 files, which is silent data loss on exactly the PRs this skill exists for.

Read the PR description and the linked issue/ticket first. The stated intent is what you check the file classification against: a file that has nothing to do with the stated intent is a *question*, not an auxiliary file.

If the PR is large enough that reading every diff would blow your context, read in waves by area -- or, if your runtime can spawn subagents, delegate one area each -- and keep only the per-file verdict and a one-line note. Never let a context shortcut turn into an unread file marked viewed.

## 2. Classify every file: auxiliary or substantive

Auxiliary means: **a reviewer who read this file would learn nothing that changes their opinion of the PR.** Work file by file, reading the actual diff.

Usual auxiliary candidates -- candidates, not verdicts:

- Lockfiles and dependency manifests tracking a stated upgrade
- Generated output: API clients, snapshots, compiled schemas, ORM-generated migrations
- Fixture, seed, and mock data
- Tool config: linter, formatter, editor, tsconfig, build config
- Docs, changelogs, comments, static assets
- Mechanical churn: pure renames, import reordering, formatter-only reflows
- Behaviour-preserving refactors: extract-to-const, a function split with the same call graph, a type-only export added for a consumer elsewhere in the same PR. Source code is not automatically substantive -- put it through the same "would a reviewer learn anything" test as everything else, and when the answer is no, mark it viewed.

Before you accept any of those as auxiliary, check it against the **promotion triggers** below. Any hit makes the file substantive, and it goes in a batch with the reason called out:

- **Config that changes runtime behaviour** -- a feature-flag default, timeout, retry, memory/size limit, CORS/CSP, auth or session setting, log level, a public env var. A one-line config diff can be the highest-risk line in the PR.
- **Fixtures that encode the expected behaviour.** When the fixture *is* the spec, reviewing the logic without it is reviewing half the change.
- **Any database migration.** Ordering-sensitive, often irreversible, can lock a table. Never auxiliary.
- **CI/workflow changes** that alter what runs, or touch permissions, secrets, or triggers -- especially `pull_request_target` and added `permissions:` scopes.
- **Lockfile entries no manifest change explains**, new transitive packages, `resolutions`/`overrides`, or a dependency arriving with an install script.
- **Generated files whose source input is not in the diff**, or a source change whose regenerated output is missing -- the pair disagreeing is a real finding.
- **`.gitignore` / `.gitattributes` changes**, which can remove files from review entirely.
- **Anything unrelated to the stated intent.** Scope creep hides in the auxiliary pile.

Record every file as `path | auxiliary/substantive | one-line reason`. You need the reasons for the comment, and the auxiliary reasons are what make the marking auditable.

## 3. Mark the auxiliary files viewed

```bash
"$SKILL_DIR/scripts/mark-viewed.sh" --repo <owner>/<name> --pr <n> --dry-run path...   # check the list first
"$SKILL_DIR/scripts/mark-viewed.sh" --repo <owner>/<name> --pr <n> --stdin < paths.txt # or pass paths as args
"$SKILL_DIR/scripts/mark-viewed.sh" --repo <owner>/<name> --pr <n> --unmark path...    # reverse
```

The script marks one path per call and prints `ok`/`FAILED` per file, exiting non-zero if any failed. **Report failures honestly** -- a file that failed to mark is a file the human still has to triage, and quietly dropping it defeats the point.

Two properties to state plainly whenever you report this:

- **Viewed state is per-account.** It collapses the file in *the token holder's* view only. Teammates see an unchanged PR.
- **A new push clears it** for every file that changed in that push. After a force-push or new commits, re-run the skill rather than assuming the marks held.

## 4. Work out the architecture, then draw it

Before ordering anything, understand the change well enough to trace it: what enters the system, what transforms it, what comes out, and where this PR intervenes in that path. Follow the real call chain across the substantive files, and name the mechanism -- not "adds a service" but "puts a write-through cache between the resolver and the repository, so invalidation now has to happen on the mutation path."

**Deliver that understanding as a diagram, not as prose.** A paragraph of architectural description is the easiest place for this skill to defeat its own purpose: the reader parses dense sentences to rebuild a shape you already had, which is reading overhead, not reading saved. GitHub renders mermaid natively in a review body, so a fenced `mermaid` block needs no image and no library. Draw the flow the change lives in -- the inputs, the branch points, the pieces that come out and their order -- and include the parts the PR *doesn't* touch where they are needed to make the touched parts make sense.

Then add at most three or four short bullets for what a diagram cannot hold: a deliberate coupling between two pieces, a behaviour that flipped from pull to push, anything in the PR that outlives the feature it was written for. If the PR does more than one thing, say so here -- "this is two changes sharing a branch" is genuinely useful and often the most actionable thing in the guide.

Keep file paths out of both the diagram and the bullets; the batch list and the inline comments carry them. Trace it through the real files so what you draw is verifiable rather than plausible. You cannot preview the render before posting, so keep the mermaid conservative -- plain-text node labels and `<br>` only, no `<b>` or `<i>` -- and tell the human to check it rendered.

## 5. Build the review batches

Order by dependency of understanding: each batch should be readable using only what the earlier batches established. The default sequence:

1. **Contract** -- schema, types, interfaces, migrations, API definitions. The vocabulary the rest of the PR speaks. A reviewer who reads these first stops having to guess what a type means four files later.
2. **Core mechanism** -- the logic that fulfils the contract. This is where correctness lives and where the reviewer should spend most of their attention.
3. **Wiring** -- call sites, routes, DI, handlers, components consuming the new thing. Mostly checking the mechanism is used as designed and every call site was updated.
4. **Tests** -- read as a statement of intent, and check they would actually fail without the change.
5. **Cleanup** -- deletions, mechanical follow-through. Skimmable, but confirm nothing still references what was removed.

Adapt the sequence when the change has a different spine (a refactor might go "new abstraction → one migrated call site in full → the rest as a spot-check"). The order has to carry an argument; if you cannot say why batch 2 follows batch 1, rethink it.

Sizing and framing:

- Roughly one sitting per batch -- about 200-400 lines of substantive diff -- and always a coherent stopping point.
- Give each batch a **question to hold in mind** ("does every path that writes to this table also invalidate the cache?"). This is what makes a reading plan better than a file list.
- Name the **keystone file**: if the human reads exactly one file, which one, and what to look for. State the single highest-risk change in the PR.

### Land the order as numbered comments, not a list of paths

Do not spell a batch's files out in the review body. A path written in prose is a string the human has to go and find; a comment anchored on the file is a link that takes them straight there, and GitHub already draws the file tree beside it. So each batch becomes one inline comment, anchored at the top of the file that batch opens with:

> **2. Review the page assembly**
>
> Why this batch sits here, and the question to hold in mind. Name the batch's other files by basename only, if it has any.

Number them in the comment text -- `**1. ...**`, `**2. ...**` -- and never rely on position to carry the sequence. A review's comments are shown against their files in diff order, not in the order you posted them, so the number in the text is the only thing that survives.

The keystone and the highest-risk change are locations too, so they are comments as well. Where either falls in a file that already opens a batch, fold the key or warning line into that batch's comment rather than posting a second one on the same lines.

The body is then a numbered list of batch names and nothing else -- something the human scans in one glance before following the comments down into the diff.

## 6. Post the guide as the opening of a review

Post **one pending review**, not a detached comment. Its inline comments do two jobs: the numbered batch markers from step 5, and the findings you noticed, each on the lines it concerns. The guide is the review body. Submit it with `event: "COMMENT"` so it registers as a review already in progress that the human continues and approves -- never `APPROVE` or `REQUEST_CHANGES`, which are the human's to give.

This is also what keeps the guide short. Anything that needs a file path and a line to make sense belongs inline, where the reader sees it beside the code. The body carries only what a file-level comment cannot: the architecture, the batch names in order, and the marked-viewed summary. Paths, the keystone and the highest-risk change all have a location, so all three are comments.

Anchor every inline comment against the head SHA, and get its line numbers by reading the file at the head ref rather than counting diff hunks by hand -- an off-by-two lands the comment on the wrong field. A multi-line block takes `start_line`/`line` with `side: "RIGHT"`.

Show the human the full text of the body and of every inline comment, get the go-ahead, then build them in variables and assemble the payload with `jq`, piping to `--input -`. Heredocs keep backticks and newlines intact:

```bash
body=$(cat <<'EOF'
## Reading guide 🗺️
...full text, with its attribution...
EOF
)
inline=$(cat <<'EOF'
...finding, with its own attribution...
EOF
)
jq -n --arg commit "<head-sha>" --arg body "$body" --arg ibody "$inline" \
  '{commit_id:$commit, body:$body, event:"COMMENT", comments:[
     {path:"<path>", start_line:<n>, start_side:"RIGHT", line:<m>, side:"RIGHT", body:$ibody}]}' \
  | gh api repos/<owner>/<name>/pulls/<n>/reviews --input -
```

Then confirm each comment anchored where you meant it, by reading back `path`, `start_line` and `line` from `pulls/<n>/comments`.

Template for the review body:

```md
## Reading guide 🗺️

<One line of orientation the PR page does not already give -- the prior PR this builds on, the constraint that shaped it. Cut the line entirely rather than restate the PR description, and never open with a file count or diffstat.>

### How it works
<A mermaid fence: the flow the change lives in. Inputs, branch points, what comes out and in what order.>

<Up to four short bullets for what the diagram cannot hold -- a deliberate coupling, a behaviour that flipped, anything here that outlives the feature. Plain English, no file paths. Say plainly if the PR does more than one thing.>

### Suggested review order

1. **<Batch name>** — <one clause on what this batch settles>
2. **<Batch name>** — <...>

<No paths here. Each numbered comment on the diff opens its batch and carries the detail; 🔑 marks the keystone and ⚠️ the highest-risk change.>

### Marked as viewed (<M> files)
Collapsed on my own file list to shrink the diff — <one-line-per-group summary, e.g. "12 snapshot files regenerated by the schema change; `pnpm-lock.yaml` for the single stated dep bump; 4 CI configs, no permission or trigger changes">.

<Note any file that looked auxiliary but was promoted, and why.>
```

Attribute the body in the format the user's instructions give for a review summary.

Keep it tight, in plain English, and let the inline comments carry the specifics. A reading guide that needs its own reading guide has failed.

Plain English is a requirement here, not a preference. Short sentences, ordinary words, one idea per sentence, no stacked subordinate clauses -- dense prose costs the reader exactly what the collapsed file list saved them. Before posting, reread the body as the reviewer and cut two things: any line that only restates the PR page, and any sentence you had to read twice.

Every inline comment carries its own attribution too, in the format the user's instructions give for inline comments -- each one is a separate posted artifact.

## Doing this without the scripts

The helpers are convenience wrappers around two GitHub GraphQL operations. If you cannot run them, issue these yourself through whatever GitHub access you have -- `gh api graphql`, an HTTP client against `https://api.github.com/graphql` with a `repo`-scoped token, or an MCP GitHub server that exposes GraphQL.

**List every changed file.** Paginate until `hasNextPage` is false. `gh pr view --json files` and REST `/pulls/{n}/files` both stop at 100 with no warning, so pagination is the whole point:

```graphql
query($o:String!, $n:String!, $p:Int!, $c:String) {
  repository(owner:$o, name:$n) { pullRequest(number:$p) {
    id
    files(first:100, after:$c) {
      pageInfo { hasNextPage endCursor }
      nodes { path changeType additions deletions viewerViewedState }
    } } }
}
```

**Mark a file viewed.** One call per path, using the `pullRequest.id` node ID from above. `unmarkFileAsViewed` takes the same input and reverses it:

```graphql
mutation($id:ID!, $path:String!) {
  markFileAsViewed(input: {pullRequestId:$id, path:$path}) { pullRequest { number } }
}
```

A path that is not part of the PR fails with `Filepath must be part of pull request` -- treat that as a real failure to report, not noise. There is **no REST equivalent for viewed state**: if your GitHub access is REST-only, say so plainly and deliver the reading guide without step 3, rather than skipping it silently and letting the human think the file list was shrunk.

## Output shape

Reply in chat with: the auxiliary/substantive split and how the marking went (including any failures), the architecture diagram, the batch plan with the keystone file, and anything that got promoted out of the auxiliary pile or looked out of scope. Then present the review body and every inline comment, and wait for confirmation before posting.
