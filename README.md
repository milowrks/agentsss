# agentsss

A public, **agent-agnostic** collection of skills for AI coding agents — built to the [Agent Skills](https://agentskills.io) standard, so they work in **pi**, **Claude Code**, and any harness that implements the spec. MIT licensed. By [Milo Z.](https://www.npmjs.com/~milowrks)

## Skills

| Skill | Status | Compatibility | Description |
|---|---|---|---|
| [`agent-setup-review`](skills/agent-setup-review/SKILL.md) | beta | Claude Code | Audit your own Claude Code setup (hooks, memories, CLAUDE.md rules, settings, plugins, skills) for what's stale, duplicated, contradictory or saved where it never loads, then fix it one approved step at a time. Ships a read-only inventory script; has a read-only mode for a scheduled monthly check. |
| [`clean-sweep-uninstall`](skills/clean-sweep-uninstall/SKILL.md) | stable | pi, Claude Code | Completely remove a macOS app and its leftovers: caches, preferences, application support, containers, launch agents and dotfiles. |
| [`digest-large-pr`](skills/digest-large-pr/SKILL.md) | stable | pi, Claude Code | Make an oversized PR reviewable: classify every file as auxiliary or substantive, collapse the auxiliary ones out of your file list, and open a pending review — inline comments on the findings, and a reading guide as the review body — for you to continue. |
| [`issue-house-style`](skills/issue-house-style/SKILL.md) | stable | pi, Claude Code | Write, groom or review the body of a GitHub story, spike or bug at the right altitude: behaviour not mechanism, no delivery storytelling, cause and history in comments, and a review checklist. Built for lazyspec-managed repos; the judgement rules work with any tracker. |
| [`issue-kick-off`](skills/issue-kick-off/SKILL.md) | stable | pi, Claude Code | Check a GitHub issue is actually ready to build before an agent starts: validate the acceptance criteria against the real code, resolve open questions from installed source rather than recall, classify adjacent work as blocking or not, and equip the human to review the build. |
| [`pr-description`](skills/pr-description/SKILL.md) | stable | pi, Claude Code | Write or update a PR description in a fixed Summary / Changes / Caveats / Verification template, grounded in the actual diff, and shown for approval before it's posted. |
| [`write-good-rtl-tests`](skills/write-good-rtl-tests/SKILL.md) | stable | pi, Claude Code | Write and review high-quality React unit tests with React Testing Library, including React 19-era patterns for React Server Components (RSC) and when to eject to E2E. |

Each skill is a directory with `SKILL.md` (frontmatter + instructions), plus `references/` (deep-dive docs loaded on demand) and/or `scripts/` (helpers the agent runs) where useful. No harness-specific code anywhere — pure Agent Skills spec.

Skills that shell out declare their tools in a `requires:` frontmatter field. `digest-large-pr` needs an authenticated [`gh`](https://cli.github.com/) plus `jq`, and documents the raw GitHub GraphQL calls as a fallback for agents that cannot run shell scripts. `issue-kick-off` needs `gh`, and works with any tracker workflow — if your project fronts its issues with a spec/document CLI, the skill defers to that tool instead.

## Installation

### pi

```bash
pi install git:github.com/milowrks/agentsss
```

Pin a specific version for stability:

```bash
pi install git:github.com/milowrks/agentsss@v1.0.0
```

Add to project settings (`.pi/settings.json`) for a team:

```json
{
  "packages": ["git:github.com/milowrks/agentsss"]
}
```

Load with `/skill:write-good-rtl-tests` or let pi auto-discover it. Update with `pi update --all`.

### Any other harness

`install.sh` symlinks every skill into whatever directory your harness reads, so the same command serves Claude Code, `.agents/`-style harnesses, and project-local installs:

```bash
git clone git@github.com:milowrks/agentsss.git ~/agentsss
~/agentsss/install.sh                              # -> ~/.claude/skills (default)
~/agentsss/install.sh --target ~/.agents/skills    # any harness's skills directory
~/agentsss/install.sh --target .claude/skills      # project-local (commit the symlinks if the repo is shared)
```

Check your harness's own docs for where it reads skills from; the [Agent Skills spec](https://agentskills.io) lists the common locations. `AGENTSSS_TARGET` works instead of `--target` if you'd rather set it once. `install-claude.sh` is kept as a wrapper for the default target so older instructions keep working.

Symlinks mean a `git pull` in the clone updates every harness at once — no re-install needed. In Claude Code, restart and use `/skills` to list, or let it auto-load a skill when a task matches.

## Updating

- **pi**: `pi update --all`
- **Everything else**: `git pull` in the clone. Symlinks stay valid, so there is nothing to re-run unless a new skill was added — then re-run `install.sh` to link it.

## Security

Agent skills run with your agent's permissions and can instruct the model to perform actions on your machine. Review any skill's contents before installing, and only install from sources you trust. The scripts in this repo (`install.sh`, and the per-skill helpers under `skills/*/scripts/`) are plain shell — read them before running.

## License

MIT — see [LICENSE.md](LICENSE.md). No warranty: use at your own risk. Free to use, modify, and redistribute (even commercially); attribution appreciated but not required.
