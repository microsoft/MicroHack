import { test, expect } from '@playwright/test';
import { CopilotPage } from '../helpers/copilot-page';

test.describe('Challenge 6 — Troubleshooting Agent', () => {
  let copilot: CopilotPage;

  test.beforeEach(async ({ page }) => {
    copilot = new CopilotPage(page);
    await copilot.goto();
    await copilot.openCopilot();
    await copilot.enableAgentMode();
  });

  test('Task 1: Troubleshoot VM connectivity', async () => {
    const response = await copilot.sendMessage(
      'I can\'t connect to my VM vm-copilot-broken in rg-copilot-{suffix}-ch05. Can you help me troubleshoot?',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /vm|connect|troubleshoot|nsg|ssh|rdp|network|diagnostic/,
    );
  });

  test('Task 2: Troubleshoot database connection', async () => {
    const response = await copilot.sendMessage(
      'I\'m trying to connect to my Azure Cosmos DB (NoSQL API) from my local development machine, but I keep getting a timeout. What should I do?',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /cosmos|timeout|firewall|connection|ip|whitelist/,
    );
  });

  test('Task 3: Troubleshoot AKS cluster issues', async () => {
    const response = await copilot.sendMessage(
      'Investigate the health of my pods in my AKS cluster.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /aks|pod|kubernetes|health|cluster|select|resource/,
    );
  });

  test('Task 4: One-click fix experience', async () => {
    const response = await copilot.sendMessage(
      'My VM vm-copilot-broken in rg-copilot-{suffix}-ch05 isn\'t responding. Help me troubleshoot.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    // Should identify the NSG blocking issue and offer remediation
    expect(text!.toLowerCase()).toMatch(
      /nsg|inbound|block|deny|fix|remediat|rule|security/,
    );
  });

  test('Task 5: Support request creation flow', async () => {
    const response = await copilot.sendMessage(
      'My application is experiencing intermittent failures that I can\'t diagnose. Can you create a support request?',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /support|request|ticket|help|diagnostic/,
    );
  });
});
