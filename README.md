# agentsss

A public, **agent-agnostic** collection of skills for AI coding agents — built to the [Agent Skills](https://agentskills.io) standard, so they work in **pi**, **Claude Code**, and any harness that implements the spec. MIT licensed. By [Milo Z.](https://www.npmjs.com/~milowrks)

## Skills

| Skill | Description |
|---|---|
| [`write-good-rtl-tests`](skills/write-good-rtl-tests/SKILL.md) | Write and review high-quality React unit tests with React Testing Library, including React 19-era patterns for React Server Components (RSC) and when to eject to E2E. |

Each skill is a directory with `SKILL.md` (frontmatter + instructions) and `references/` (deep-dive docs loaded on demand). No harness-specific code anywhere — pure Agent Skills spec.

## Installation

### pi

```bash
pi install git:github.com/<github-username>/agentsss
```

Add to project settings (`.pi/settings.json`) for a team:

```json
{
  "packages": ["git:github.com/<github-username>/agentsss"]
}
```

Load with `/skill:write-good-rtl-tests` or let pi auto-discover it. Update with `pi update --all`.

### Claude Code

```bash
git clone git@github.com:<github-username>/agentsss.git ~/agentsss
~/agentsss/install-claude.sh          # symlinks each skill into ~/.claude/skills
```

For a single project instead of personal install, symlink the skill folder into `.claude/skills/` (commit the symlink if the repo is shared):

```bash
mkdir -p .claude/skills
ln -s ~/agentsss/skills/write-good-rtl-tests .claude/skills/write-good-rtl-tests
```

Restart Claude Code, then use `/skills` to list or let Claude auto-load it when a task matches.

### Any other agent harness

Copy or symlink the skill folder into your harness's skills directory per the [Agent Skills spec](https://agentskills.io) (e.g. `~/.agents/skills/`, `.agents/skills/`, `~/.claude/skills/`). The `skills/` directory in this repo contains ready-to-use skill folders.

## Updating

- **pi**: `pi update --all`
- **Claude Code**: `git pull` in the clone, then re-run `install-claude.sh` (symlinks stay valid)

## License

MIT — see [LICENSE.md](LICENSE.md). No warranty: use at your own risk. Free to use, modify, and redistribute (even commercially); attribution appreciated but not required.
