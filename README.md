# agentsss

A public, **agent-agnostic** collection of skills for AI coding agents — built to the [Agent Skills](https://agentskills.io) standard, so they work in **pi**, **Claude Code**, and any harness that implements the spec. MIT licensed. By [Milo Z.](https://www.npmjs.com/~milowrks)

## Skills

| Skill | Status | Compatibility | Description |
|---|---|---|---|
| [`digest-large-pr`](skills/digest-large-pr/SKILL.md) | stable | pi, Claude Code | Make an oversized PR reviewable: classify every file as auxiliary or substantive, collapse the auxiliary ones out of your file list, and open a pending review — inline comments on the findings, and a reading guide as the review body — for you to continue. |
| [`issue-kick-off`](skills/issue-kick-off/SKILL.md) | stable | pi, Claude Code | Check a GitHub issue is actually ready to build before an agent starts: validate the acceptance criteria against the real code, resolve open questions from installed source rather than recall, classify adjacent work as blocking or not, and equip the human to review the build. |
| [`write-good-rtl-tests`](skills/write-good-rtl-tests/SKILL.md) | stable | pi, Claude Code | Write and review high-quality React unit tests with React Testing Library, including React 19-era patterns for React Server Components (RSC) and when to eject to E2E. |
| [`browser-qa-verification`](skills/browser-qa-verification/SKILL.md) | stable | Claude Code | Verify a change in a real browser against a deployment or a local app or CMS Studio: scope the checks to the diff, get past Vercel Deployment Protection with a temporary bypass secret, verify results in the data store rather than the form, and capture screenshot and payload evidence against the test plan. |
| [`cross-browser-ticket-qa`](skills/cross-browser-ticket-qa/SKILL.md) | beta | Claude Code | Turn a ticket into an approved test plan and run it as one Playwright script in Chromium, WebKit and Firefox. The human signs in by hand and the session stays in memory. Each step's screenshot shows the whole component or screen, with the region that proves the result outlined green or red. |
| [`evidence-test-plan`](skills/evidence-test-plan/SKILL.md) | stable | Claude Code | Post a finished test plan run to its GitHub issue or ClickUp task: every plan item a heading, every screenshot under the claim it proves, uploaded by the skill itself, after the human approves the text. |

Each skill is a directory with `SKILL.md` (frontmatter + instructions), plus `references/` (deep-dive docs loaded on demand) and/or `scripts/` (helpers the agent runs) where useful. No harness-specific code anywhere — pure Agent Skills spec.

Skills that shell out declare their tools in a `requires:` frontmatter field. `digest-large-pr` needs an authenticated [`gh`](https://cli.github.com/) plus `jq`, and documents the raw GitHub GraphQL calls as a fallback for agents that cannot run shell scripts. `issue-kick-off` needs `gh`, and works with any tracker workflow — if your project fronts its issues with a spec/document CLI, the skill defers to that tool instead. The three browser QA skills drive a [Playwright MCP server](https://github.com/microsoft/playwright-mcp); `cross-browser-ticket-qa` also needs Node 20.11 or later and pnpm, and installs Playwright and its three browsers once on first use.

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
