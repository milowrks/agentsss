---
name: digest-large-pr
description: 'Use when a pull request is too big to review front-to-back and the human needs a way in. Reads the whole PR, marks genuinely auxiliary files (configs, fixtures, lockfiles, generated output) as viewed so they collapse out of the file list, then posts a reading guide comment -- what the auxiliary files were, the architecture of the implementation, and the substantive files grouped into an ordered set of review batches. Triggers on "digest this PR", "review this large PR", "big PR", "help me review PR #N", "this PR has too many files", "give me a reading guide for this PR".'
license: MIT
compatibility: pi, claude-code, any agent-skills-compatible harness
requires: gh (authenticated, repo scope), jq, POSIX shell — or any GraphQL-capable GitHub access, see "Doing this without the scripts"
metadata:
  author: Milo Z.
  version: "1.0.0"
  status: stable
---

# Digest Large PR

```
SHRINK THE FILE LIST, EXPLAIN THE SHAPE, HAND OVER AN ORDERED PLAN
```

A 60-file PR is not 60 files of review. It is usually 8 files that decide whether the change is correct and 52 that just have to be *not wrong*. This skill separates those two piles, clears the second one out of the human's way, and turns the first into a sequenced reading plan with a stated architecture behind it.

The deliverable is a **reading guide**, not a verdict. Do not approve, request changes, or leave line-level critique from this skill -- the human is the reviewer and this makes them faster, it does not replace them. Flag anything alarming you happen to notice, but finding bugs is a dedicated code-review pass's job, not this one's.

<HARD-GATE>
Read every file before you mark it viewed. "Viewed" is a claim that a human's eyes are not needed on it. A glob is not evidence -- `*.json`, `fixtures/`, and `*.lock` all routinely hide load-bearing changes. If you did not read the diff, do not mark it.
Confirm before posting. The guide comment is visible to the whole team and posts as the human. Show them the full text and get an explicit go-ahead. Marking files viewed is per-account and invisible to others, so it needs no separate confirmation once the human has invoked this skill -- that is what they asked for.
Disclose authorship. Anything posted while authenticated as the human must state that an AI assistant generated it and the human reviewed it -- name yourself as that assistant, whichever one you are. Check the repo's agent-instruction file -- `AGENTS.md`, `CLAUDE.md`, or whatever the equivalent is -- in case it mandates specific wording, and follow that instead. Put the disclosure in the same text you pass to `--body`; never post via `--body-file`, since any pre-post check that inspects the command text cannot see inside a file argument, and will either block the call or wave through an undisclosed comment.
</HARD-GATE>

<NEVER>
- Do NOT mark a substantive file viewed because it is small, or because you already understood it. Understanding it is exactly why it belongs in a batch with your notes attached.
- Do NOT classify from the file table alone. `additions/deletions` and a path tell you nothing about whether a config change flips a production default.
- Do NOT let the batch plan be an alphabetical or directory-order relabelling of the file list. If the order carries no argument about what depends on what, it is not worth posting.
- Do NOT rewrite, fix, or push to the branch. This skill reads and reports.
</NEVER>

## 0. Check you can actually finish

This skill needs the GitHub CLI authenticated against the host (`gh auth status`, with `repo` scope), `jq`, and a POSIX shell to run the two helper scripts. Verify that up front. Failing at step 3 with 60 files already classified wastes the entire pass, and marking files viewed is the half of this skill the human cannot easily do themselves.

The helper scripts live in `scripts/` **inside this skill's own directory**, not the repo under review. Different agents install skills in different places, so resolve that directory once and prefix every invocation with it -- your working directory will be the project:

```bash
SKILL_DIR=$(find ~/.claude/skills ./.claude/skills ~/.agents/skills ./.agents/skills \
  ~/agentsss/skills /mnt/skills \
  -maxdepth 4 -type d -name digest-large-pr -print -quit 2>/dev/null)
```

Add your own harness's skills root to that list if it is not there.

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

## 4. Work out the architecture

Before ordering anything, understand the change well enough to describe it in a short paragraph: what enters the system, what transforms it, what comes out, and where this PR intervenes in that path. Trace the real call chain across the substantive files, and name the mechanism -- not "adds a service" but "puts a write-through cache between the resolver and the repository, so invalidation now has to happen on the mutation path."

Include the parts of the flow the PR *doesn't* touch when they are needed to make sense of the parts it does. Cite files so the human can verify rather than trust you.

If the PR does more than one thing, say so -- "this is two changes sharing a branch" is genuinely useful and often the most actionable thing in the guide.

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

## 6. Post the guide

Show the human the full comment text, get the go-ahead, then build the body in a variable and pass it inline. A reading guide is long and full of backticks and newlines, so quote it through a heredoc rather than trying to escape it into one argument -- the text still travels in the command, where pre-post checks can see the disclosure:

```bash
body=$(cat <<'EOF'
## Reading guide 🗺️
...full text, including the disclosure line...
EOF
)
gh pr comment <n> --repo <owner>/<name> --body "$body"
```

Template -- keep it tight; a reading guide that needs its own reading guide has failed:

```md
## Reading guide 🗺️

**<N> files, +X/−Y.** <One sentence on what the PR does.>

### Architecture
<Short paragraph: the flow end to end and where this PR intervenes. Cite files.>

### Suggested review order

**1. <Batch name>** — `file-a`, `file-b`
<Why these first. What question to hold in mind.>

**2. <Batch name>** — `file-c`, `file-d`
<...>

🔑 **Keystone:** `path/to/file` — <what to look hardest at, and why it carries the most risk.>

### Marked as viewed (<M> files)
Collapsed on my own file list to shrink the diff — <one-line-per-group summary, e.g. "12 snapshot files regenerated by the schema change; `pnpm-lock.yaml` for the single stated dep bump; 4 CI configs, no permission or trigger changes">.

<Note any file that looked auxiliary but was promoted, and why.>

---
*This reading guide was generated by <name yourself -- e.g. Claude> and reviewed/edited by me before posting.*
```

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

Reply in chat with: the auxiliary/substantive split and how the marking went (including any failures), the architecture summary, the batch plan with the keystone file, and anything that got promoted out of the auxiliary pile or looked out of scope. Then present the comment text and wait for confirmation before posting.
