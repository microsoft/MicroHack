import { test, expect } from '@playwright/test';
import { CopilotPage } from '../helpers/copilot-page';

test.describe('Challenge 3 — Observability Agent', () => {
  let copilot: CopilotPage;

  test.beforeEach(async ({ page }) => {
    copilot = new CopilotPage(page);
    await copilot.goto();
    await copilot.openCopilot();
    await copilot.enableAgentMode();
  });

  test('Task 1: Start an alert investigation', async () => {
    const response = await copilot.sendMessage(
      'Start an investigation for my most recent alert.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    // Should mention alerts, investigation, or ask for context
    expect(text!.toLowerCase()).toMatch(
      /alert|investigation|monitor|select|resource/,
    );
  });

  test('Task 2: Investigate with specific resource context', async () => {
    const response = await copilot.sendMessage(
      'Investigate HTTP 5xx errors on my App Service in resource group rg-copilot-{suffix}-ch02.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /5xx|error|http|app service|investigate/,
    );
  });

  test('Task 3: Check application health metrics', async () => {
    const response = await copilot.sendMessage(
      'What are the current response times and error rates for my application in rg-copilot-{suffix}-ch02?',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /response time|error rate|metric|performance|monitor/,
    );
  });

  test('Task 4: Investigate slow response times', async () => {
    const response = await copilot.sendMessage(
      'My web application is experiencing slow response times. Help me investigate using Application Insights.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /response|slow|performance|application insights|latency/,
    );
  });

  test('Task 5: Investigate Azure Monitor issues', async () => {
    const response = await copilot.sendMessage(
      'Show me any Azure Monitor alerts that fired in the last 24 hours.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(/alert|monitor|24 hours|fired|no/);
  });
});
