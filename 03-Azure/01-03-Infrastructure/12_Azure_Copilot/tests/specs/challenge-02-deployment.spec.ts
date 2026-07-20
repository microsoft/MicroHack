import { test, expect } from '@playwright/test';
import { CopilotPage } from '../helpers/copilot-page';

test.describe('Challenge 2 — Deployment Agent', () => {
  let copilot: CopilotPage;

  test.beforeEach(async ({ page }) => {
    copilot = new CopilotPage(page);
    await copilot.goto();
    await copilot.openCopilot();
  });

  test('Task 1: Enable Agent mode', async () => {
    await copilot.enableAgentMode();
    await expect(copilot.agentButton).toHaveAttribute('aria-pressed', 'true');
  });

  test('Task 2: Request a deployment plan', async () => {
    await copilot.enableAgentMode();

    const response = await copilot.sendMessage(
      'Deploy a simple web app with an App Service and Azure SQL Database in East US 2. Use Terraform for infrastructure as code.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    // The Deployment Agent should generate a plan with components
    expect(text!.toLowerCase()).toMatch(
      /plan|app service|sql|terraform|deploy/,
    );
  });

  test('Task 3: Refine a deployment plan', async () => {
    await copilot.enableAgentMode();

    // First request
    await copilot.sendMessage(
      'Deploy a Node.js API on App Service with a PostgreSQL database.',
      { timeout: 120_000 },
    );

    // Refine
    const response = await copilot.sendMessage(
      'Add Azure Cache for Redis for session management.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(/redis|cache/);
  });

  test('Task 4: Generate Terraform code', async () => {
    await copilot.enableAgentMode();

    const response = await copilot.sendMessage(
      'Generate Terraform code for a simple Azure App Service running Node.js.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    // Should include Terraform-related content
    expect(text!.toLowerCase()).toMatch(
      /terraform|resource|azurerm|provider|main\.tf/,
    );
  });

  test('Task 5: Review deployment artifacts', async () => {
    await copilot.enableAgentMode();
    await copilot.switchToFullscreen();

    const response = await copilot.sendMessage(
      'Deploy a static website on Azure Storage with a CDN.',
      { timeout: 120_000 },
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(/storage|cdn|static/);

    // Check for artifact pane indicators (Activity/Artifacts tabs)
    const artifactsTab = copilot.frame.getByRole('tab', {
      name: 'Artifacts',
    });
    if ((await artifactsTab.count()) > 0) {
      await artifactsTab.click();
      await expect(artifactsTab).toBeVisible();
    }
  });
});
