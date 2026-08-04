---
name: write-good-rtl-tests
description: Write and review high-quality React unit tests using React Testing Library (RTL), @testing-library/jest-dom, and @testing-library/user-event. Encodes Testing Library's guiding principles, the official query-priority guide, and Kent C. Dodds' rules on implementation-detail testing and common RTL mistakes, plus React 19-era patterns for testing React Server Components (RSC) — including when to eject from RTL to end-to-end tests instead of mocking React internals. Use whenever writing, reviewing, or refactoring React component tests.
license: MIT
---

# Write Good RTL Tests

## The one principle

> The more your tests resemble the way your software is used, the more confidence they can give you.
> — Kent C. Dodds

Everything in this skill derives from that sentence. When in doubt, ask: **"What does the user see, hear, and do?"** Then test exactly that — nothing more.

The test's job is to answer one question: *does the software work for the user?* Not: *does my state field have the right name?* Not: *did my internal function get called?* If a test can't be written without knowing how the component is implemented, the test is wrong — not the component.

## Decision tree: which kind of test to write

1. **Interactive client component** (state, effects, events, hooks) → RTL unit test in jsdom: `render`, `user-event`, jest-dom. This is the heart of the skill.
2. **React Server Component / async component** → try a React 19-era RSC pattern first (see [references/react-19-rsc-testing.md](references/react-19-rsc-testing.md)): **await-and-render** (`render(await Page(props))`) or **static markup** (`renderToStaticMarkup` / `prerender` + `@testing-library/dom`).
3. **RSC that cannot be tested easily, or anything framework-integrated** (layouts, server actions, streaming, routing, auth, data-cache invalidation) → **eject from RTL to end-to-end tests** (Playwright/Cypress). This is a feature, not a failure: E2E tests the real user experience across the server/client boundary.
4. **Never mock complex React internals** (reconciler, `react-dom` internals, `React.cache`, suspense plumbing, or framework internals) to force an RSC into a jsdom test. If a test needs that, you are testing implementation details of the framework instead of the user experience. Eject to E2E instead.

## Hard rules (each is a review check)

### Queries — in this priority order (from the official guide)
1. `getByRole` with the `name` option — top preference, tests the accessibility tree. Can't find it? Your UI may be inaccessible.
2. `getByLabelText` — form fields (labels are how users find inputs).
3. `getByPlaceholderText` — only if there's no label (placeholder is not a substitute for a label).
4. `getByText` — non-interactive content.
5. `getByDisplayValue` — filled-in form values.
6. `getByAltText` / `getByTitle` — semantic but inconsistently exposed.
7. `getByTestId` — last resort only (dynamic text, or no sensible role/text). TestIDs are invisible to users.

Other query rules:
- Prefer regex over `{exact: false}` for fuzzy matching (`/hello world/i`).
- Use `findBy*` whenever the element may not be there immediately (async). `findBy` = `getBy` + `waitFor`.
- Use `queryBy*` **only** to assert non-existence (`expect(screen.queryByText('x')).not.toBeInTheDocument()`). Never use `queryBy*` for existence — `getBy*`/`findBy*` throw descriptive errors that print the DOM; `queryBy*` returns null and `toBeInTheDocument` will just say "null isn't in the document".
- Prefer `getByRole('button', {name: /submit/i})` even when text is split across child elements (accessible-name matching handles it; `getByText` fails on split text).
- Never query with `container.querySelector`, classes, or ids. If you must fall back, use a `data-testid` to make the non-semantic intent explicit.

### Implementation details — never
- No `wrapper.state()`, `wrapper.instance()`, component internals, or internal helper calls. (Those are enzyme patterns; RTL doesn't even expose them.)
- No asserting on how state is stored (`openIndex` vs `openIndexes` vs `tacosAreTasty`) — assert on what renders.
- No `mockedInternalFn.toHaveBeenCalled()` when the observable outcome is renderable. If a call matters, assert its user-visible effect.
- Don't add a third user ("the tests") that app code must cater to. End-users (rendered output) and developers (props) are the only users.

### Assertions
- Use `@testing-library/jest-dom` matchers: `toBeDisabled()`, `toBeInTheDocument()`, `toHaveTextContent()`, `toHaveValue()`, etc. Error messages are dramatically better than raw property asserts (`expect(button.disabled).toBe(true)` fails with useless output).
- Make existence assertions explicit: `expect(screen.getByRole('alert')).toBeInTheDocument()` — communicate intent to readers.

### Interactions
- Use `@testing-library/user-event` (`userEvent.type`, `userEvent.click`, `userEvent.keyboard`) over `fireEvent`. `fireEvent.change` fires one event; `userEvent.type` fires keydown/keypress/keyup per character — it resembles real usage and works with libraries that ignore `change`.
- `render`, `userEvent`, and `fireEvent` are already wrapped in `act`. Don't add your own `act(() => ...)` around them. An `act` warning means something unexpected is happening — investigate, don't silence. (React 19: if you genuinely need it, `await act(async () => ...)` from `react`.)

### Async (`waitFor`)
- Don't pass an empty callback (`await waitFor(() => {})`) — wait for a specific assertion.
- Put only one assertion inside the `waitFor` callback; put extra assertions after it (fail fast, and the callback may run many times).
- No side-effects (events, DOM writes) inside `waitFor` — the callback may run non-deterministically many times. Fire the event first, then `waitFor` the assertion.
- No snapshot assertions inside `waitFor`.

### Hygiene
- Use `screen` for all queries (`screen.getByRole(...)`) — no destructuring from `render`, no stale destructure updates.
- Don't call `cleanup()` manually — RTL auto-cleans.
- Don't name the render result `wrapper` — it's not an enzyme wrapper. Use `const view = render(...)` or destructure.
- Don't add unnecessary `aria-*`/`role` attributes just to make queries pass. Use semantic HTML (`<button>`, `<input type="text">`); add ARIA only when semantic HTML genuinely can't express the pattern (e.g., autocomplete).
- Query by visible text (default locale), not testIDs everywhere — content changes are real changes you want to know about.
- Install and heed `eslint-plugin-testing-library` and `eslint-plugin-jest-dom` — they encode most of these rules.

## Writing the test: structure

```
Arrange  → render the component with realistic props (use real wrappers: providers, router, etc.)
Act      → userEvent interactions (type, click, keyboard)
Assert   → jest-dom assertions on the user-visible result; await findBy* for async
```

- Test behavior, not scenarios: one test per user-visible behavior ("can open accordion items to see the contents"), not one test per method.
- A good test passes whether state is named `openIndex`, `openIndexes`, or `tacosAreTasty`, and fails if the click handler is wired to the wrong button. That is the target.
- Mock at the boundaries you don't own: API calls (MSW or fetch mocks), not internals you do own.
- Providers/wrappers that all tests need → a custom `render` in `test-utils.tsx` (re-export RTL, override `render` with a `wrapper`). Do this for theme, i18n, router, etc.

## React 19 + React Server Components

See [references/react-19-rsc-testing.md](references/react-19-rsc-testing.md) for the full patterns. Summary:

- Stable React 19's **client renderer does not support async components**; RTL has no first-class RSC support yet. RSC runs in a Node environment — jsdom `render()` is the wrong environment for it.
- **Pattern A — await-and-render**: `render(await Page(props))`. Works for pure RSC unit tests: call the async component as a function, pass the resolved element tree to RTL.
- **Pattern B — static markup**: `renderToStaticMarkup(<App/>)` (or `prerender` for data loading) then assert on the HTML with `@testing-library/dom`'s `screen`. No interactions (static HTML has no handlers) — assert on what users will see.
- Mock `server-only` where needed: `vi.mock('server-only', () => ({}))` / `jest.mock('server-only')`.
- Anything framework-integrated (layouts, server actions, streaming, auth) → **E2E**. Never mock React/framework internals to make an RSC render in jsdom.

## Read these references for details
- [references/guiding-principles.md](references/guiding-principles.md) — the guiding principles and the implementation-details argument (false positives/negatives) with the classic accordion example.
- [references/common-mistakes.md](references/common-mistakes.md) — every common mistake with before/after examples and importance levels.
- [references/react-19-rsc-testing.md](references/react-19-rsc-testing.md) — React 19 testing changes, RSC patterns, mocking guidance, and the eject-to-E2E decision guide.

## Sources
- https://testing-library.com/docs/guiding-principles
- https://testing-library.com/docs/queries/about/#priority
- https://kentcdodds.com/blog/testing-implementation-details
- https://kentcdodds.com/blog/common-mistakes-with-react-testing-library
- https://github.com/testing-library/react-testing-library/issues/1209 (RSC support status)
- https://react.dev/reference/react/act and https://react.dev/reference/react-dom/server
