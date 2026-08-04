# Common Mistakes with React Testing Library

From https://kentcdodds.com/blog/common-mistakes-with-react-testing-library, with the "importance" tags preserved (high = definitely listen, medium = will bite you, low = mostly opinion).

## High importance

### Using the wrong assertion
```jsx
const button = screen.getByRole('button', {name: /disabled button/i})
// ❌ expect(button.disabled).toBe(true)  →  useless error output
// ✅
expect(button).toBeDisabled()
```
Install and use `@testing-library/jest-dom`. Error messages include the offending DOM element.

### Using the wrong query
```jsx
// DOM: <label>Username</label><input data-testid="username" />
// ❌ screen.getByTestId('username')
// ✅ screen.getByRole('textbox', {name: /username/i})
```
Follow the query priority guide. Also sub-rules:

- **No `container.querySelector`**: `container.querySelector('.btn-primary')` breaks on class changes and tests nothing users perceive. Use `screen.getByRole('button', {name: /click me/i})`.
- **Query by visible text, not testIDs everywhere**: `getByTestId('submit-button')` → `getByRole('button', {name: /submit/i})`. Content-writer changes to "Submit" → "Send" are real changes you want to know about. (Not everyone agrees; see Kent's tweet thread. Default: text over testIDs.)
- **Use `*ByRole` most of the time**: the `name` option matches the accessible name, which works even when text is split across elements:
  ```jsx
  // <button><span>Hello</span> <span>World</span></button>
  screen.getByText(/hello world/i) // ❌ fails — text split across elements
  screen.getByRole('button', {name: /hello world/i}) // ✅ works
  ```
  Failed role queries also dump all available roles, which is a great debugging aid.

### Adding `aria-`/`role`/other accessibility attributes incorrectly
```jsx
// ❌ render(<button role="button">Click me</button>)
// ✅ render(<button>Click me</button>)
```
Implicit roles exist for semantic HTML. Adding redundant/incorrect ARIA confuses screen readers. Use ARIA only when semantic HTML doesn't satisfy the use case (e.g., autocomplete), and then follow WAI-ARIA patterns or use an established library. Note: inputs get a role only if you set `type`.

### Only use `query*` variants for checking non-existence
```jsx
// ❌ expect(screen.queryByRole('alert')).toBeInTheDocument()
// ✅ expect(screen.getByRole('alert')).toBeInTheDocument()
//    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
```
`query*` exists only so a missing element doesn't throw. `get*`/`find*` throw with the full DOM printed — hugely helpful. `queryBy*` + `toBeInTheDocument` just says "null isn't in the document."

### Using `waitFor` to wait for elements that `find*` already covers
```jsx
// ❌ const button = await waitFor(() => screen.getByRole('button', {name: /submit/i}))
// ✅ const button = await screen.findByRole('button', {name: /submit/i})
```
Equivalent, but `findBy` is simpler with better error messages.

### Passing an empty callback to `waitFor`
```jsx
// ❌ await waitFor(() => {})
//    expect(window.fetch).toHaveBeenCalledWith('foo')
// ✅ await waitFor(() => expect(window.fetch).toHaveBeenCalledWith('foo'))
//    expect(window.fetch).toHaveBeenCalledTimes(1)
```
`waitFor` should wait for a specific thing. Empty callbacks create fragile tests.

### Performing side-effects in `waitFor`
```jsx
// ❌ await waitFor(() => {
//      fireEvent.keyDown(input, {key: 'ArrowDown'})
//      expect(screen.getAllByRole('listitem')).toHaveLength(3)
//    })
// ✅ fireEvent.keyDown(input, {key: 'ArrowDown'})
//    await waitFor(() => expect(screen.getAllByRole('listitem')).toHaveLength(3))
```
The `waitFor` callback runs a non-deterministic number of times — side-effects would run repeatedly. No snapshot assertions inside `waitFor` either.

## Medium importance

### Not using the ESLint plugins
Install `eslint-plugin-testing-library` and `eslint-plugin-jest-dom`. They encode most of the rules on this page.

### Using `wrapper` as the variable name for the render result
```jsx
// ❌ const wrapper = render(<Example prop="1" />)
// ✅ const {rerender} = render(<Example prop="1" />)  // or const view = render(...)
```
`wrapper` is enzyme cruft; RTL's result is a collection of utilities.

### Using `cleanup`
```jsx
// ❌ import {render, screen, cleanup} from '@testing-library/react'
//    afterEach(cleanup)
// ✅ import {render, screen} from '@testing-library/react'
```
Auto-cleanup has been built in for most major frameworks for years. Don't call it.

### Not using `screen`
```jsx
// ❌ const {getByRole} = render(<Example />)
//    getByRole('alert')
// ✅ render(<Example />)
//    screen.getByRole('alert')
```
`screen` queries `document.body`; no stale destructures as you add/remove queries. Exception: custom `container`/`baseElement`, which you should avoid anyway.

### Wrapping things in `act` unnecessarily
```jsx
// ❌ act(() => { render(<Example />) })
// ✅ render(<Example />)
```
`render` and `fireEvent` are already wrapped in `act`. Extra wrapping does nothing. An `act` warning is a signal that something unexpected is happening in your test — investigate (see Kent's "Fix the 'not wrapped in act(...)' warning"), don't silence.

### Not using `@testing-library/user-event`
```jsx
// ❌ fireEvent.change(input, {target: {value: 'hello world'}})
// ✅ userEvent.type(input, 'hello world')
```
`userEvent` fires the full event sequence (keydown, keypress, keyup per character) and works with libraries that don't listen for `change`. Prefer it wherever possible.

## Low importance

### Multiple assertions in a single `waitFor` callback
```jsx
// ❌ await waitFor(() => {
//      expect(window.fetch).toHaveBeenCalledWith('foo')
//      expect(window.fetch).toHaveBeenCalledTimes(1)
//    })
// ✅ await waitFor(() => expect(window.fetch).toHaveBeenCalledWith('foo'))
//    expect(window.fetch).toHaveBeenCalledTimes(1)
```
One assertion in the callback lets `waitFor` succeed as soon as the state settles — fail fast.

### Using `get*` variants as assertions without an explicit matcher
```jsx
// screen.getByRole('alert', {name: /error/i})
// → expect(screen.getByRole('alert', {name: /error/i})).toBeInTheDocument()
```
`get*` throws on failure anyway, so it never false-passes — but the explicit assertion communicates intent to readers. Keep it explicit.

## Bonus: keep the DOM clean between tests

If you see cross-test bleed ("test bleeding"), the cause is usually leaked DOM or async work, not missing `cleanup`. RTL cleans up automatically; investigate leaked timers/intervals or unawaited promises instead of adding manual teardown.
