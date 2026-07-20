import { test, expect } from '@playwright/test';
import { CopilotPage } from '../helpers/copilot-page';

test.describe('Challenge 5 — Resiliency Agent', () => {
  let copilot: CopilotPage;

  test.beforeEach(async ({ page }) => {
    copilot = new CopilotPage(page);
    await copilot.goto();
    await copilot.openCopilot();
    await copilot.enableAgentMode();
  });

  test('Task 1: Assess zone resiliency status', async () => {
    const response = await copilot.sendMessage(
      'Which resources aren\'t zone-resilient?',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /zone|resilient|resiliency|resource|availability/,
    );
  });

  test('Task 2: Configure zone resiliency', async () => {
    const response = await copilot.sendMessage(
      'Configure zone resiliency for my VM vm-copilot-noresilience in rg-copilot-{suffix}-ch04.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /zone|resiliency|vm|configure|availability/,
    );
  });

  test('Task 3: Review backup coverage', async () => {
    const response = await copilot.sendMessage(
      'Which data sources don\'t have a recovery point within the last 7 days?',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /backup|recovery|point|data source|protection/,
    );
  });

  test('Task 4: Manage backup vaults', async () => {
    const response = await copilot.sendMessage(
      'Help me create a Recovery Services vault named rsv-copilot-workshop in my resource group rg-copilot-{suffix}-ch04.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /vault|recovery|create|backup|services/,
    );
  });

  test('Task 5: Resiliency improvement plan', async () => {
    const response = await copilot.sendMessage(
      'Give me a summary of the resiliency posture of my resources in rg-copilot-{suffix}-ch04.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /resiliency|posture|summary|resource|improvement/,
    );
  });
});
