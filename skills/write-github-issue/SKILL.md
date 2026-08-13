---
name: write-github-issue
description: 'Use when writing, drafting, grooming or reviewing the body of a GitHub issue -- a story, spike or bug an agent or a person will build from. Specifies observable behaviour at an altitude an implementer can build against and a reviewer can check, rather than restating the product tracker above it or pre-empting the implementation below it. Triggers on "write the issue", "draft a story", "groom this ticket", "write up this bug", "review this issue body", "is this issue written well".'
license: MIT
compatibility: pi, claude-code, any agent-skills-compatible harness
requires: gh (authenticated, repo scope) -- optionally a spec/document CLI such as lazyspec, see "If your project has a document tool"
metadata:
  author: Milo Z.
  version: "1.0.0"
  status: stable
---

# Write GitHub Issue

```
SPECIFY THE BEHAVIOUR, NOT THE IMPLEMENTATION
```

An issue is the **starting context** for building, not the answer. It says what must become true and roughly how, at an altitude an implementer can build against and a reviewer can check. What it must not do is restate the product artefact above it, or pre-empt the implementation below it.

Two modes, same rules: **write** (draft or groom a body) and **review** (check a body and report what breaks).

Before drafting, read the issue and its neighbours -- `gh issue view <n> --json number,title,body,labels,comments,state`, plus whatever the tracker above holds. Grooming an existing body is a visible mutation: show the proposed body and get a go-ahead first, unless the request already named that action.

## The altitude test

Most bad issues are not badly written, they are written at the wrong altitude. For any sentence you are about to include, ask **which document would have to change if it became false**:

| If it became false because… | Then it belongs to |
|:---|:---|
| the technology or approach changed | the implementation plan, PR or build doc |
| the product intent changed | the parent feature or requirement, in the product tracker |
| more than one issue would have to change | a decision record, design doc or engineering principle |
| only this slice's observable behaviour changed | **this issue** |

Applied honestly this is subtractive. Remove what the parent artefact says, what the standing decisions say, and what the build will say, and what remains is the issue: this slice's observable contract, the divergences an implementer would otherwise get wrong, and links to the rest.

**Do not assume the layers run from product down to implementation.** In practice a product artefact often names systems and named contracts, while the issue beneath it names what becomes observably true. Neither should name file paths or code identifiers. Where the artefact above does name one, treat it as a leak and do not copy it down.

**Do not duplicate the layer above.** Restating a parent's motivation, business logic, data sources or out-of-scope list creates a second copy that drifts, and the parent wins every disagreement. Link to it instead. The one thing worth checking before applying this strictly: whether the people building from the issue can actually reach that tracker. If they can -- and on most teams engineers and stakeholders share it -- there is no access argument for duplication.

## Four exclusions

1. **No delivery storytelling.** Never narrate what landed in which commit, what another ticket's out-of-scope list said, or how the issue came to be written. A link at the point it matters replaces all of it.
2. **No file-level or API-level detail.** No paths, no schema option names, no code identifiers in the spec sections. A well-written issue body often contains no backticks at all -- treat that as the bar, not a coincidence.
3. **Behaviour, not mechanism.** Specify the observable outcome. "The same video cannot appear twice in one record's list", not which validator enforces it.
4. **Name divergences from a neighbouring precedent.** If the adjacent field, sibling issue or nearby pattern would lead an implementer the wrong way, say so and say why. An agent copying the neighbour fails an acceptance criterion silently otherwise.

## Shape

A story:

```
As a <role>, I can <capability>, so that <outcome>.

## Goal
## Scope                  (only when the boundaries are contested)
## Context
## Proposed Implementation
### <named aspect>
## Acceptance Criteria     (Given/When/Then table)
## Test Plan
```

- **The `so that` clause** stays tied to what this slice makes possible next, not to the parent's business value. That clause is where a second copy of the parent creeps in.
- **Goal** states what becomes true in two or three sentences, and closes its own boundary in the last one -- "Nothing renders it."
- **Proposed Implementation** splits into named aspects, a noun phrase per part of the system ("The field", "The read side"), so a reviewer holds one at a time.
- **Acceptance criteria** are one row per behaviour at definition-of-done altitude, not one per assertion. Include the negative and empty cases: nothing configured, publish still succeeds, an empty list rather than a missing field. Keep the table -- prose bullets read as discussion, and a table reads as a checklist.
- **Test Plan** is numbered steps, one per criterion or group, each ending in what to confirm. Every criterion needs a step.

For a **bug**, replace the story line and Goal with `## Observed behaviour` and `## Expected behaviour`, and omit Proposed Implementation entirely while the cause is unknown -- a guess there becomes the implementer's plan. A stack trace is evidence for a comment, not spec for the body.

For a **spike**, replace them with `## Question`, `## What a resolved answer looks like` and `## Approach`. The body holds the question and how it gets answered, never the answer: that lands in the design doc or decision record the body names, so the two cannot disagree about what was decided.

**No non-functional section.** A non-functional requirement specific to this slice is an acceptance-criteria row, because that is where a reviewer checks it. A standing obligation belongs to a principle or design doc -- link it where it bites and do not restate it. If a constraint cannot be written as a checkable row and is not already someone else's document, it is not yet a requirement.

**No cross-reference table.** Issue trackers already carry the edges: GitHub shows blocked-by, blocking and sub-issues in the sidebar, and a document CLI records typed relations. A hand-maintained citation list duplicates both and drifts from both. Instead reference an artefact **inline, as a link, only where it changes how a reader understands that sentence** -- the design doc holding the question this slice answers, the issue that landed the thing it extends, the sibling whose opposite behaviour would mislead. Issues auto-link by number (`#403`). A repo document needs an absolute blob URL, because relative links do not resolve from an issue body. Record the relation whether or not the prose mentions it, so the graph stays complete where the text is silent.

## Voice

- Plain declarative present tense. Match the project's spelling convention.
- Justify inline and briefly, in the same sentence or the next: "Optional, because records already exist without it."
- State the negative explicitly -- what is *not* offered, *not* rendered, *not* falling back.
- Aphorisms that carry a rule are welcome: "a library is only a library if its assets are made in one place".
- No named individuals, no business-pitch framing. Technical vocabulary only where plain English would be vague or wrong.
- A long em-dash sentence and a dense paragraph describing a multi-step flow both fail. Use a list.

## Length

Two to five minutes for a human reviewer, roughly 650-1000 words. Tables scan fast and cost less than the same content as prose. Plain behavioural language runs longer than schema shorthand; that trade is intended -- spend the words on specification, not narrative.

## If your project has a document tool

Some repos front the tracker with a spec/document CLI (lazyspec and similar) that models issues as documents with typed relations. Where one exists it is the source of truth and the GitHub issue is its projection, so read and write through the tool. Three things to check before writing:

- **The type's template.** These tools support a per-type template carrying the section skeleton plus intent and per-section guidance. That is where a project's own shape belongs -- version-controlled and shared -- and this skill is the judgement layer on top. Read the template for the type in hand rather than assuming the shape above. `references/document-templates.md` has adaptable story, bug and spike templates in that style.
- **The authorship ceiling.** A type may be configured as human-authored, which means an agent may create and link the document but must hand the body back rather than write it. Read the ceiling before drafting and propose prose in chat when it says human.
- **Prose only on update.** These tools separate body from frontmatter and re-serialize frontmatter themselves. Passing the frontmatter block back inside a new body duplicates it. Never hand-edit the managed file, even though it looks like ordinary Markdown.

Worked example, lazyspec:

```bash
lazyspec config --json                    # a type's intent, authorship ceiling, parent type
lazyspec show <id> --json                 # body, comments, related, status as separate fields
lazyspec context <id> --json              # the parent/related chain, not just the leaf
lazyspec update <id> --body-file <path>   # prose only, no frontmatter block
lazyspec link <from> <rel-type> <to>      # relations, in place of a citation table
```

## Review output

Check the body against the type's template, if there is one, and the rules above. Report what is missing, what sits at the wrong altitude (mechanism where behaviour belongs, or the parent artefact restated), which references are decorative rather than load-bearing, which acceptance criteria are assertions rather than behaviours, and which test-plan steps have no criterion -- or criteria with no step. Give a verdict, then the specific fixes. Do not rewrite the body unless asked.
