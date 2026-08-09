# Changelog

All notable changes to this repository's skills, grouped by release tag. Versions follow [SemVer](https://semver.org/); format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [1.2.0] - 2026-08-10

### Added

- **`issue-kick-off`** — the step between "issue exists" and "agent starts building": validates the issue's context and acceptance criteria against the actual repo rather than against itself, resolves open questions by reading installed dependency source at the pinned version instead of relying on recall, classifies adjacent tracker work as blocking or merely relevant, and hands the human an architecture-level walkthrough to review the eventual build against. Uses `gh` by default, and defers to a project's spec/document CLI where one exists.

## [1.1.0] - 2026-08-08

### Added

- **`digest-large-pr`** — turns an oversized pull request into a reviewable plan: classifies every changed file as auxiliary or substantive (with promotion triggers for the config, fixture, migration, CI and lockfile changes that only look auxiliary), marks the auxiliary ones as viewed so they collapse out of the reviewer's file list, and posts a reading guide comment with the architecture and an ordered set of review batches. Ships two `gh`-based helpers that paginate past the 100-file limit `gh pr view --json files` and the REST files endpoint silently truncate at.
- `requires:` frontmatter field for skills that shell out, and `scripts/` as a supported skill subdirectory alongside `references/`.

## [1.0.0] - 2026-08-04

### Added

- **`write-good-rtl-tests`** — React unit-test guidance: Testing Library guiding principles, query priority, implementation-detail rules, common RTL mistakes, plus React 19-era React Server Component patterns and the eject-to-E2E policy.
- MIT license, pi package manifest, Claude Code install script, agent-agnostic structure (Agent Skills spec).
