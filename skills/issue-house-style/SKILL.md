---
name: issue-house-style
description: Use when writing, drafting, grooming or reviewing the body of a GitHub issue (story, spike or bug) in the lazyspec planning graph. Carries the judgement the templates cannot — what to exclude, what altitude to write at, voice, length, and the review checklist. Triggers on "write the issue", "draft a story", "groom this ticket", "review this issue body", "does this issue match our style".
license: MIT
compatibility: pi, claude-code, any agent-skills-compatible harness
requires: gh (authenticated); written for lazyspec-managed repos, though the judgement rules apply to any issue tracker
metadata:
  author: Milo Z.
  version: "1.0.0"
  status: stable
---

# Issue House Style

```
SPECIFY THE BEHAVIOUR, NOT THE IMPLEMENTATION — CAUSE AND HISTORY GO IN COMMENTS
```

The issue is the **starting context** for the lazyspec document flow, not the answer. It says what must become true and roughly how, at an altitude an implementer can build against and a reviewer can check. The iteration and review cycle uncover the implementation.

## What lives where

Do not restate the section order here — read it from the graph, which is version-controlled and shared with the team:

- **Section skeleton and per-section guidance**: `.lazyspec/templates/<type>.md`, if the repo has one for the type in hand. Read it before drafting. Where there is none, go by the type's intent and this skill.
- **Type intent**: `lazyspec config --json` (the `intent` field on the type).
- **CLI mechanics** — create, link, update, authorship ceilings: the `lazyspec:scaffold` and `lazyspec:co-write` skills own these. Don't duplicate their steps; invoke them.
- **Reference body**: the project's accepted example issue, if its agent-instruction file (`AGENTS.md`, `CLAUDE.md` or equivalent) names one. Read it before anything substantial, always with `gh issue view <n> --repo <owner>/<name>` so a same-numbered issue in another repo can't stand in for it. Where there is none, the template and this skill are the bar.

This skill is the judgement layer on top of those: the rules a template comment is too small to hold.

## Authorship ceiling

Read each type's `authorship` from `lazyspec config --json`; it varies by repo (a common setup is `story` as `human`, and `bug` and `spike` as `assisted`). `human` means scaffold only, per lazyspec ADR-020. So for a `human` type:

- Create the shell and link it (`lazyspec:scaffold`), surface the template's intent and guidance, and **propose the body as prose in chat** for the human to edit and apply.
- Do **not** write the body with `lazyspec update --body` on your own initiative. The human applies the accepted draft.

For an `assisted` type, or one with no `authorship` set, `lazyspec:co-write` is permitted — interview first, propose, iterate, then apply.

**Exception:** when the human has said to create an issue related to the work in hand, create it in the team's grooming status without showing them the body first, if their agent instructions allow that. Meeting this skill is the bar, not their sign-off on the prose. This never applies to a `human` type.

Grooming an existing body of any type is a visible mutation: read it, show the proposed body, get an explicit go-ahead, unless the request already named that action.

Expect several rounds of this before the human stops: a draft that reads as finished will still have narration or cross-references worth cutting, and a further round of trims is normal, not a sign the first draft was bad. Keep proposing — don't treat an already-applied version as final until the human stops requesting cuts.

## Four exclusions

1. **No delivery storytelling.** Never narrate what landed in which commit, what another ticket's out-of-scope list said, or how the issue came to be written — including a story's own retconned history, such as why it was split from a sibling or why its scope moved. A "Scope" or "Context" section that explains a story's relationship to a sibling issue is this in disguise: it duplicates the `blocked-by`/`blocks`/`implements` relation the graph already carries. State the boundary as a fact about this slice's own behaviour, or cut it. A link-out at the point it matters replaces all of it.
2. **No file-level or API-level detail.** No paths, no schema option names, no code identifiers in the spec sections. A good reference body contains **zero backticks** — treat that as the bar, not a coincidence.
3. **Behaviour, not mechanism.** Specify the observable outcome. Say "the same video cannot appear twice in one record's list", not which validator enforces it.
4. **Name divergences from a neighbouring precedent.** If the adjacent field, sibling story or nearby pattern would lead an implementer the wrong way, say so and say why. An agent copying the neighbour fails an AC silently otherwise. This includes a new field's own shape: don't infer upload-vs-preset from how many example variants a linked design happens to show — that's what the design looked like at the time, not a constraint on the field. Check an existing precedent field of the same kind first, and ask if none exists.

## Altitude

For any sentence, ask **which document would have to change if it became false.** This extends the convention's own "mechanism splits by reversibility" rule down to the issue boundary.

| If it became false because… | Then it belongs to |
|:---|:---|
| the technology changed | the iteration |
| the product intent changed | the parent feature (in the feature tracker) |
| more than one issue would change | an RFC or a principle |
| only this slice's observable behaviour changed | **this issue** |

The layers do not run from product down to implementation. The parent feature names systems and named contracts (a CMS, a video host, a tag manager, "the shared listing projection"). The issue names what becomes observably true. Neither names file paths or code identifiers; where a feature does (a `Data sources` list on the feature card, say), treat it as a leak and don't copy it down.

**Never duplicate the feature tracker in GitHub.** Where developers and non-technical stakeholders share the feature tracker (ClickUp, Jira, Linear and so on), every reader can open the parent feature. Restating its motivation, business logic, data sources or out-of-scope list buys no access and creates a second copy to drift. Link to it. There is no audience argument for duplication here.

Then, section by section:

- **Goal / Observed–Expected** closes its own boundary in a short final sentence — "Nothing renders it."
- **A story body is the goal statement, ACs and Test Plan. No `## Scope` section**, even where the template suggests one for contested boundaries. A boundary that is real behaviour becomes an AC row: an excluded fallback is a row asserting it is not requested. A boundary that constrains more than this slice belongs to the RFC. Anything else was never load-bearing.
- **Observed behaviour holds observation only.** What introduced the defect, why it surfaces now, what it is *not*, and adjacent defects found alongside it all go in issue comments. The body is read as spec: a table of what is served where beats a paragraph describing it, and a section that opens with observation then drifts into cause fails even when every sentence is true. Don't fold a removed `## Context` section *into* Observed behaviour; that moves the narrative instead of removing it. The same goes for Proposed Implementation: keep the fix and the one real trade-off, and move design musing to a comment.
- **Proposed Implementation** splits into named aspects, a noun phrase per part of the system, so a reviewer holds one at a time. Omit it entirely on a bug whose cause is still open — a guess here becomes the implementer's plan.
- **Acceptance criteria** are one row per behaviour, not one per assertion. Include the negative and empty cases. The Given/When/Then **table** is the convention and is not optional; a draft that replaced it with prose bullets was rejected. Past eight rows, split the table into logical groups under `###` subheadings — a reader holds one aspect at a time. Numbering runs continuously across the groups, so the Test Plan's references stay stable when a group gains a row.
- **A small, scoped, known-how-to-implement gap is this issue's own AC, not an Open item or a blocked-on note.** Reserve "blocked on" framing for work that genuinely belongs to a different, already-identified issue, or that only someone else's decision can resolve. If the gap is a missing field or a short step with an obvious shape and no other owner — a schema field the rendering needs that nothing else is already landing — write the AC for it (add it, persist it, publish with it empty) and fold it into the Goal sentence, rather than a paragraph explaining why the story can't proceed.
- **Open items** name the behaviour they bear on when the item is "we already shipped a default, but it isn't confirmed" — not a free-floating question. Write "the listing criteria currently take the newest items, but that priority order is still open with the client" rather than stating the question in isolation; the altitude test above (which document changes if this becomes false) applies to Open items too.
- **No non-functional section.** A slice-specific non-functional requirement is an AC row, because that is where a reviewer checks it. A standing obligation belongs to a principle or an RFC — link to it where it bites and don't restate it.
- **The `so that` clause** stays tied to what this slice makes possible next, not to the feature's business value. That clause is where a second copy of the feature creeps in.
- **No Related artefacts section.** There is no cross-reference table and no citation list. The graph carries the edges in two places that are already load-bearing: `lazyspec link` records relations for context assembly, and GitHub's native blocked-by, blocking and sub-issue edges show humans the sequencing. Neither needs a prose copy, and a hand-maintained list drifts from both.
- **Reference an artefact inline, as a link, at the point it matters.** Only where it changes how a reader understands that sentence — the RFC holding the question this slice answers, the story that landed the thing it extends, the sibling whose opposite behaviour would mislead an implementer. Issues by number (`#123`) auto-link. Repo documents need an absolute blob URL, since relative links don't resolve from an issue body. Feature-tracker artefacts link to the card or task. Not a bibliography: if the link isn't earning its place in that sentence, the relation alone is enough. A section that narrates what a linked design already shows — its fields, its layout, which variant is out of scope — is redundant with the link itself: fold the link into the sentence it belongs to (often the Goal) instead of giving the design its own section, and leave a scope-boundary fact that's visible on the canvas for the design tool's own annotations to carry.
- **Test Plan** has a step for every AC, each ending in what to confirm, phrased as what a person does in the browser or the CMS — "set the block's heading, publish, view the page; confirm it shows as configured" — not as render-and-assert pseudocode. A step opening "Render the block with X set" is unit-test framing; rewrite it as the action a manual tester takes.

## Voice

- Plain declarative present tense, in the project's spelling convention.
- Justify inline and briefly, in the same sentence or the one after: "Optional, because records already exist without it."
- State the negative explicitly — what is *not* offered, *not* rendered, *not* falling back.
- Aphorisms that carry a rule are welcome: "a library is only a library if its assets are made in one place".
- No named individuals, no business-pitch framing, and no internal client-side process jargon — an internal ticketing label or triage category — describe the fact plainly instead. Technical vocabulary only where plain English would be vague or wrong.
- Long em-dash sentences and dense prose for a complex flow both fail — use a list.

## Length

2-5 minutes for a human reviewer, roughly 650-1000 words. Tables scan fast and cost less than the same content as prose. Plain behavioural language runs longer than schema shorthand; that trade is intended — spend the words on spec, not narrative.

## Known CLI traps

Two lazyspec behaviours (checked on 0.12) bite issue bodies most:

- `lazyspec link` on a GitHub-native edge can push a stale cache over the remote body. Run `lazyspec fetch` first, and again before the next `update`.
- `lazyspec update --title` never reaches GitHub. Set the title with `gh issue edit`.

## Review output

Check the body against the type's template and the rules above. Report: what is missing, what sits at the wrong altitude (mechanism where behaviour belongs), which sentences carry cause or history that belongs in a comment, which sections the house style excludes (Scope, Context, Non-functional, Related artefacts), which ACs are assertions rather than behaviours, and which Test Plan steps have no AC (or ACs with no step). Give a verdict, then the specific fixes. Don't rewrite the body unless asked.
