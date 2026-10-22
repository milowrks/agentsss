import { test as base, expect, type Browser, type BrowserType, type Locator, type Page } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

export { expect };

export type Engine = 'chromium' | 'webkit' | 'firefox';
export type AfterSignIn = 'hide' | 'minimise' | 'keep';
type Status = 'pass' | 'fail' | 'blocked';
type Region = Locator | ((page: Page) => Locator);
type Viewport = { width: number; height: number };

export type StepResult = {
  step: number;
  title: string;
  engine: Engine;
  variant?: string;
  status: Status;
  screenshot?: string;
  note?: string;
  error?: string;
};

const engines = (process.env.QA_ENGINES?.split(',') ?? ['chromium', 'webkit', 'firefox']) as Engine[];
const afterSignIn = (process.env.QA_AFTER_SIGN_IN ?? 'hide') as AfterSignIn;
const resultsDir = path.resolve(__dirname, '..', 'Results');
const previousDir = path.join(__dirname, 'previous-run');
const debugDir = path.join(__dirname, 'debug');
const resultsFile = path.join(__dirname, 'results.json');
const ownShot = /^step\d+-(chromium|webkit|firefox)(-[\w-]+)?-(pass|fail)\.png$/;

class QA {
  readonly results: StepResult[] = [];
  private readonly launched = new Map<string, Browser>();

  constructor(private readonly pw: Record<Engine, BrowserType>) {
    fs.mkdirSync(resultsDir, { recursive: true });
    fs.rmSync(previousDir, { recursive: true, force: true });
    fs.rmSync(debugDir, { recursive: true, force: true });
    // Move the last run's captures aside so a stale fail can't sit next to a new pass.
    for (const name of fs.readdirSync(resultsDir).filter((n) => ownShot.test(n))) {
      fs.mkdirSync(previousDir, { recursive: true });
      fs.renameSync(path.join(resultsDir, name), path.join(previousDir, name));
    }
  }

  async signIn(
    engine: Engine,
    opts: { label: string; url: string; ready: (page: Page) => Locator; viewport?: Viewport; after?: AfterSignIn },
  ): Promise<Page> {
    const viewport = opts.viewport ?? { width: 1440, height: 900 };
    const browser = await this.launch(engine, false);
    const context = await browser.newContext({ viewport });
    const page = await context.newPage();
    await page.goto(opts.url);
    console.log(`\n[sign-in] ${engine}: sign in to ${opts.label} in the window that just opened. Waiting up to 15 minutes.\n`);
    await expect(opts.ready(page)).toBeVisible({ timeout: 15 * 60_000 });
    console.log(`[sign-in] ${engine}: signed in to ${opts.label}.`);

    const after = opts.after ?? afterSignIn;
    if (after === 'keep') return page;
    if (after === 'minimise') {
      await minimise(page);
      return page;
    }
    return this.moveToHidden(engine, page, viewport, opts);
  }

  // Copies the session in memory (cookies, localStorage, IndexedDB) to a headless browser and closes the window.
  private async moveToHidden(engine: Engine, page: Page, viewport: Viewport, opts: { label: string; ready: (page: Page) => Locator }) {
    const state = await page.context().storageState({ indexedDB: true });
    const url = page.url();
    const headed = page.context().browser()!;
    await page.context().close();
    await headed.close();
    this.launched.delete(`${engine}:false`);

    const hidden = await (await this.launch(engine, true)).newContext({ viewport, storageState: state });
    const next = await hidden.newPage();
    await next.goto(url);
    try {
      await expect(opts.ready(next)).toBeVisible({ timeout: 60_000 });
    } catch {
      throw new Error(
        `${opts.label} lost the sign-in when it moved to a hidden browser, so it probably keeps it somewhere storage state doesn't carry. Rerun with QA_AFTER_SIGN_IN=minimise or keep.`,
      );
    }
    console.log(`[sign-in] ${engine}: moved to a hidden browser and closed the window.`);
    return next;
  }

  async eachEngine(
    fn: (page: Page, engine: Engine) => Promise<void>,
    opts: { viewport?: Viewport; headless?: boolean } = {},
  ) {
    for (const engine of engines) {
      const browser = await this.launch(engine, opts.headless ?? !process.env.QA_HEADED);
      const context = await browser.newContext({ viewport: opts.viewport ?? { width: 1280, height: 800 } });
      try {
        await fn(await context.newPage(), engine);
      } finally {
        await context.close();
      }
    }
  }

  async step(
    n: number,
    title: string,
    opts: { page: Page; region: Region; frame?: Region | 'screen'; needs?: number | number[]; variant?: string },
    fn: () => Promise<void>,
  ) {
    const engine = engineOf(opts.page);
    const blocker = [opts.needs ?? []].flat().find((d) => !this.passed(d, engine));
    if (blocker !== undefined) {
      this.results.push({ step: n, title, engine, variant: opts.variant, status: 'blocked', note: `step ${blocker} did not pass` });
      return;
    }
    await test.step(`${n}. ${title} [${[engine, opts.variant].filter(Boolean).join(' ')}]`, async () => {
      let error: unknown;
      try {
        await fn();
      } catch (e) {
        error = e;
      }
      const status = error ? 'fail' : 'pass';
      const region = typeof opts.region === 'function' ? opts.region(opts.page) : opts.region;
      const frame = typeof opts.frame === 'function' ? opts.frame(opts.page) : (opts.frame ?? 'screen');
      const shot = await capture(opts.page, region, frame, shotName(n, engine, opts.variant, status), status);
      if (error) await dumpAria(opts.page, region, shotName(n, engine, opts.variant, 'fail').replace(/\.png$/, '.aria.yml'));
      this.results.push({ step: n, title, engine, variant: opts.variant, status, ...shot, error: error ? clean(error) : undefined });
    });
  }

  async close() {
    for (const browser of this.launched.values()) await browser.close().catch(() => {});
  }

  // A step that ran in this engine counts; otherwise one that ran elsewhere (e.g. a Studio step in Chromium only).
  private passed(step: number, engine: Engine) {
    const prior = this.results.filter((r) => r.step === step);
    const same = prior.filter((r) => r.engine === engine);
    const relevant = same.length ? same : prior;
    return relevant.length > 0 && relevant.every((r) => r.status === 'pass');
  }

  private async launch(engine: Engine, headless: boolean) {
    const key = `${engine}:${headless}`;
    let browser = this.launched.get(key);
    if (!browser) {
      browser = await this.pw[engine].launch({ headless });
      this.launched.set(key, browser);
    }
    return browser;
  }
}

async function minimise(page: Page) {
  if (engineOf(page) !== 'chromium') {
    console.log('[sign-in] only Chromium can minimise its own window, so this one stays open.');
    return;
  }
  const cdp = await page.context().newCDPSession(page);
  const { windowId } = await cdp.send('Browser.getWindowForTarget');
  await cdp.send('Browser.setWindowBounds', { windowId, bounds: { windowState: 'minimized' } });
  await cdp.detach();
  console.log('[sign-in] chromium: minimised the window to the Dock.');
}

function engineOf(page: Page): Engine {
  return page.context().browser()!.browserType().name() as Engine;
}

function shotName(n: number, engine: Engine, variant: string | undefined, status: Status) {
  return `step${n}-${[engine, variant, status].filter(Boolean).join('-')}.png`;
}

async function capture(page: Page, region: Locator, frame: Locator | 'screen', name: string, status: Status) {
  const file = path.join(resultsDir, name);
  const screenshot = name;
  const target = region.first();
  const colour = status === 'pass' ? '#1a7f37' : '#cf222e';
  const outline = `[data-qa-region]{outline:3px solid ${colour}!important;outline-offset:2px!important}`;
  const hide = '[data-qa-hide]{visibility:hidden!important}';
  const pad = 24;
  if (status === 'fail') {
    fs.mkdirSync(debugDir, { recursive: true });
    await page.screenshot({ path: path.join(debugDir, name.replace(/\.png$/, '.viewport.png')) }).catch(() => {});
  }
  try {
    await target.waitFor({ state: 'visible', timeout: 3000 });
    await target.evaluate((el) => el.setAttribute('data-qa-region', ''));
    if (frame === 'screen') {
      // Smooth-scrolling panes (Sanity Studio's) would still be moving when the box is read.
      await target.evaluate((el) => el.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' }));
      await page.screenshot({ path: file, animations: 'disabled', style: outline });
      return { screenshot };
    }
    const box = await frame.first().evaluate((f, pad) => {
      const el = document.querySelector('[data-qa-region]')!;
      // Sticky headers and cookie banners would otherwise sit on top of the component.
      for (const other of document.querySelectorAll('body *')) {
        const { position } = getComputedStyle(other);
        if ((position === 'fixed' || position === 'sticky') && !other.contains(f) && !f.contains(other) && !other.contains(el)) {
          other.setAttribute('data-qa-hide', '');
        }
      }
      f.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' });
      const a = f.getBoundingClientRect();
      const b = el.getBoundingClientRect();
      const r = {
        x: Math.min(a.left, b.left),
        y: Math.min(a.top, b.top),
        width: Math.max(a.right, b.right) - Math.min(a.left, b.left),
        height: Math.max(a.bottom, b.bottom) - Math.min(a.top, b.top),
      };
      const fits = r.height + 2 * pad <= window.innerHeight;
      return { x: r.x + (fits ? 0 : window.scrollX), y: r.y + (fits ? 0 : window.scrollY), width: r.width, height: r.height, fits };
    }, pad);
    const bounds = box.fits
      ? await page.evaluate(() => ({ width: window.innerWidth, height: window.innerHeight }))
      : await page.evaluate(() => ({ width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight }));
    const x = Math.max(0, box.x - pad);
    const y = Math.max(0, box.y - pad);
    const clip = {
      x,
      y,
      width: Math.min(bounds.width, box.x + box.width + pad) - x,
      height: Math.min(bounds.height, box.y + box.height + pad) - y,
    };
    await page.screenshot({
      path: file,
      fullPage: !box.fits,
      clip,
      animations: 'disabled',
      style: outline + hide,
    });
    return { screenshot };
  } catch (padded) {
    try {
      if (frame === 'screen') throw padded;
      await frame.first().screenshot({ path: file, animations: 'disabled', timeout: 5000, style: outline + hide });
      return { screenshot, note: `the padded crop failed (${clean(padded).split('\n')[0]}), so this is the component alone` };
    } catch (plain) {
      await page.screenshot({ path: file, animations: 'disabled', style: outline }).catch(() => {});
      return { screenshot, note: `the capture failed (${clean(plain).split('\n')[0]}), so this shows the whole viewport` };
    }
  } finally {
    await page
      .evaluate(() => {
        for (const el of document.querySelectorAll('[data-qa-region],[data-qa-hide]')) {
          el.removeAttribute('data-qa-region');
          el.removeAttribute('data-qa-hide');
        }
      })
      .catch(() => {});
  }
}

async function dumpAria(page: Page, region: Locator, name: string) {
  fs.mkdirSync(debugDir, { recursive: true });
  const snapshot = await region
    .first()
    .ariaSnapshot({ timeout: 2000 })
    .catch(() => page.locator('body').ariaSnapshot({ timeout: 5000 }))
    .catch(() => '');
  fs.writeFileSync(path.join(debugDir, name), `# ${page.url()}\n${snapshot}\n`);
}

function clean(error: unknown) {
  const text = error instanceof Error ? error.message : String(error);
  return text.replace(/\x1b\[[0-9;]*m/g, '').split('Call log:')[0].trim().slice(0, 600);
}

export const test = base.extend<{ qa: QA }>({
  qa: async ({ playwright }, use) => {
    const qa = new QA(playwright);
    try {
      await use(qa);
    } finally {
      await qa.close();
      fs.writeFileSync(resultsFile, JSON.stringify(qa.results, null, 2));
    }
    const notPassed = qa.results.filter((r) => r.status !== 'pass');
    if (notPassed.length) {
      throw new Error(`Not passed: ${notPassed.map((r) => `step ${r.step} ${r.engine} ${r.status}`).join(', ')}`);
    }
  },
});
