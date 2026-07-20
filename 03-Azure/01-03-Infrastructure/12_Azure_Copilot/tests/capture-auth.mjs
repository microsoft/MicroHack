/**
 * Captures Azure portal auth state from Edge's existing SSO session.
 * Uses Edge's user data directory so the existing login persists.
 *
 * Usage: node capture-auth.mjs
 *
 * Platform support:
 *   - Windows: uses %LOCALAPPDATA%\Microsoft\Edge\User Data
 *   - macOS:   uses ~/Library/Application Support/Microsoft Edge
 *   - Linux:   uses ~/.config/microsoft-edge
 */
import { chromium } from 'playwright';
import { mkdirSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

mkdirSync('.auth', { recursive: true });

function getEdgeUserDataDir() {
  switch (process.platform) {
    case 'win32':
      return join(process.env.LOCALAPPDATA ?? '', 'Microsoft', 'Edge', 'User Data');
    case 'darwin':
      return join(homedir(), 'Library', 'Application Support', 'Microsoft Edge');
    default:
      return join(homedir(), '.config', 'microsoft-edge');
  }
}

const userDataDir = getEdgeUserDataDir();

console.log('Launching Edge with existing profile for SSO...');
const context = await chromium.launchPersistentContext(userDataDir, {
  channel: 'msedge',
  headless: false,
  args: ['--profile-directory=Default'],
  viewport: { width: 1280, height: 720 },
});

const page = context.pages()[0] || await context.newPage();

console.log('Navigating to Azure portal...');
await page.goto('https://portal.azure.com', { waitUntil: 'domcontentloaded' });

// Wait for portal to load (SSO should auto-authenticate)
try {
  await page.waitForURL('**/portal.azure.com/**', { timeout: 60_000 });
  await page.getByRole('textbox', { name: /Search resources/ }).waitFor({
    state: 'visible',
    timeout: 60_000,
  });
  console.log('Portal loaded — authenticated via SSO');
} catch {
  console.log('Waiting for manual login... (complete login in the browser)');
  await page.getByRole('textbox', { name: /Search resources/ }).waitFor({
    state: 'visible',
    timeout: 300_000,
  });
}

// Save the auth state
await context.storageState({ path: '.auth/state.json' });
console.log('Auth state saved to .auth/state.json');

await context.close();
process.exit(0);
