import { test, expect } from './qa';

// Replace this example with the approved plan. Step numbers and titles are the plan's, word for word.
test('test plan', async ({ qa }) => {
  const studio = await qa.signIn('chromium', {
    label: 'Sanity Studio (staging dataset)',
    url: 'https://example.sanity.studio/structure/page',
    ready: (page) => page.getByRole('button', { name: /create/i }).first(),
  });
  const dataset = 'staging';
  await studio.route(/\.api\.sanity\.io\/v[^/]+\/data\/(mutate|actions)\//, (route) => {
    const target = new URL(route.request().url()).pathname.split('/')[4];
    return target === dataset ? route.continue() : route.abort();
  });

  try {
    await qa.step(
      1,
      'In Studio, change the QA page heading to "QA heading 1234" and publish',
      { page: studio, region: (p) => p.getByTestId('field-heading'), frame: 'screen' },
      async () => {
        // Drive the Studio here. Wait for the change to save before publishing.
      },
    );

    await qa.eachEngine(async (page) => {
      await qa.step(
        2,
        'The QA page shows "QA heading 1234" as its heading',
        {
          page,
          // The region is what proves the result; the frame is the whole component it sits in.
          region: (p) => p.getByRole('heading', { level: 1 }),
          frame: (p) => p.getByRole('heading', { level: 1 }).locator('xpath=ancestor::section[1]'),
          needs: 1,
        },
        async () => {
          await page.goto('https://staging.example.com/qa-page');
          // Published content reaches the site after revalidation, so reload until it shows.
          await expect(async () => {
            await page.reload();
            await expect(page.getByRole('heading', { level: 1 })).toHaveText('QA heading 1234', { timeout: 2000 });
          }).toPass({ timeout: 90_000 });
        },
      );
    });
  } finally {
    await qa.step(
      3,
      'Delete the QA page and confirm it is gone',
      { page: studio, region: (p) => p.getByTestId('vision-result'), frame: 'screen' },
      async () => {
        // Delete the fixture, then check the store has no published or draft copy.
      },
    );
  }
});
