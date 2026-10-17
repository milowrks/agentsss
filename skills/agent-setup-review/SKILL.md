---
name: agent-setup-review
description: >-
  Review and clean up the user's own Claude Code setup: hooks, memories, the
  global CLAUDE.md rules, settings, plugins and skills. Finds what's stale,
  duplicated, contradictory or saved where it never loads, then walks through
  fixes one approved step at a time. Use whenever the user asks to review,
  audit, tidy, prune or summarise their hooks, memory, rules, skills, plugins
  or Claude config ("some might be no longer required", "what rules do I
  have", "list and review skills"), and for the scheduled monthly read-only
  check.
license: MIT
compatibility: claude-code (it audits Claude Code's own config)
requires: macOS, bash, jq, git; gh optional
metadata:
  author: Milo Z.
  version: "1.0.0"
  status: beta
---
# Claude setup review

```
INVENTORY, VERIFY, THEN ONE APPROVED STEP AT A TIME. BACK UP FIRST, TRASH DON'T DELETE.
```

Config drifts quietly: a hook matches tool names that changed, a memory holds a
rule that only loads in one folder, a skill contradicts a rule added later. The
user can't see most of this, so the value here is a short, evidenced list of what
to change and a safe way to change it.

## Modes

- **Interactive** (the user asked in a session): inventory → findings → a
  numbered plan → apply one step at a time, each shown and approved first.
- **Read-only** (the scheduled check, or the user says "just report"): do steps
  1–3 and stop; skip step 4. Write the report to
  `~/Documents/Notes/Drafts/YYYY-MM-DD Claude setup review.md` (needs the sandbox
  disabled) and change nothing else. If that write is refused (for example when
  running as a subagent), return the report as text instead. Lead it with
  anything urgent.

The running session's tool list reflects the config it started with, so an MCP
server removed today can still show up as tools until the next session. Judge
config from the files, not from the tools you can see.

## 1. Inventory

Run `scripts/inventory.sh` (read-only). It lists hooks from global and project
settings, enabled plugins and their installs, plugin hooks, memory folders,
CLAUDE.md files, personal/plugin/project skills, and leftover backups. Pass
repo roots as arguments to narrow it; by default it scans every git repo under
`~/Developer`.

Where things live, and what that means for changing them:

| Thing | Where | Loads | Changing it |
|---|---|---|---|
| Global rules | `~/.claude/CLAUDE.md` | every session | edit directly |
| Repo rules | `<repo>/CLAUDE.md`, `AGENTS.md` | that repo | team file: branch + PR, the user pushes |
| Hooks | `~/.claude/settings.json`, `<repo>/.claude/settings.json` | everywhere / that repo | committed project settings are team files |
| Plugin hooks | `~/.claude/plugins/cache/<mkt>/<plugin>/<ver>/hooks/hooks.json` | where the plugin is enabled | only by updating or disabling the plugin |
| Memories | `~/.claude/projects/<encoded-path>/memory/` | **only** when a session starts in that exact folder | edit, move or trash |
| Personal skills | `~/.claude/skills/` | everywhere | edit directly |
| Plugin skills | plugin cache | where enabled | plugin update, or a PR to its repo |
| Project skills | `<repo>/.claude/skills/` | that repo | team file |
| claude.ai skills | `~/.claude/skills/synced/` | everywhere | claude.ai settings, not locally |

The memory row is the one people miss: a general preference saved while working
in one repo never reaches the others, and one saved in a scratch session is
effectively dead.

## 2. Find problems

Read the actual files; the inventory only says where to look. Skip any area the
inventory reports as empty. Hand big sweeps (dozens of memory files, every skill)
to subagents in parallel with a read-only brief and a compact table back. Wait
for every subagent to report before writing your own findings, and spot-check
their strongest claims yourself; if you can't, mark those rows as unverified.

**Follow-ups from the last review**
- Open PRs or branches it left (for example a team skill repo). A branch being
  behind `main` only matters if it conflicts: a PR diffs against the merge base,
  so files `main` changed since aren't deleted by merging it.
- Backups (`*.bak`) older than about a week: offer to trash them.

**Permissions**
- Allow rules naming MCP servers that don't exist under that name. The same
  naming trap as hooks below: `mcp__claude_ai_ClickUp__…` is the terminal name,
  and the desktop app's connector servers are UUID-named, so add both forms.
- Tools that CLAUDE.md or a skill routes work to but that have no allow rule
  (a fallback MCP server), which then prompt every call.

**Hooks**
- Matchers that name tools that no longer exist. MCP tools are named
  `mcp__<server>__<tool>`, and in the desktop app connector servers carry a UUID
  (`mcp__<uuid>__clickup_create_comment`), not `mcp__claude_ai_ClickUp__…`. A
  matcher written for one won't fire in the other; match on the tool suffix.
- The same job done twice: a project hook duplicating a plugin's hook.
- Commands pointing at scripts or binaries that are gone.
- Hooks whose rule now lives in CLAUDE.md, or that the user calls deprecated.

**Memories**
- Misplaced: a rule meant for every repo saved in one project's folder. These
  move to CLAUDE.md (short) or a skill (long and situational).
- Stale: tied to a PR, issue or ticket that's merged or closed (check with `gh`),
  a tool bug fixed in the installed version, a file or flag that no longer
  exists.
- Covered: a skill or the repo's own CLAUDE.md now enforces it.
- Duplicates across folders, `[[links]]` to missing memories, `MEMORY.md` lines
  whose file is gone (watch filename case) or files missing from the index.

**Rules (CLAUDE.md)**
- `@imports` whose target doesn't exist with that exact case (works on macOS,
  breaks on Linux and in cloud sessions). The inventory flags these.
- Lines specific to one project in the global file.
- Contradictions with skills or settings (attribution formats, who pushes or
  posts, where drafts go, which browser).
- Claims about tools that a version check shows are no longer true.

**Settings and plugins**
- Plugins whose skills lag the CLI they drive. Compare the installed plugin
  version with upstream (read-only:
  `gh api repos/<owner>/<repo>/contents/.claude-plugin/plugin.json --jq .content | base64 -d`)
  and with the CLI's `--version`, and grep the plugin's `skills/` for commands
  the CLI's `--help` doesn't list (ignore its `docs/`).
- Plugins enabled in a repo's settings but not installed for it, and install
  records whose project folders are all gone (prune with `claude plugin`, never
  by hand-editing `installed_plugins.json`).
- Project-scope plugin installs pinned to an old version; updating at user scope
  doesn't touch them (`claude plugin update <p> --scope project`, run from that
  repo).
- MCP servers whose default can't run (a browser that isn't installed), and
  config files no server uses any more.
- Leftovers the inventory lists: `~/.claude.json` project entries for deleted
  folders, transcript folders in `~/.claude/projects` for deleted worktrees and
  scratch sessions (only disk space; trash on request), and clutter such as an
  Obsidian `.trash/` inside `~/.claude/skills`.
- Context in global settings that only fits one project (auto-mode environment
  notes, trusted repos).

**Skills**
- Instructions contradicting CLAUDE.md. Prefer skills that point at CLAUDE.md
  over ones that restate its wording, so one edit updates both.
- Hard-coded project specifics (issue numbers, datasets, URLs) that mislead in
  other repos, and `gh` calls without `--repo`.
- Stale tool names, CLI verbs, paths, or references to memories and hooks that
  no longer exist.
- Trigger overlap with other skills, including the `lazyspec:*` entry point.
- Two skills owning the same step, and personal copies that have drifted from
  a team copy (diff them; say which way the drift goes).

Verify before you assert. Read the installed source (`~/.cargo/registry/src`,
`node_modules`, the plugin cache) rather than trusting a memory's claim about a
tool, and say what you checked.

## 3. Report

One table per area: item, verdict (keep, fix, move, merge, delete, verify), one
line of evidence. Then a numbered plan, ordered so that the global rules are
written before the memories they replace are removed. Name anything outside the
cleanup that's urgent (a fix that never merged) at the end.

## 4. Apply, one step at a time

Each step: show what changes (a table of now → after, or a draft file sent to
the user), wait for an explicit yes, apply, verify, then present the next step.
Ask only for the decisions the user must make; don't make them choose between
wordings you can settle yourself.

- **Back up first**: copy `CLAUDE.md`, `settings.json`, `~/.claude.json` and the
  skills folder to `*.pre-<what>-YYYYMMDD.bak` before the first edit.
- **Trash, don't delete**: move memories, folders and old backups into
  `~/.Trash/claude-<what>-YYYYMMDD/`, keeping their source folder names so
  anything can be restored.
- **Repair after removing**: update `MEMORY.md` indexes and repoint or drop
  `[[links]]` and skill references to anything removed. Grep to confirm none are
  left.
- **Team files**: never edit committed project settings, repo CLAUDE.md or
  project skills in place. Offer a branch and a local commit; the user pushes
  and opens the PR. A team-shared skill must not carry the user's personal paths
  or formats; point at "the user's agent instructions" instead.
- **Next session**: plugin, MCP server and hook changes apply from the next
  session; say so.

## Gotchas

- The Bash tool runs zsh: an unquoted `$VAR` holding a list doesn't split (use an
  array), and `*(N)` glob qualifiers fail under some setups (use `find`).
- macOS `sed -i ''`, `stat -f`; `du`/`cat` choke on paths starting with `-` (the
  encoded project folders): use `cat -- ` or `./`.
- Auto mode may block `gh api` calls; fall back to local clones, or ask.
- Memory folder names encode the path (`/` → `-`); a folder for a scratch or
  deleted directory is dead weight.
