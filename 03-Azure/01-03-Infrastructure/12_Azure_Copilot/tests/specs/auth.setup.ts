import { test as setup } from '@playwright/test';
import path from 'path';

const authFile = path.join(__dirname, '..', '.auth', 'state.json');

/**
 * Interactive authentication setup.
 * Run with: npx playwright test --project=setup --headed
 *
 * This opens the Azure portal and pauses so you can sign in manually.
 * After login, the browser state (cookies/tokens) is saved for reuse.
 */
setup('authenticate with Azure portal', async ({ page }) => {
  await page.goto('https://portal.azure.com');

  // Pause to let you sign in manually
  await page.pause();

  // After you resume, save authenticated state
  await page.context().storageState({ path: authFile });
});
