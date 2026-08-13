# Document templates

Adaptable per-type templates for a spec/document CLI that supports them (lazyspec and similar). Drop them in the tool's template directory named for the type — for lazyspec that is `.lazyspec/templates/{story,bug,spike}.md`, alongside the generic fallback.

Two conventions these rely on, both lazyspec's and common to tools of this kind:

- An `intent:` comment at the top of the body states what documents of this type are for. Agents read it.
- A `guidance:` comment under a heading describes what belongs in that section.
- `{title}`, `{author}`, `{date}` and `{type}` are substituted at creation.

They are HTML comments, so they render invisibly and can stay in place while a draft is written.

Adapt the frontmatter block to whatever your tool writes — copy it from the generic template already in the directory rather than from here, since the field set is tool-specific. The bodies below are the part worth taking.

Two things to change for your project. Replace *the parent feature* with whatever your product tracker calls the layer above an issue (feature, requirement, epic). Replace *the iteration* with whatever holds your implementation plan (an iteration document, a design doc, the PR itself). If a formatter runs over your repo's Markdown, exclude the template directory — `{type}` and `{date}` get mangled otherwise.

## story.md

```md
<!-- intent: specify one vertical slice of value as observable behaviour, at an altitude
     an implementer can build against and a reviewer can check. The implementation plan
     finds the implementation. Full house style: the write-github-issue skill. -->

<!-- altitude: for any sentence you are about to write, ask which document would have to
     change if it became false.

       the technology changed               -> the implementation plan owns it
       the product intent changed           -> the parent feature owns it
       more than one story would change     -> a decision record or principle owns it
       only this slice's behaviour changed  -> it belongs here

     The layers do not run from product down to implementation. The parent feature names
     systems and named contracts; this story names what becomes observably true. Neither
     names file paths or code identifiers. Where a feature does name one, treat it as a
     leak and do not copy it down. -->

As a <role>, I can <capability>, so that <outcome>.

<!-- guidance: name the actor and the capability of this slice. Keep "so that" tied to
     what this slice makes possible next, not to the feature's business value — that
     clause is where a second copy of the feature creeps in. -->

## Goal

<!-- guidance: what must become true, in two or three sentences. Close your own boundary
     in the last one ("Nothing renders it."). -->

## Context

<!-- guidance: only the background specific to this slice. No commit history, no narrative
     of how the ticket came to be.

     Never duplicate the parent feature. If the people building from this issue can open
     the tracker — and usually they can — restating its motivation, business logic, data
     sources or out-of-scope list buys nothing and creates a second copy to drift. Link to
     it instead. If a constraint applies to every slice under the feature, it stays in the
     feature.

     There is no cross-reference table. The edges are already recorded twice over: the
     document tool's relations for context assembly, and the tracker's own blocked-by /
     blocking / sub-issue edges for human sequencing. So reference an artefact inline, as a
     link, only where it changes how a reader understands that sentence. Issues auto-link
     by number; a repo document needs an absolute blob URL, because relative links do not
     resolve from an issue body. Record the relation whether or not the prose mentions it,
     so the graph stays complete. -->

## Proposed Implementation

<!-- guidance: the approach at behaviour altitude. Split into named aspects — a noun
     phrase per part of the system ("The field", "The read side") — so a reviewer holds
     one at a time. No file paths, no schema option names, no code identifiers. Justify
     inline and briefly ("Optional, because records already exist without it"). Where a
     neighbouring field or sibling story would lead an implementer the wrong way, say so
     and say why. -->

### <named aspect>

## Acceptance Criteria

<!-- guidance: one row per behaviour, at definition-of-done altitude — not one row per
     assertion. Keep the table; prose bullets read as discussion rather than a checklist.
     Include the negative and empty cases (nothing configured, publish still succeeds, an
     empty list rather than a missing field).

     Non-functional requirements land here too, as rows, when they are specific to this
     slice — a budget, a limit, a thing that must not regress. There is no separate
     non-functional section: a standing obligation belongs to a principle or design doc,
     linked where it bites. If a constraint cannot be written as a checkable row and is not
     already someone else's document, it is not yet a requirement. -->

| AC  | Given | When | Then |
| :-- | :---- | :--- | :--- |
| AC1 |       |      |      |

## Test Plan

<!-- guidance: numbered steps, one per AC or group of ACs, each ending in what to confirm.
     Every AC needs a step. -->

1.

<!-- Optional: add `## Scope` above `## Context` only when the boundaries are contested.
     Usually the Goal's closing sentence does the job. Target 650-1000 words, a 2-5
     minute read. Plain declarative present tense. -->
```

## bug.md

```md
<!-- intent: state one defect as the gap between observed and expected behaviour, at an
     altitude a reviewer can check. Diagnose only as far as is already known; the
     implementation plan finds the cause. Full house style: the write-github-issue skill. -->

<!-- altitude: for any sentence you are about to write, ask which document would have to
     change if it became false.

       the technology changed                -> the implementation plan owns it
       more than one issue would change      -> a decision record or principle owns it
       the behaviour was never wanted        -> it is a change of intent, not a bug
       only this defect's behaviour changed  -> it belongs here

     Name systems and observable behaviour, not file paths or code identifiers. A stack
     trace or a suspected line number is evidence for a comment, not spec for the body. -->

## Observed behaviour

<!-- guidance: what happens now, in the terms a user would describe it, plus where and
     when it reproduces. State it as behaviour, not as a stack trace. -->

## Expected behaviour

<!-- guidance: what should happen instead. Close the boundary: what this bug does not
     cover, where a related symptom is a separate ticket. -->

## Context

<!-- guidance: what an implementer without session history needs — when it started, how
     often, who is affected, which environment. No commit narrative.

     There is no cross-reference table. Reference an artefact inline, as a link, only where
     it changes how a reader understands that sentence — the issue that landed the broken
     behaviour, the sibling that would regress with the fix. Record the relation whether or
     not the prose mentions it, and let the tracker's own blocked-by and blocking edges
     carry the sequencing. -->

## Proposed Implementation

<!-- guidance: only when the cause is already known. Behaviour altitude, named aspects, no
     file paths or code identifiers. Omit the section entirely when the cause is still
     open — a guess here becomes the implementer's plan. -->

## Acceptance Criteria

<!-- guidance: one row per behaviour, at definition-of-done altitude. Include a row for the
     regression not returning, and rows for the neighbouring behaviour the fix must leave
     intact. -->

| AC  | Given | When | Then |
| :-- | :---- | :--- | :--- |
| AC1 |       |      |      |

## Test Plan

<!-- guidance: numbered steps, one per AC or group of ACs, each ending in what to confirm.
     Step 1 is normally reproducing the defect before the fix. -->

1.
```

## spike.md

```md
<!-- intent: state one question the team cannot answer yet, what a resolved answer looks
     like, and where the answer will be recorded. A spike produces a decision and its
     evidence, not shipped behaviour. Full house style: the write-github-issue skill. -->

<!-- altitude: for any sentence you are about to write, ask which document would have to
     change if it became false.

       the technology changed                     -> the implementation plan owns it
       the answer changed                         -> the design doc owns it, written after
       the product intent changed                 -> the parent feature owns it
       only the question or the approach changed  -> it belongs here

     A spike body holds the question and how it gets answered. It never holds the answer:
     that lands in the design doc or decision record named below, so the two cannot
     disagree about what was decided. Name systems and options, not file paths. -->

## Question

<!-- guidance: the question, in one or two sentences, phrased so it can be answered rather
     than explored indefinitely. Where it came from belongs in a link, not a paragraph. -->

## What a resolved answer looks like

<!-- guidance: the shape of the answer and where it lands — which document records it,
     which issues unblock. Close the boundary: what this spike will not settle. -->

## Context

<!-- guidance: the constraints that make the question hard and the options already on the
     table, enough that a reader can judge the answer when it arrives.

     There is no cross-reference table. Reference an artefact inline, as a link, only where
     it changes how a reader understands that sentence — above all the document the
     resolution lands in. Record the relation whether or not the prose mentions it. -->

## Approach

<!-- guidance: how the question gets answered — what will be read, built, measured or
     compared, and against which version. Name the options to be tested against each
     other. Time-box it here if it needs one. -->

## Acceptance Criteria

<!-- guidance: one row per question answered, at definition-of-done altitude. The answer is
     evidenced, not asserted, and recorded where this document says it lands. -->

| AC  | Given | When | Then |
| :-- | :---- | :--- | :--- |
| AC1 |       |      |      |

## Test Plan

<!-- guidance: numbered steps, one per AC, each ending in what to confirm. For a spike
     these are how each answer is evidenced — the command run, the source read, the two
     builds compared — so a reviewer can repeat it rather than take it on faith. -->

1.
```
