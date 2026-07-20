import { test, expect } from '@playwright/test';
import { CopilotPage } from '../helpers/copilot-page';

test.describe('Challenge 1 — Azure Copilot Basics', () => {
  let copilot: CopilotPage;

  test.beforeEach(async ({ page }) => {
    copilot = new CopilotPage(page);
    await copilot.goto();
  });

  test('Task 1: Open Copilot panel', async () => {
    // Verify the Copilot button is visible in the portal header
    await expect(copilot.copilotButton).toBeVisible();

    // Open Copilot
    await copilot.openCopilot();

    // Verify the pane opened with chat input, suggested prompts, and controls
    await expect(copilot.chatInput).toBeVisible();
    await expect(copilot.agentButton).toBeVisible();
    await expect(copilot.attachContextButton).toBeVisible();
  });

  test('Task 2: Ask a question and get a response', async () => {
    await copilot.openCopilot();

    const response = await copilot.sendMessage(
      'What is Azure App Service and when should I use it?',
    );

    // Verify Copilot produced a response
    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text).toBeTruthy();
    expect(text!.toLowerCase()).toContain('app service');
  });

  test('Task 3: Navigate to a resource using Copilot', async () => {
    await copilot.openCopilot();

    const response = await copilot.sendMessage(
      'Navigate me to my resource groups',
    );

    await expect(response).toBeVisible();
    // Copilot should provide a navigation link or perform navigation
    const text = await response.textContent();
    expect(text!.toLowerCase()).toMatch(/resource group|navigate/);
  });

  test('Task 4: Generate a script', async () => {
    await copilot.openCopilot();

    const response = await copilot.sendMessage(
      'Generate a PowerShell script to list all VMs in my subscription',
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    // Response should contain script-related content
    expect(text!.toLowerCase()).toMatch(/powershell|script|get-azvm|az vm/i);
  });

  test('Task 5: Get recommendations', async () => {
    await copilot.openCopilot();

    const response = await copilot.sendMessage(
      'What best practices should I follow when deploying a web application on Azure?',
    );

    await expect(response).toBeVisible();
    const text = await response.textContent();
    expect(text!.length).toBeGreaterThan(100);
  });

  test('Task 6: Attach context', async () => {
    await copilot.openCopilot();
    await copilot.openContextPicker();

    // Verify the context picker tabs are visible
    const allTab = copilot.frame.getByRole('tab', { name: 'All' });
    const resourcesTab = copilot.frame.getByRole('tab', {
      name: 'Resources',
    });
    const rgTab = copilot.frame.getByRole('tab', {
      name: 'Resource groups',
    });
    const subsTab = copilot.frame.getByRole('tab', {
      name: 'Subscriptions',
    });

    await expect(allTab).toBeVisible();
    await expect(resourcesTab).toBeVisible();
    await expect(rgTab).toBeVisible();
    await expect(subsTab).toBeVisible();
  });
});
