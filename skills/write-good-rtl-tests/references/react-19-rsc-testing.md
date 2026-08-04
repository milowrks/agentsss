# React 19-Era Server Component Testing Patterns

Research-backed supplement (React 19 stable): how to test React Server Components (RSC) without violating the guiding principles — and when to eject from RTL entirely.

## Reality check: why RSC unit testing is different

Stable React 19's **client renderer (`react-dom/client`) does not support async function components** — they only work with server renderers. React Testing Library renders through `react-dom/client`, so `render(<Page />)` where `Page` is `async` fails on stable React 19. React's stable releases also warn: *"async/await is not yet supported in Client Components, only Server Components."*

There is **no first-class RSC support in RTL** (open issue: testing-library/react-testing-library#1209; the `renderAsync` PR was not merged). RSC runs in a **Node server environment**, client code in a **jsdom/browser environment**, and no test runner yet runs both environments with correct export conditions in a single test. A key feature of RSC is that `server-only` and `client-only` can be mutually exclusive environments — jsdom `render()` cannot faithfully simulate that boundary.

**Consequence:** forcing an RSC into a jsdom unit test requires fighting the framework — mocking React internals, hiding warnings, stubbing environment checks. That is testing the framework's implementation details, not the user experience. It produces false positives and false negatives (see guiding-principles.md). **Don't do it.**

## The decision guide (this is the skill's policy)

1. **Pure RSC data/output that's easy to test** → Pattern A (await-and-render) or Pattern B (static markup), below.
2. **RSC that can't be tested easily, or anything framework-integrated** — layouts, server actions, streaming, routing, auth, cache invalidation, middleware → **Eject from RTL. Write E2E tests (Playwright/Cypress).** This is a feature, not a failure: E2E tests the real user experience across the server/client boundary, which is exactly what these features are.
3. **Never mock complex React/framework internals to test RSC** — no stubbing `react-dom` internals, reconciler behavior, `React.cache`, suspense plumbing, or framework magic. If a test requires that, eject to E2E. (Expo's `jest-expo/rsc` is the only sanctioned exception: it provides a real server-side RSC renderer and `toMatchFlight` matchers as a framework feature — not a hack.)

Match the layer to the tool:

| What you're testing | Tool |
|---|---|
| RSC shell: async data fetching → rendered output | Pattern A or B (or E2E) |
| Interactive client components (events, state, effects) | RTL unit tests |
| Server actions, layouts, streaming, auth, router integration | E2E |

## React 19 changes that matter for tests

- `act` is now exported from **`react`** (`await act(async () => ...)`). `react-dom/test-utils` is legacy. RTL's own helpers are already act-wrapped — you rarely need `act` yourself.
- `global.IS_REACT_ACT_ENVIRONMENT = true` is required for `act` in raw setups — RTL sets it for you.
- New static APIs `prerender` / `prerenderToNodeStream` wait for all data before returning HTML — better than legacy `renderToString` for RSC with awaited data.
- New client features to test the RTL way: Actions, `useActionState`, `useOptimistic`, `useFormStatus`, `<form action={...}>`, `<Context>` as provider, `ref` as prop. All are client-renderable → test with normal RTL patterns (render, user-event, jest-dom).
- `@testing-library/react` **v16+** is required for React 19.
- `use(promise)` in client components suspends — wrap in `<Suspense>` in your test tree and `await screen.findBy*` for the resolved content.

## Pattern A — await-and-render (preferred for pure RSC unit tests)

An async Server Component is just an async function returning JSX. Call it directly and hand the resolved element tree to RTL:

```tsx
// page.tsx — a server component
export default async function Page({params}: {params: {id: string}}) {
  const post = await fetchPost(params.id)   // runs in Node during the await
  return <article><h1>{post.title}</h1><p>{post.body}</p></article>
}
```

```tsx
// page.test.tsx
import {render, screen} from '@testing-library/react'
import Page from './page'

it('renders the post', async () => {
  // ✅ call the async component as a function, await it, render the result
  render(await Page({params: {id: '1'}}))

  expect(screen.getByRole('heading', {name: /hello world/i})).toBeInTheDocument()
  expect(screen.getByText(/body text/i)).toBeInTheDocument()
})
```

Notes:
- Set up data mocks **before** the `await Page(...)` call — data fetching happens during that call, not after render. Use MSW (`setupServer`) or mocked fetch; both work normally.
- The resolved tree may contain client-component references; those render through RTL's normal pipeline.
- TypeScript: `@types/react` supports async components as JSX since TS 5.1.
- If a nested async component/`use(promise)` is involved, wrap in `<Suspense>` + `await findBy*`.

## Pattern B — static markup + @testing-library/dom (SSR output assertions)

Render the tree to static HTML on the server and assert on the HTML with DOM Testing Library. Good for asserting the SSR shell / what the user sees before hydration. No interactions possible (static HTML has no event handlers).

```tsx
import {renderToStaticMarkup} from 'react-dom/server'   // or prerender() to wait for all data
import {screen} from '@testing-library/dom'

it('server-renders the page shell', async () => {
  const html = renderToStaticMarkup(<Page params={{id: '1'}} />)
  document.body.innerHTML = html

  expect(screen.getByRole('heading', {name: /hello world/i})).toBeInTheDocument()
})
```

- Use `prerender` / `prerenderToNodeStream` (from `react-dom/static`) when the tree awaits data: they wait for everything to load and return static HTML.
- Queries still follow the priority guide — `getByRole`, `getByText`, etc.
- You need a DOM environment (jsdom) in this test file for `@testing-library/dom`.

## Mocking the environment boundary

- **`server-only` imports**: RSC often imports `server-only` to guard against client use, which throws in jsdom tests.
  ```js
  // Vitest
  vi.mock('server-only', () => ({}))
  // Jest
  jest.mock('server-only')
  ```
  For Jest, an empty `__mocks__/server-only.js` also works. This is mocking a guardrail module, not React internals — acceptable.
- **Framework modules** (`next/navigation`, `next/headers`, `@remix-run/...`, etc.): mock narrowly what your component uses (e.g. `vi.mock('next/navigation', () => ({useRouter: () => ({push: vi.fn()})}))`). If the surface gets large, that's a signal to eject to E2E.
- **Data**: MSW (`setupServer`) for HTTP; mock at the API boundary, never the component's internal data plumbing.

## What not to do (review checks)

- ❌ No `<Suspense><Page/></Suspense>` + `findBy*` workaround on stable React 19 — that relied on removed canary/RC client behavior. (It worked on 18.3 canary / 19 RC only.)
- ❌ No stubbing `react-dom/server` output, `React.cache`, reconciler behavior, or framework internals to make an RSC render in jsdom.
- ❌ No `render(await ...)` hacks that hide warnings with console mocks to cover up environment mismatches — if warnings appear, the pattern is wrong for the environment.
- ❌ Don't use `react-test-renderer` — deprecated in React 19.
- ❌ Don't snapshot RSC Flight streams unless your framework provides first-class matchers (Expo's `toMatchFlight`).

## Sources
- https://github.com/testing-library/react-testing-library/issues/1209 (status + workarounds, incl. React team input)
- https://testing-library.com/docs/react-testing-library/setup/ (custom render)
- https://react.dev/reference/react/act , https://react.dev/reference/react-dom/server , https://react.dev/blog/2024/12/05/react-19
- https://nextjs.org/docs/app/building-your-application/testing (recommends E2E for async components)
- https://docs.expo.dev/guides/testing-rsc/ (Expo `jest-expo/rsc` + `toMatchFlight`)
