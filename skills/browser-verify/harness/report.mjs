// Prints the run's results as a markdown table: one row per plan step, one column per browser.
import fs from 'node:fs';
import path from 'node:path';

const results = JSON.parse(fs.readFileSync(path.join(import.meta.dirname, 'results.json'), 'utf8'));
const engines = ['chromium', 'webkit', 'firefox'].filter((e) => results.some((r) => r.engine === e));
const label = { chromium: 'Chromium', webkit: 'WebKit (Safari)', firefox: 'Firefox' };
const steps = [...new Map(results.map((r) => [r.step, r.title])).entries()].sort((a, b) => a[0] - b[0]);

// A step that ran in one browser only (a Studio step, say) doesn't apply to the others.
const ranIn = (n) => new Set(results.filter((r) => r.step === n).map((r) => r.engine)).size;

const cell = (rs, n) =>
  rs.length === 0
    ? ranIn(n) === 1 ? 'n/a' : 'not run'
    : rs
        .map((r) => {
          const text = [r.variant, r.status].filter(Boolean).join(' ');
          return r.screenshot ? `[${text}](${encodeURI(r.screenshot)})` : text;
        })
        .join('<br>');

const lines = [
  `| Step | ${engines.map((e) => label[e]).join(' | ')} |`,
  `| --- | ${engines.map(() => '---').join(' | ')} |`,
  ...steps.map(
    ([n, title]) => `| ${n}. ${title} | ${engines.map((e) => cell(results.filter((r) => r.step === n && r.engine === e), n)).join(' | ')} |`,
  ),
];

const problems = results.filter((r) => r.status !== 'pass' || r.note);
if (problems.length) {
  lines.push('', '**Failures and notes**', '');
  for (const r of problems) {
    lines.push(`- Step ${r.step}, ${label[r.engine]}${r.variant ? ` (${r.variant})` : ''}: ${r.status}.${r.note ? ` ${r.note}.` : ''}`);
    if (r.error) lines.push('', '  ```', ...r.error.split('\n').slice(0, 8).map((l) => `  ${l}`), '  ```');
  }
}

console.log(lines.join('\n'));
