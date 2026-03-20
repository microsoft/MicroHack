import { defineConfig } from '@playwright/test';

/**
 * Playwright configuration for Azure Copilot MicroHack E2E tests.
 *
 * Environment variables:
 *   AZURE_USER_EMAIL        — Azure AD email for SSO login
 *   AZURE_SUBSCRIPTION_ID   — target subscription for resource-scoped tests
 *
 * Authentication:
 *   Run `npm run auth:setup` once in headed mode to save session tokens
 *   to .auth/state.json, then all subsequent runs reuse the saved state.
 *
 * IMPORTANT: Azure portal uses WAM (Web Account Manager) for auth on
 * corporate machines. Playwright automation mode disables WAM, so
 * FIDO2/passwordless auth will NOT work in headless. You must either:
 *   1. Use `auth:setup` to capture a session interactively, OR
 *   2. Use GitHub Copilot CLI with the Playwright MCP browser
 *      (which inherits the system's WAM session automatically).
 *
 * See README.md for detailed instructions.
 */
export default defineConfig({
  testDir: './specs',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: [
    ['html', { open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
    ['list'],
  ],
  timeout: 180_000,
  expect: {
    timeout: 60_000,
  },
  use: {
    baseURL: 'https://portal.azure.com',
    storageState: '.auth/state.json',
    channel: 'msedge',
    screenshot: 'on',
    video: 'retain-on-failure',
    trace: 'on-first-retry',
    actionTimeout: 30_000,
    navigationTimeout: 90_000,
    viewport: { width: 1920, height: 1080 },
  },
  projects: [
    {
      name: 'setup',
      testMatch: /auth\.setup\.ts$/,
      use: { storageState: undefined },
    },
    {
      name: 'edge',
      testMatch: /\.spec\.ts$/,
      dependencies: ['setup'],
    },
  ],
});
