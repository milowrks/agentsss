# agentsss

A public collection of [pi](https://pi.dev) agent skills by [Milo Z.](https://www.npmjs.com/~milowrks) — MIT licensed.

## Skills

| Skill | Description |
|---|---|
| [`write-good-rtl-tests`](skills/write-good-rtl-tests/SKILL.md) | Write and review high-quality React unit tests with React Testing Library, including React 19-era patterns for React Server Components (RSC) and when to eject to E2E. |

## Installation

```bash
pi install git:github.com/<github-username>/agentsss
```

or add it to project settings (`.pi/settings.json`) so a whole team gets it:

```json
{
  "packages": ["git:github.com/<github-username>/agentsss"]
}
```

Then load a skill with `/skill:<name>` or let your agent discover it automatically when the task matches. Use `pi config` to enable/disable individual skills, and `pi update --all` to pull updates.

## License

MIT — see [LICENSE.md](LICENSE.md). No warranty: use at your own risk. Free to use, modify, and redistribute (even commercially); attribution appreciated but not required.
