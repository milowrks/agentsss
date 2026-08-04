# Guiding Principles & Implementation Details

## The guiding principles (testing-library.com/docs/guiding-principles)

> The more your tests resemble the way your software is used, the more confidence they can give you.

Testing Library only exposes methods and utilities that encourage tests that closely resemble how web pages are used. The principles:

1. **Deal with DOM nodes, not component instances.** Utilities must never encourage dealing with component instances, state, or lifecycle.
2. **Generally useful for testing application components the way the user uses them.** Tests run on a computer in a simulated browser, but utilities should encourage using components the way they're intended to be used.
3. **Simple and flexible.** Lightweight, simple, understandable.

The user of your component is a person with a mouse/keyboard/touchscreen — and assistive technology. Query and interact the way they do.

## Implementation details (kentcdodds.com/blog/testing-implementation-details)

**Definition:** Implementation details are things which users of your code will not typically use, see, or even know about.

React components have two users:
- **End-users** — see/interact with what's rendered.
- **Developers** — see/interact with the props they pass.

A test should only see/interact with props (input) and rendered output. When a test reaches into state, instance methods, or internals, it creates a third user — **the tests** — that nobody cares about. App code must then be written to satisfy the tests, which is a complete waste of time.

### Why it's bad: false negatives and false positives

A test answers "does the software work?" If the test passes → positive (working software). If it fails → negative (broken software). *False* = incorrect result.

**False negative** — software works, test fails:
- You refactor an accordion from `openIndex` state to `openIndexes` (same behavior, different implementation).
- Test `expect(wrapper.state('openIndex')).toBe(0)` breaks. The app still works fine — the *test* is broken.
- Result: brittle tests that break "any time you so much as look at the code." This is the #1 reason people find testing distasteful.

**False positive** — software broken, test passes:
- Someone "optimizes" `<button onClick={() => this.setOpenIndex(index)}>` to `<button onClick={this.setOpenIndex}>` — a real bug (wrong argument) that breaks the app in production.
- The implementation-detail tests still pass because they call `setOpenIndex` directly and never verify the button is wired to it.
- Result: tests give false confidence; real bugs ship.

### The fix (from Kent's article, RTL rewrite)

```jsx
test('can open accordion items to see the contents', () => {
  const hats = {title: 'Favorite Hats', contents: 'Fedoras are classy'}
  const footware = {title: 'Favorite Footware', contents: 'Flipflops are the best'}
  render(<Accordion items={[hats, footware]} />)

  expect(screen.getByText(hats.contents)).toBeInTheDocument()
  expect(screen.queryByText(footware.contents)).not.toBeInTheDocument()

  userEvent.click(screen.getByText(footware.title))

  expect(screen.getByText(footware.contents)).toBeInTheDocument()
  expect(screen.queryByText(hats.contents)).not.toBeInTheDocument()
})
```

One test, all behavior verified, no implementation knowledge. It passes whether state is `openIndex`, `openIndexes`, or `tacosAreTasty` 🌮, and it fails if the click handler is wired incorrectly.

### Practical checklist — is this an implementation detail?

Ask: **who uses/sees/knows this?**

| Touchpoint | User | OK to test? |
|---|---|---|
| Rendered DOM (text, roles, values) | End-user | ✅ |
| Props passed in | Developer | ✅ |
| Component state | Nobody | ❌ |
| Instance methods | Nobody | ❌ |
| Internal helper functions | Nobody | ❌ |
| Whether a handler is inline vs. referenced | Nobody | ❌ |
| Framework internals (reconciler, cache, suspense plumbing) | Nobody | ❌ |

Related reading: Kent's "Avoid the Test User" essay expands on the same idea.
