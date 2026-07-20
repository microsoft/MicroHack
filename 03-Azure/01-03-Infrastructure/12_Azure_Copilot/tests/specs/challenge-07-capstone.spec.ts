import { test, expect } from '@playwright/test';
import { CopilotPage } from '../helpers/copilot-page';

test.describe('Challenge 7 — Capstone Multi-Agent Scenario', () => {
  let copilot: CopilotPage;

  test.beforeEach(async ({ page }) => {
    copilot = new CopilotPage(page);
    await copilot.goto();
    await copilot.openCopilot();
    await copilot.enableAgentMode();
    await copilot.switchToFullscreen();
  });

  test('Phase 1: Deploy e-commerce infrastructure', async () => {
    const response = await copilot.sendMessage(
      'I need to deploy an e-commerce platform with: a React frontend on App Service, a Node.js backend API on App Service, Azure Cosmos DB for the product catalog, and Azure Cache for Redis. Generate a Terraform plan.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /app service|cosmos|redis|terraform|plan|deploy/,
    );
  });

  test('Phase 2: Set up monitoring', async () => {
    const response = await copilot.sendMessage(
      'What alerts should I configure for an e-commerce platform with App Service, Cosmos DB, and Redis Cache?',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /alert|monitor|response time|error rate|metric/,
    );
  });

  test('Phase 3: Optimize costs', async () => {
    const response = await copilot.sendMessage(
      'Show me cost-saving opportunities across my subscription. Focus on compute and database resources.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /cost|saving|recommend|optimize|compute/,
    );
  });

  test('Phase 4: Ensure resiliency', async () => {
    const response = await copilot.sendMessage(
      'Which of my resources aren\'t zone-resilient? Help me set up backup for my critical resources.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /zone|resilient|backup|recovery|availability/,
    );
  });

  test('Phase 5: Troubleshoot an incident', async () => {
    const response = await copilot.sendMessage(
      'Users are reporting that the checkout process on our e-commerce platform is failing with timeout errors. Help me troubleshoot.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /timeout|troubleshoot|checkout|diagnos|issue/,
    );
  });

  test('Phase 6: Build operational runbook', async () => {
    const response = await copilot.sendMessage(
      'Help me create a daily operational runbook for my e-commerce platform covering monitoring, cost management, resiliency checks, and incident response.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(
      /runbook|operational|daily|monitor|incident/,
    );
  });
});
