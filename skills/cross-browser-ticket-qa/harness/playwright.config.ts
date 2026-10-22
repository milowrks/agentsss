import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  testMatch: 'plan.spec.ts',
  // A run includes waiting for a human to sign in.
  timeout: 60 * 60_000,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  outputDir: 'test-output',
  // Traces record typed text, so a sign-in would end up in the trace file.
  use: { trace: 'off', video: 'off', screenshot: 'off' },
});
