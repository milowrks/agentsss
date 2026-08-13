# Changelog

All notable changes to this repository's skills, grouped by release tag. Versions follow [SemVer](https://semver.org/); format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [1.3.0] - 2026-08-13

### Added

- **`write-github-issue`** — the writing half of the issue workflow, pairing with `issue-kick-off`'s validation half. Built on an altitude test rather than a template: for any sentence, ask which document would have to change if it became false, and put it there. Encodes what that subtracts — no restatement of the product artefact above the issue, no file or API detail, no delivery narrative, no non-functional section (a slice-specific requirement is an acceptance-criteria row, a standing obligation is a principle to link), and no cross-reference table, since the tracker's own dependency edges and a document CLI's typed relations already carry them. Covers story, bug and spike shapes, and defers to a project's per-type templates and authorship ceilings where a spec CLI defines them.
- `write-github-issue/references/document-templates.md` — adaptable story, bug and spike templates in the intent-plus-guidance style a spec/document CLI reads, so a project's own shape lives in version control and the skill stays the judgement layer on top.

## [1.2.0] - 2026-08-10

### Added

- **`issue-kick-off`** — the step between "issue exists" and "agent starts building": validates the issue's context and acceptance criteria against the actual repo rather than against itself, resolves open questions by reading installed dependency source at the pinned version instead of relying on recall, classifies adjacent tracker work as blocking or merely relevant, and hands the human an architecture-level walkthrough to review the eventual build against. Uses `gh` by default, and defers to a project's spec/document CLI where one exists.

## [1.1.0] - 2026-08-08

### Added

- **`digest-large-pr`** — turns an oversized pull request into a reviewable plan: classifies every changed file as auxiliary or substantive (with promotion triggers for the config, fixture, migration, CI and lockfile changes that only look auxiliary), marks the auxiliary ones as viewed so they collapse out of the reviewer's file list, and opens a pending review for the human to continue — findings as inline comments on the lines they concern, and a reading guide as the review body carrying the architecture, the batch order and the keystone file. Submitted as `COMMENT`, never as an approval. Ships two `gh`-based helpers that paginate past the 100-file limit `gh pr view --json files` and the REST files endpoint silently truncate at.
- `requires:` frontmatter field for skills that shell out, and `scripts/` as a supported skill subdirectory alongside `references/`.

### Changed

- `install-claude.sh` is now `install.sh`, taking `--target <dir>` (or `AGENTSSS_TARGET`) and defaulting to `~/.claude/skills`. The installer was never Claude-specific beyond that path, and every other harness was previously told to symlink by hand. `install-claude.sh` remains as a wrapper for the default target.

### Fixed

- The installer refuses to link over a real directory. `ln -sfn` would otherwise nest the symlink inside it, silently producing a broken install for anyone who already had their own copy of a skill in the target.

## [1.0.0] - 2026-08-04

### Added

- **`write-good-rtl-tests`** — React unit-test guidance: Testing Library guiding principles, query priority, implementation-detail rules, common RTL mistakes, plus React 19-era React Server Component patterns and the eject-to-E2E policy.
- MIT license, pi package manifest, Claude Code install script, agent-agnostic structure (Agent Skills spec).
