/**
 * Agent — the brain of the Login Machine.
 *
 * analyzeLoginPage()  — Screenshot + HTML → LLM → structured screen type
 * handleScreen()      — Act on the classified screen (fill, click, wait…)
 *
 * Model priority: Antigravity ($0) → Google Gemini → Anthropic direct.
 * Override: LM_BASE_URL + LM_API_KEY + LM_MODEL env vars.
 */

import { createOpenAI } from "@ai-sdk/openai";
import { generateObject } from "ai";
import { LOGIN_SCREEN_SYSTEM_PROMPT } from "./prompts";
import { LoginStateSchema, type LoginState, type AgentMessage } from "./types";
import {
  type BrowserSession,
  getPageContext,
  fillAndSubmit,
  clickElement,
  waitForPageContent,
} from "./browser";
import {
  detectCaptcha,
  solveTurnstile,
  solveRecaptchaV2,
  solveHCaptcha,
  injectCaptchaToken,
} from "./captcha";
import { waitForVerificationEmail, getEmailAddress } from "./email-verify";
import { buyNumber, waitForCode as waitForSmsCode, cancelOrder } from "./sms";

// ---------------------------------------------------------------------------
// LLM provider setup — multi-provider fallback chain
// ---------------------------------------------------------------------------

interface ModelSlot {
  name: string;
  provider: ReturnType<typeof createOpenAI>;
  model: string;
}

function buildModelChain(): ModelSlot[] {
  // If user explicitly set env, use that single provider only
  if (process.env.LM_BASE_URL) {
    const p = createOpenAI({
      baseURL: process.env.LM_BASE_URL,
      apiKey: process.env.LM_API_KEY || "sk-dummy",
    });
    return [{ name: "custom", provider: p, model: process.env.LM_MODEL || "claude-sonnet-4-5" }];
  }

  const slots: ModelSlot[] = [];

  // 1. Antigravity — $0 cost, try first
  slots.push({
    name: "antigravity",
    provider: createOpenAI({
      baseURL: "http://127.0.0.1:8045/v1",
      apiKey: "sk-e97ef24d4931482093b3889be6517959",
    }),
    model: "claude-sonnet-4-5",
  });

  // 2. Google Gemini — direct API (needs GOOGLE_GENERATIVE_AI_API_KEY or GEMINI_API_KEY)
  const geminiKey = process.env.GOOGLE_GENERATIVE_AI_API_KEY || process.env.GEMINI_API_KEY;
  if (geminiKey) {
    slots.push({
      name: "gemini",
      provider: createOpenAI({
        baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
        apiKey: geminiKey,
      }),
      model: "gemini-2.5-flash",
    });
  }

  // 3. Anthropic direct (needs ANTHROPIC_API_KEY)
  if (process.env.ANTHROPIC_API_KEY) {
    slots.push({
      name: "anthropic",
      provider: createOpenAI({
        baseURL: "https://api.anthropic.com/v1",
        apiKey: process.env.ANTHROPIC_API_KEY,
      }),
      model: "claude-sonnet-4-5-20250514",
    });
  }

  return slots;
}

const modelChain = buildModelChain();
let activeSlotIndex = 0;

function getModel() {
  const slot = modelChain[activeSlotIndex] || modelChain[0];
  return slot.provider(slot.model);
}

function getActiveSlotName(): string {
  return (modelChain[activeSlotIndex] || modelChain[0]).name;
}

/** Rotate to next provider in chain after a failure. Returns true if rotated. */
function rotateProvider(): boolean {
  if (modelChain.length <= 1) return false;
  const prev = activeSlotIndex;
  activeSlotIndex = (activeSlotIndex + 1) % modelChain.length;
  console.warn(`[agent] Rotating provider: ${modelChain[prev].name} → ${modelChain[activeSlotIndex].name}`);
  return true;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_ANALYSIS_RETRIES = 3;

// ---------------------------------------------------------------------------
// Locator validation helpers
// ---------------------------------------------------------------------------

/** Pull every Playwright locator string out of a classified screen. */
function getScreenLocators(screen: LoginState): string[] {
  const locators: string[] = [];
  if (screen.inputs) {
    for (const input of screen.inputs) locators.push(input.playwrightLocator);
  }
  if (screen.submit) locators.push(screen.submit.playwrightLocator);
  if (screen.options) {
    for (const opt of screen.options)
      locators.push(opt.optionPlaywrightLocator);
  }
  if (screen.dismissPlaywrightLocator)
    locators.push(screen.dismissPlaywrightLocator);
  return locators;
}

/** Check whether a Playwright locator resolves to at least one *usable* element.
 *
 * For INPUT elements: must exist AND not be disabled (disabled inputs can't be filled).
 * For BUTTON/submit elements: must exist (may be disabled until form is filled — that's OK).
 */
async function validateLocator(
  session: BrowserSession,
  locator: string,
): Promise<boolean> {
  const page = session.page;

  const isInputLocator = /input/i.test(locator);

  const isUsable = async (el: ReturnType<typeof page.locator>) => {
    if ((await el.count()) === 0) return false;
    if (isInputLocator) {
      // Reject disabled inputs — they can't be typed into
      const disabled = await el.first().isDisabled().catch(() => false);
      if (disabled) return false;
    }
    return true;
  };

  try {
    if (await isUsable(page.locator(locator))) return true;
  } catch {
    // Fall through to iframes
  }

  for (const frame of page.frames()) {
    if (frame === page.mainFrame()) continue;
    try {
      if (await isUsable(frame.locator(locator))) return true;
    } catch {
      // Next frame
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// analyzeLoginPage — the core observation step
// ---------------------------------------------------------------------------

/**
 * Screenshot the page, send it (with stripped HTML) to the LLM, and receive a
 * structured screen classification.
 *
 * Includes validation + self-correction loop:
 *   1. Zod schema parsing — output must match the expected shape.
 *   2. Element existence — every Playwright locator is checked against the DOM.
 *   3. Retry with context — if validation fails, errors are fed back to the LLM.
 */
export async function analyzeLoginPage(
  session: BrowserSession,
  verbose = false,
): Promise<{ screen: LoginState; screenshot: string }> {
  const { html, screenshot, url } = await getPageContext(session.page);

  const errorHistory: Array<{ error: string }> = [];

  for (let attempt = 0; attempt < MAX_ANALYSIS_RETRIES; attempt++) {
    const errorContext =
      errorHistory.length > 0
        ? `\n\n<error-history>\n${errorHistory.map((e, i) => `Attempt ${i + 1}: ${e.error}`).join("\n")}\n</error-history>`
        : "";

    if (verbose) {
      console.log(
        `[agent] Analyzing page (attempt ${attempt + 1}/${MAX_ANALYSIS_RETRIES})...`,
      );
    }

    let object: LoginState;
    try {
      const result = await generateObject({
        model: getModel(),
        schema: LoginStateSchema,
        system: LOGIN_SCREEN_SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: `Current URL: ${url}\n\nHTML:\n${html}${errorContext}`,
              },
              { type: "image", image: `data:image/jpeg;base64,${screenshot}` },
            ],
          },
        ],
      });
      object = result.object;
    } catch (genErr) {
      const msg = genErr instanceof Error ? genErr.message : String(genErr);
      if (verbose) console.warn(`[agent] generateObject failed (${getActiveSlotName()}): ${msg.substring(0, 200)}`);
      errorHistory.push({ error: `Schema generation failed: ${msg.substring(0, 200)}` });
      // Try next provider on timeout or API errors
      if (msg.includes("timed out") || msg.includes("timeout") || msg.includes("503") || msg.includes("429") || msg.includes("500")) {
        rotateProvider();
      }
      continue;
    }

    if (verbose) {
      console.log(`[agent] Classified as: ${object.type}`);
    }

    // Screens without locators don't need validation
    if (["loading_screen", "logged_in_screen", "captcha_screen"].includes(object.type)) {
      return { screen: object, screenshot };
    }

    // Validate every locator against the live DOM
    const locators = getScreenLocators(object);
    if (locators.length === 0) {
      return { screen: object, screenshot };
    }

    const results = await Promise.all(
      locators.map(async (loc) => ({
        locator: loc,
        exists: await validateLocator(session, loc),
      })),
    );

    const missing = results.filter((r) => !r.exists);
    if (missing.length === 0) {
      return { screen: object, screenshot };
    }

    const errorMsg = `These locators are not found or are disabled/non-interactable: ${missing.map((m) => m.locator).join(", ")}. Note: disabled inputs (e.g. already-filled username on a multi-step form) should be excluded. Please generate locators for the currently active/enabled fields only.`;
    if (verbose) {
      console.warn(`[agent] Validation failed: ${errorMsg}`);
    }
    errorHistory.push({ error: errorMsg });
  }

  // Exhausted retries — return best effort
  console.warn("[agent] Exhausted retries, returning loading_screen fallback");
  const { screenshot: lastScreenshot } = await getPageContext(session.page);
  // Return a loading_screen so the outer loop can handle gracefully
  const fallback = { type: "loading_screen" } as LoginState;
  return { screen: fallback, screenshot: lastScreenshot };
}

// ---------------------------------------------------------------------------
// handleScreen — act on the classified screen
// ---------------------------------------------------------------------------

export async function handleScreen(
  session: BrowserSession,
  screen: LoginState,
  userInput?: Record<string, string>,
  verbose = false,
): Promise<{ nextScreen: LoginState | null; message: AgentMessage }> {
  switch (screen.type) {
    // ------------------------------------------------------------------
    // credential_login_form — fill fields + click submit
    // ------------------------------------------------------------------
    case "credential_login_form": {
      const hasValues = userInput && Object.values(userInput).some((v) => v);
      if (process.env.DEBUG_AGENT) {
        console.log("[DEBUG] screen.inputs:", JSON.stringify(screen.inputs));
        console.log("[DEBUG] userInput keys:", userInput ? Object.keys(userInput) : "none");
      }
      if (!hasValues || !screen.inputs || !screen.submit) {
        return {
          nextScreen: null,
          message: { type: "input_request", screen },
        };
      }

      const inputs = screen.inputs
        .filter((input) => userInput[input.name])
        .map((input) => ({
          locator: input.playwrightLocator,
          value: userInput[input.name],
        }));

      if (verbose) {
        console.log(
          `[agent] Filling ${inputs.length} field(s) and submitting...`,
        );
      }

      await fillAndSubmit(
        session.page,
        inputs,
        screen.submit.playwrightLocator,
      );

      return {
        nextScreen: null,
        message: { type: "action", action: "Filled form and submitted" },
      };
    }

    // ------------------------------------------------------------------
    // choice_screen — click the selected option
    // ------------------------------------------------------------------
    case "choice_screen": {
      if (!userInput?.choice || !screen.options) {
        // Auto-select first option if available
        if (screen.options && screen.options.length > 0) {
          const first = screen.options[0];
          if (verbose) {
            console.log(
              `[agent] Auto-selecting first option: ${first.optionText}`,
            );
          }
          await clickElement(
            session.page,
            first.optionPlaywrightLocator,
          );
          if (screen.submit) {
            await clickElement(
              session.page,
              screen.submit.playwrightLocator,
            );
          }
          return {
            nextScreen: null,
            message: {
              type: "action",
              action: `Auto-selected: ${first.optionText}`,
            },
          };
        }
        return {
          nextScreen: null,
          message: { type: "input_request", screen },
        };
      }

      const option = screen.options!.find(
        (o) => o.optionText === userInput.choice,
      );
      if (!option) {
        return {
          nextScreen: screen,
          message: {
            type: "error",
            message: `Option not found: ${userInput.choice}`,
          },
        };
      }

      await clickElement(session.page, option.optionPlaywrightLocator);
      if (screen.submit) {
        await clickElement(session.page, screen.submit.playwrightLocator);
      }

      return {
        nextScreen: null,
        message: { type: "action", action: `Selected: ${userInput.choice}` },
      };
    }

    // ------------------------------------------------------------------
    // magic_login_link — can't auto-handle, notify user
    // ------------------------------------------------------------------
    case "magic_login_link": {
      return {
        nextScreen: null,
        message: {
          type: "complete",
          success: false,
          message: `Magic login link required: ${screen.instructionText || "Check your email"}. Cannot auto-complete this flow.`,
        },
      };
    }

    // ------------------------------------------------------------------
    // blocked_screen — auto-dismiss and re-analyze
    // ------------------------------------------------------------------
    case "blocked_screen": {
      if (!screen.dismissPlaywrightLocator) {
        return {
          nextScreen: null,
          message: { type: "error", message: "No dismiss locator found" },
        };
      }
      if (verbose) {
        console.log("[agent] Dismissing blocking element...");
      }
      await clickElement(session.page, screen.dismissPlaywrightLocator);
      const { screen: nextScreen } = await analyzeLoginPage(session, verbose);
      return {
        nextScreen,
        message: { type: "action", action: "Dismissed blocking popup" },
      };
    }

    // ------------------------------------------------------------------
    // captcha_screen — solve via CapSolver
    // ------------------------------------------------------------------
    case "captcha_screen": {
      if (verbose) console.log(`[agent] Captcha detected: ${screen.captchaType || "unknown"}`);

      // Auto-detect captcha info from live DOM
      const captchaInfo = await detectCaptcha(session.page);
      const captchaType = captchaInfo.type !== "unknown" ? captchaInfo.type : (screen.captchaType || "unknown");
      const siteKey = captchaInfo.siteKey || screen.siteKey || null;
      const pageUrl = session.page.url();

      if (!siteKey && captchaType !== "cloudflare_challenge") {
        if (verbose) console.warn("[agent] No captcha sitekey found");
        return {
          nextScreen: null,
          message: { type: "error", message: "Cannot solve captcha: no sitekey found" },
        };
      }

      if (verbose) console.log(`[agent] Solving ${captchaType} (sitekey: ${siteKey?.substring(0, 10)}...)...`);

      let token: string | null = null;
      switch (captchaType) {
        case "turnstile":
        case "cloudflare_challenge":
          token = await solveTurnstile(pageUrl, siteKey || pageUrl);
          break;
        case "recaptcha_v2":
        case "recaptcha_v3":
          token = await solveRecaptchaV2(pageUrl, siteKey!);
          break;
        case "hcaptcha":
          token = await solveHCaptcha(pageUrl, siteKey!);
          break;
      }

      if (!token) {
        return {
          nextScreen: null,
          message: { type: "error", message: `Failed to solve ${captchaType} captcha` },
        };
      }

      if (verbose) console.log("[agent] Captcha solved, injecting token...");
      await injectCaptchaToken(session.page, captchaInfo, token);
      await session.page.waitForTimeout(3000);

      // Re-analyze after captcha solve
      const { screen: nextScreen } = await analyzeLoginPage(session, verbose);
      return {
        nextScreen,
        message: { type: "action", action: `Solved ${captchaType} captcha` },
      };
    }

    // ------------------------------------------------------------------
    // verification_screen — SMS / email / authenticator code
    // ------------------------------------------------------------------
    case "verification_screen": {
      const method = screen.verificationMethod || "unknown";
      if (verbose) console.log(`[agent] Verification required: ${method}`);

      let code: string | null = null;

      if (method === "sms") {
        if (verbose) console.log("[agent] Waiting for SMS code via 5sim...");
        // If we previously bought a number (stored in session), wait for it
        // Otherwise this is a login flow requiring user's own phone
        // For now, try to poll if there's an active order
        const hint = screen.verificationHint || "";
        if (verbose) console.log(`[agent] Phone hint: ${hint}`);

        // Check if we have an active SMS order in env
        const orderId = process.env._LM_SMS_ORDER_ID;
        if (orderId) {
          code = await waitForSmsCode(parseInt(orderId), 90_000);
        } else {
          return {
            nextScreen: null,
            message: {
              type: "error",
              message: `SMS verification required (hint: ${hint}). No active SMS order. Provide phone access or use 5sim for registration flows.`,
            },
          };
        }
      } else if (method === "email") {
        if (verbose) console.log(`[agent] Waiting for verification email at ${getEmailAddress()}...`);
        const result = await waitForVerificationEmail({ timeoutMs: 90_000 });
        if (result) {
          code = result.code || null;
          if (!code && result.link) {
            // Navigate to verification link instead
            if (verbose) console.log(`[agent] Following verification link: ${result.link}`);
            await session.page.goto(result.link, { waitUntil: "domcontentloaded", timeout: 15000 });
            await session.page.waitForTimeout(3000);
            const { screen: nextScreen } = await analyzeLoginPage(session, verbose);
            return {
              nextScreen,
              message: { type: "action", action: "Followed email verification link" },
            };
          }
        }
      } else if (method === "authenticator") {
        return {
          nextScreen: null,
          message: { type: "error", message: "Authenticator (TOTP) verification not yet supported. Check 1Password for TOTP." },
        };
      }

      if (!code) {
        return {
          nextScreen: null,
          message: { type: "error", message: `Failed to get ${method} verification code` },
        };
      }

      // Fill the code into the input field
      if (screen.inputs && screen.inputs.length > 0 && screen.submit) {
        const inputs = screen.inputs.map((input) => ({
          locator: input.playwrightLocator,
          value: code!,
        }));
        if (verbose) console.log(`[agent] Filling verification code: ${code}`);
        await fillAndSubmit(session.page, inputs, screen.submit.playwrightLocator);
      }

      const { screen: nextScreen } = await analyzeLoginPage(session, verbose);
      return {
        nextScreen,
        message: { type: "action", action: `Filled ${method} verification code` },
      };
    }

    // ------------------------------------------------------------------
    // loading_screen — wait and re-analyze
    // ------------------------------------------------------------------
    case "loading_screen": {
      if (verbose) {
        console.log("[agent] Page loading, waiting...");
      }
      await waitForPageContent(session.page);
      const { screen: nextScreen } = await analyzeLoginPage(session, verbose);
      return {
        nextScreen,
        message: { type: "thought", content: "Page was loading, waiting..." },
      };
    }

    // ------------------------------------------------------------------
    // logged_in_screen — terminal state
    // ------------------------------------------------------------------
    case "logged_in_screen": {
      return {
        nextScreen: null,
        message: {
          type: "complete",
          success: true,
          message: "Successfully logged in!",
        },
      };
    }

    default:
      return {
        nextScreen: null,
        message: { type: "error", message: "Unknown screen type" },
      };
  }
}
