import { test, expect } from '@playwright/test';
import { CopilotPage } from '../helpers/copilot-page';

const SUBSCRIPTION_ID = process.env.AZURE_SUBSCRIPTION_ID ?? '';

test.describe('Challenge 4 — Optimization Agent', () => {
  let copilot: CopilotPage;

  test.beforeEach(async ({ page }) => {
    copilot = new CopilotPage(page);
    await copilot.goto();
    await copilot.openCopilot();
    await copilot.enableAgentMode();
  });

  test('Task 1: Discover cost-saving opportunities', async () => {
    const prompt = SUBSCRIPTION_ID
      ? `Show me the top five cost-saving opportunities for subscription ${SUBSCRIPTION_ID}`
      : 'Show me the top five cost-saving opportunities for my current subscription.';

    const response = await copilot.sendMessage(prompt, { timeout: 120_000 });

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /cost|saving|recommendation|optimize|subscription/,
    );
  });

  test('Task 2: Deep-dive into a specific recommendation', async () => {
    const response = await copilot.sendMessage(
      'Explain the cost recommendation for vm-copilot-oversized in rg-copilot-{suffix}-ch03.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /vm|recommendation|cost|sku|right.?siz/,
    );
  });

  test('Task 3: Visualize optimization impact', async () => {
    const response = await copilot.sendMessage(
      'Show me a chart of the expected results of applying the recommendation for vm-copilot-oversized.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /chart|visual|impact|savings|result/,
    );
  });

  test('Task 4: Generate optimization scripts', async () => {
    const response = await copilot.sendMessage(
      'Generate a PowerShell script to apply the recommended optimizations for vm-copilot-oversized.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /powershell|script|resize|vm|az vm/,
    );
  });

  test('Task 5: Summarize total potential savings', async () => {
    const response = await copilot.sendMessage(
      'Summarize total potential cost and carbon reduction from all active recommendations.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /total|saving|cost|carbon|reduction|recommendation/,
    );
  });
});
