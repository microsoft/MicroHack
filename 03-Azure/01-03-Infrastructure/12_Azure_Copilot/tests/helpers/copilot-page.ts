import { Page, FrameLocator, Locator, expect } from '@playwright/test';

/**
 * Page Object Model for Azure Portal Copilot interactions.
 *
 * Architecture: All Copilot UI renders inside an iframe named
 * "CopilotFluentAI.ReactView". This class abstracts that boundary
 * so test specs interact with Copilot as if it were a first-class page.
 *
 * Key test IDs (inside the Copilot iframe):
 *   - copilot-input-chatinput  — main prompt textarea
 *   - copilot-toggle-agentmode — agent mode toggle button
 *   - copilot-add-context-button — "Attach context" button
 *
 * Agent mode response flow:
 *   1. User sends message → "Reasoning…" indicator appears
 *   2. Agent executes actions (visible in Activity tab)
 *   3. Text streams into an article[aria-label="Copilot said"]
 *   4. Suggestion toolbar may appear with follow-up buttons
 *
 * Timeouts are intentionally generous because Copilot agent processing
 * can take 15–120+ seconds depending on complexity.
 */
export class CopilotPage {
  readonly page: Page;

  // Portal-level locators
  readonly copilotButton: Locator;
  readonly searchBar: Locator;

  // Copilot iframe (lazy-initialised)
  private _frame: FrameLocator | null = null;

  constructor(page: Page) {
    this.page = page;
    this.copilotButton = page.getByRole('button', { name: 'Copilot' });
    this.searchBar = page.getByRole('textbox', {
      name: /Search resources, services, and docs/,
    });
  }

  /** Lazily resolved Copilot iframe locator. */
  get frame(): FrameLocator {
    this._frame ??= this.page.frameLocator(
      'iframe[name="CopilotFluentAI.ReactView"]',
    );
    return this._frame;
  }

  // ── Copilot-pane locators (inside iframe) ──────────────────────

  get chatInput(): Locator {
    return this.frame.getByTestId('copilot-input-chatinput');
  }

  get agentButton(): Locator {
    return this.frame.getByTestId('copilot-toggle-agentmode');
  }

  get attachContextButton(): Locator {
    return this.frame.getByTestId('copilot-add-context-button');
  }

  get fullscreenButton(): Locator {
    return this.frame.getByRole('button', {
      name: /Switch to fullscreen mode/,
    });
  }

  get sidecarButton(): Locator {
    return this.frame.getByRole('button', {
      name: /Switch to sidecar mode/,
    });
  }

  get newChatButton(): Locator {
    return this.frame.getByRole('button', { name: 'Start a new chat' });
  }

  get closeButton(): Locator {
    return this.frame.getByRole('button', { name: 'Close Copilot hub' });
  }

  get navPaneToggle(): Locator {
    return this.frame.getByRole('button', {
      name: /Open Copilot navigation pane/,
    });
  }

  /** The feed region that holds conversation messages. */
  get feed(): Locator {
    return this.frame.getByRole('feed');
  }

  // ── High-level actions ─────────────────────────────────────────

  /** Navigate to Azure portal and wait for it to load. */
  async goto(): Promise<void> {
    await this.page.goto('https://portal.azure.com', {
      waitUntil: 'domcontentloaded',
    });
    await this.handleLoginIfNeeded();
    await this.searchBar.waitFor({ state: 'visible', timeout: 90_000 });
  }

  /**
   * If the portal redirects to login.microsoftonline.com,
   * attempt SSO login. Set AZURE_USER_EMAIL to override the default.
   *
   * NOTE: Automated Playwright runs disable WAM/Windows Hello, so
   * FIDO2 or passwordless flows will block. For fully automated runs
   * use the GitHub Copilot CLI MCP browser approach instead (see README).
   */
  private async handleLoginIfNeeded(): Promise<void> {
    const email = process.env.AZURE_USER_EMAIL;
    if (!email) {
      // No email configured — assume auth state was restored from .auth/state.json
      await this.page.waitForTimeout(3_000);
      return;
    }

    await this.page.waitForTimeout(3_000);

    const url = this.page.url();
    if (
      !url.includes('login.microsoftonline.com') &&
      !url.includes('auth/login')
    ) {
      return; // Already authenticated
    }

    // "Pick an account" page
    const pickAccount = this.page.getByText(email).first();
    if (await pickAccount.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await pickAccount.click();
      await this.page.waitForURL('**/portal.azure.com/**', {
        timeout: 60_000,
      });
      return;
    }

    // Standard sign-in page
    const emailInput = this.page.getByPlaceholder('Email, phone, or Skype');
    if (await emailInput.isVisible({ timeout: 5_000 }).catch(() => false)) {
      await emailInput.fill(email);
      await this.page.getByRole('button', { name: 'Next' }).click();
      await this.page.waitForURL('**/portal.azure.com/**', {
        timeout: 90_000,
      });
    }
  }

  /** Open the Copilot side pane (if not already open). */
  async openCopilot(): Promise<void> {
    await this.copilotButton.click();
    await this.chatInput.waitFor({ state: 'visible', timeout: 30_000 });
  }

  /** Enable Agent mode. No-op if already enabled. */
  async enableAgentMode(): Promise<void> {
    const pressed = await this.agentButton.getAttribute('aria-pressed');
    if (pressed !== 'true') {
      await this.agentButton.click();
    }
    await expect(this.agentButton).toHaveAttribute('aria-pressed', 'true');
  }

  /** Switch to fullscreen mode. No-op if already fullscreen. */
  async switchToFullscreen(): Promise<void> {
    const btn = this.fullscreenButton;
    if ((await btn.count()) > 0) {
      await btn.click();
      await this.sidecarButton.waitFor({ state: 'visible', timeout: 10_000 });
    }
  }

  /** Switch back to sidecar (side-pane) mode. */
  async switchToSidecar(): Promise<void> {
    const btn = this.sidecarButton;
    if ((await btn.count()) > 0) {
      await btn.click();
      await this.fullscreenButton.waitFor({
        state: 'visible',
        timeout: 10_000,
      });
    }
  }

  /** Start a fresh chat conversation. */
  async startNewChat(): Promise<void> {
    await this.newChatButton.click();
    await this.chatInput.waitFor({ state: 'visible', timeout: 10_000 });
  }

  /**
   * Send a message to Copilot and wait for the response to complete.
   * Returns the last Copilot response article locator.
   */
  async sendMessage(
    message: string,
    options?: { timeout?: number },
  ): Promise<Locator> {
    const timeout = options?.timeout ?? 90_000;

    const articlesBefore = await this.frame
      .getByRole('article')
      .filter({ hasText: 'Copilot said' })
      .count();

    await this.chatInput.fill(message);
    await this.chatInput.press('Enter');

    const copilotArticles = this.frame
      .getByRole('article')
      .filter({ hasText: 'Copilot said' });

    await expect(copilotArticles).toHaveCount(articlesBefore + 1, { timeout });

    return copilotArticles.nth(articlesBefore);
  }

  /**
   * Wait for the Copilot response to finish reasoning/processing.
   * Checks that the "Reasoning…" indicator disappears and the
   * agent mode button is re-enabled.
   */
  async waitForResponseComplete(timeout = 90_000): Promise<void> {
    const reasoningIndicator = this.frame.getByText('Reasoning...');
    if ((await reasoningIndicator.count()) > 0) {
      await reasoningIndicator.waitFor({ state: 'hidden', timeout });
    }
    await expect(this.agentButton).not.toHaveAttribute('disabled', '', {
      timeout,
    });
  }

  /** Open the "Attach context" picker. */
  async openContextPicker(): Promise<void> {
    await this.attachContextButton.click();
    await this.frame
      .getByRole('tab', { name: 'All' })
      .waitFor({ state: 'visible', timeout: 10_000 });
  }

  /** Get the last Copilot response text content. */
  async getLastResponseText(): Promise<string> {
    const articles = this.frame
      .getByRole('article')
      .filter({ hasText: 'Copilot said' });
    const count = await articles.count();
    if (count === 0) return '';
    return (await articles.nth(count - 1).textContent()) ?? '';
  }

  /** Check if a specific text appears in the last Copilot response. */
  async responseContains(text: string): Promise<boolean> {
    const content = await this.getLastResponseText();
    return content.toLowerCase().includes(text.toLowerCase());
  }

  /** Get follow-up suggestion buttons from the latest response. */
  get followUpSuggestions(): Locator {
    return this.frame.getByRole('button').filter({ hasText: /\?$/ });
  }

  /** Navigate to a resource group in the portal. */
  async navigateToResourceGroup(rgName: string): Promise<void> {
    const subscriptionId = process.env.AZURE_SUBSCRIPTION_ID;
    if (!subscriptionId) {
      throw new Error(
        'AZURE_SUBSCRIPTION_ID env var is required for resource group navigation',
      );
    }
    await this.page.goto(
      `https://portal.azure.com/#@/resource/subscriptions/${subscriptionId}/resourceGroups/${rgName}/overview`,
      { waitUntil: 'domcontentloaded' },
    );
  }
}
