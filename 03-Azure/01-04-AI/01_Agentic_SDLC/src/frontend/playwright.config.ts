import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration scoped to Chromium only.
 */
export default defineConfig({
  testDir: './tests/e2e',
  timeout: 60_000,
  expect: {
    timeout: 10_000,
  },
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:5137',
    trace: 'on-first-retry',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer:
    process.env.PLAYWRIGHT_WEB_SERVER !== 'false'
      ? {
          command: 'cd .. && make dev',
          port: 5137,
          reuseExistingServer: !process.env.CI,
          timeout: 120_000,
        }
      : undefined,
});
