/**
 * Browser automation layer — Local CDP connection.
 *
 * Connects to a local headless Chromium via CDP (ws://127.0.0.1:18800).
 * Creates new pages for each session; never closes the shared browser.
 *
 * Credentials never pass through this module's logs; values are written
 * directly to the DOM.
 */

import {
  chromium,
  type Browser,
  type Page,
  type BrowserContext,
} from "playwright";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface BrowserSession {
  page: Page;
  browser: Browser;
  context: BrowserContext;
}

// ---------------------------------------------------------------------------
// Session lifecycle
// ---------------------------------------------------------------------------

/**
 * Create a browser session. Two modes:
 *   1. cdpUrl provided (http or ws) → connect to existing browser via CDP
 *   2. No cdpUrl or "launch" → launch a fresh headless Chromium instance
 */
export async function createSession(
  cdpUrl?: string,
  options?: { headed?: boolean },
): Promise<BrowserSession> {
  let browser: Browser;

  if (cdpUrl && cdpUrl !== "launch") {
    // Connect to existing browser via CDP
    let wsUrl: string;
    if (cdpUrl.startsWith("ws")) {
      wsUrl = cdpUrl;
    } else {
      // Discover WS URL from /json/version
      const res = await fetch(`${cdpUrl}/json/version`);
      const data = (await res.json()) as { webSocketDebuggerUrl?: string };
      wsUrl = data.webSocketDebuggerUrl || cdpUrl.replace(/^http/, "ws");
    }
    browser = await chromium.connectOverCDP(wsUrl);
    const context = browser.contexts()[0];
    if (!context) {
      throw new Error("No browser context available.");
    }
    const page = await context.newPage();
    page.setDefaultTimeout(15000);
    return { page, browser, context };
  }

  // Launch browser (headed if requested, headless by default)
  browser = await chromium.launch({
    headless: !options?.headed,
    args: [
      "--no-sandbox",
      "--disable-blink-features=AutomationControlled",
      "--disable-dev-shm-usage",
    ],
  });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  });

  // Anti-detection: hide webdriver property
  await context.addInitScript(() => {
    Object.defineProperty(navigator, "webdriver", { get: () => undefined });
    // Patch chrome.runtime to look normal
    (window as any).chrome = { runtime: {}, loadTimes: () => {}, csi: () => {} };
  });

  const page = await context.newPage();
  page.setDefaultTimeout(15000);
  return { page, browser, context };
}

/** Close the session. If we launched the browser, close it entirely. */
export async function closeSession(session: BrowserSession): Promise<void> {
  try {
    await session.page.close();
  } catch {
    // Page may already be closed
  }
  try {
    // Close the browser if we launched it (connected browsers just disconnect)
    await session.browser.close();
  } catch {
    // Already closed or disconnected
  }
}

// ---------------------------------------------------------------------------
// Page context extraction
// ---------------------------------------------------------------------------

/**
 * Build the minimal context the LLM needs: stripped HTML + a JPEG screenshot.
 *
 * The HTML extractor walks the DOM recursively and keeps only attributes
 * useful for locator generation. Shadow DOM boundaries are traversed so
 * enterprise SSO widgets aren't missed.
 */
export async function getPageContext(
  page: Page,
  attempt = 0,
): Promise<{ html: string; screenshot: string; url: string }> {
  try {
    await page.waitForLoadState("domcontentloaded", { timeout: 10000 });
  } catch {
    // Page might still be usable even if the full load times out
  }

  try {
    const extractBodyHTML = () => {
      function extractHTML(node: Node): string {
        if (node.nodeType === 3) return node.textContent?.trim() || "";
        if (node.nodeType !== 1) return "";

        const el = node as Element;
        const styles = window.getComputedStyle(el);
        if (styles.display === "none" || styles.visibility === "hidden")
          return "";

        const exclude = ["SCRIPT", "STYLE", "svg", "IMG", "NOSCRIPT", "LINK"];
        if (exclude.includes(el.tagName)) return "";

        const root = (el as any).shadowRoot || el;
        let html = `<${el.tagName.toLowerCase()}`;

        for (const attr of el.attributes) {
          if (
            [
              "id",
              "class",
              "type",
              "name",
              "placeholder",
              "role",
              "aria-label",
              "disabled",
              "aria-disabled",
              "readonly",
              "data-sitekey",
              "data-testid",
            ].includes(attr.name)
          ) {
            html += ` ${attr.name}="${attr.value}"`;
          }
        }
        html += ">";

        for (const child of root.childNodes) {
          if (child instanceof HTMLSlotElement) {
            const assigned = (child as HTMLSlotElement).assignedNodes()[0];
            html += assigned ? extractHTML(assigned) : child.innerHTML;
          } else {
            html += extractHTML(child);
          }
        }

        html += `</${el.tagName.toLowerCase()}>`;
        return html;
      }
      return extractHTML(document.body);
    };

    let bodyHtml = await page.evaluate(extractBodyHTML);

    // Extract iframe content separately
    for (const frame of page.frames()) {
      if (frame !== page.mainFrame()) {
        try {
          const iframeHtml = await frame.evaluate(extractBodyHTML);
          bodyHtml += `<iframe-content>${iframeHtml}</iframe-content>`;
        } catch {
          // Cross-origin frames can't be read
        }
      }
    }

    const buf = await page.screenshot({
      type: "jpeg",
      quality: 80,
      fullPage: false,
      timeout: 30000,
      animations: "disabled",
    });

    return {
      html: bodyHtml.substring(0, 100_000),
      screenshot: buf.toString("base64"),
      url: page.url(),
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : "";
    if (msg.includes("Execution context was destroyed") && attempt < 2) {
      console.warn(
        `[browser] Navigation detected, retrying (attempt ${attempt + 1})...`,
      );
      await page.waitForTimeout(2000);
      return getPageContext(page, attempt + 1);
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Wait for meaningful page content (used after form submissions)
// ---------------------------------------------------------------------------

/**
 * Wait for the SPA to render meaningful content.
 */
export async function waitForPageContent(page: Page): Promise<void> {
  // Timeout at 5s to avoid blocking on SPAs with persistent WebSockets (X, etc.)
  await page.waitForLoadState("load", { timeout: 5000 }).catch(() => {});

  try {
    await page.waitForFunction(
      () => {
        const body = document.body;
        if (!body) return false;
        return (
          body.querySelectorAll("input, button, a[href]").length >= 2 ||
          (body.innerText || "").trim().length > 100
        );
      },
      { timeout: 15000 },
    );
  } catch {
    // Timeout is fine — re-analyze with whatever we have
  }

  await page.waitForTimeout(2000);
}

// ---------------------------------------------------------------------------
// Form interaction helpers
// ---------------------------------------------------------------------------

/**
 * Fill every field and click submit. Credential values are written directly
 * to the DOM — they never appear in logs or LLM context.
 */
export async function fillAndSubmit(
  page: Page,
  inputs: Array<{ locator: string; value: string }>,
  submitLocator: string,
): Promise<void> {
  let lastInputLocator = "";
  for (const { locator, value } of inputs) {
    const filled = await fillInPageOrFrame(page, locator, value);
    if (filled) lastInputLocator = locator;
    if (!filled) {
      console.warn(`[browser] Could not fill element for locator: ${locator}`);
    }
  }

  try {
    const btn = page.locator(submitLocator).first();

    // Wait for button to become enabled (captcha/validation may take a few seconds)
    let isDisabled = await btn.isDisabled().catch(() => false);
    if (isDisabled) {
      console.log(`[browser] Submit button disabled, waiting up to 10s for it to enable...`);
      for (let wait = 0; wait < 10; wait++) {
        await page.waitForTimeout(1000);
        isDisabled = await btn.isDisabled().catch(() => false);
        if (!isDisabled) {
          console.log(`[browser] Submit button enabled after ${wait + 1}s`);
          break;
        }
      }
    }

    if (isDisabled && lastInputLocator) {
      console.warn(`[browser] Submit button still disabled after wait, trying Enter key...`);
      await page.locator(lastInputLocator).first().press("Enter");
    } else {
      await clickInPageOrFrame(page, submitLocator);
    }
  } catch (e) {
    console.warn(`[browser] Failed to submit form:`, e);
    if (lastInputLocator) {
      await page.locator(lastInputLocator).first().press("Enter").catch(() => {});
    }
  }

  // Wait for navigation / redirects (5s cap for SPA environments)
  await page.waitForLoadState("load", { timeout: 5000 }).catch(() => {});
  await page.waitForTimeout(3000);

  try {
    await page.waitForLoadState("domcontentloaded", { timeout: 5000 });
  } catch {
    // Page may already be stable
  }
}

/** Click an element, searching across frames if needed. */
export async function clickElement(page: Page, locator: string): Promise<void> {
  await clickInPageOrFrame(page, locator);
  await page.waitForLoadState("load", { timeout: 5000 }).catch(() => {});
  await page.waitForTimeout(1500);
}

// ---------------------------------------------------------------------------
// Frame-aware helpers
// ---------------------------------------------------------------------------

async function fillInPageOrFrame(
  page: Page,
  locator: string,
  value: string,
): Promise<boolean> {
  try {
    const el = page.locator(locator).first();
    if ((await el.count()) > 0) {
      await el.waitFor({ state: "attached", timeout: 5000 });
      // Skip disabled / read-only fields (e.g. X username on password step)
      const isDisabled = await el.isDisabled().catch(() => true);
      if (isDisabled) {
        console.warn(`[browser] Skipping disabled field: ${locator}`);
        return false;
      }
      await el.focus();
      await el.clear();
      await el.pressSequentially(value, { delay: 10 });
      return true;
    }
  } catch (e) {
    console.warn(`[browser] Main frame fill failed for ${locator}:`, e);
  }

  for (const frame of page.frames()) {
    if (frame === page.mainFrame()) continue;
    try {
      const el = frame.locator(locator).first();
      if ((await el.count()) > 0) {
        await el.focus();
        await el.clear();
        await el.fill(value);
        return true;
      }
    } catch {
      // Try next frame
    }
  }
  return false;
}

async function clickInPageOrFrame(
  page: Page,
  locator: string,
): Promise<boolean> {
  try {
    const el = page.locator(locator).first();
    if ((await el.count()) > 0) {
      await el.click();
      return true;
    }
  } catch (e) {
    console.warn(`[browser] Main frame click failed for ${locator}:`, e);
  }

  for (const frame of page.frames()) {
    if (frame === page.mainFrame()) continue;
    try {
      const el = frame.locator(locator).first();
      if ((await el.count()) > 0) {
        await el.click();
        return true;
      }
    } catch {
      // Try next frame
    }
  }
  return false;
}
