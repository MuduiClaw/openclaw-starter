/**
 * CapSolver integration — solve Turnstile, reCAPTCHA, hCaptcha.
 * Config: ~/clawd/config/capsolver.json
 */

import { readFileSync } from "fs";
import { resolve } from "path";
import type { Page } from "playwright";

const CONFIG_PATH = resolve(
  process.env.HOME || "~",
  "clawd/config/capsolver.json",
);

function loadApiKey(): string {
  const raw = readFileSync(CONFIG_PATH, "utf-8");
  return JSON.parse(raw).api_key;
}

const API = "https://api.capsolver.com";

// ---------------------------------------------------------------------------
// Generic task solver
// ---------------------------------------------------------------------------

async function solveTask(
  taskPayload: Record<string, unknown>,
  maxPollSec = 120,
): Promise<string | null> {
  const clientKey = loadApiKey();

  const createRes = await fetch(`${API}/createTask`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ clientKey, task: taskPayload }),
  });
  const create = (await createRes.json()) as Record<string, unknown>;

  if ((create.errorId as number) !== 0) {
    console.warn(`[captcha] CapSolver create error: ${create.errorDescription}`);
    return null;
  }

  const taskId = create.taskId as string;

  for (let i = 0; i < maxPollSec / 3; i++) {
    await new Promise((r) => setTimeout(r, 3000));

    const pollRes = await fetch(`${API}/getTaskResult`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ clientKey, taskId }),
    });
    const poll = (await pollRes.json()) as Record<string, unknown>;

    if (poll.status === "ready") {
      const sol = poll.solution as Record<string, string> | undefined;
      return sol?.token || sol?.gRecaptchaResponse || null;
    }
    if ((poll.errorId as number) !== 0) {
      console.warn(`[captcha] CapSolver poll error: ${poll.errorDescription}`);
      return null;
    }
  }

  console.warn("[captcha] CapSolver timeout");
  return null;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export async function solveTurnstile(
  siteUrl: string,
  siteKey: string,
): Promise<string | null> {
  return solveTask({
    type: "AntiTurnstileTaskProxyLess",
    websiteURL: siteUrl,
    websiteKey: siteKey,
  });
}

export async function solveRecaptchaV2(
  siteUrl: string,
  siteKey: string,
): Promise<string | null> {
  return solveTask(
    { type: "ReCaptchaV2TaskProxyLess", websiteURL: siteUrl, websiteKey: siteKey },
    180,
  );
}

export async function solveHCaptcha(
  siteUrl: string,
  siteKey: string,
): Promise<string | null> {
  return solveTask({
    type: "HCaptchaTaskProxyLess",
    websiteURL: siteUrl,
    websiteKey: siteKey,
  });
}

// ---------------------------------------------------------------------------
// Page helpers — detect captcha type & sitekey from live DOM
// ---------------------------------------------------------------------------

export interface CaptchaInfo {
  type: "turnstile" | "recaptcha_v2" | "recaptcha_v3" | "hcaptcha" | "unknown";
  siteKey: string | null;
}

/** Detect captcha type and sitekey from the live page DOM. */
export async function detectCaptcha(page: Page): Promise<CaptchaInfo> {
  return page.evaluate(() => {
    // Turnstile
    const turnstile =
      document.querySelector("[data-sitekey].cf-turnstile") ||
      document.querySelector("iframe[src*='challenges.cloudflare.com']");
    if (turnstile) {
      const key =
        (turnstile as HTMLElement).dataset?.sitekey ||
        new URL((turnstile as HTMLIFrameElement).src || "").searchParams.get("k");
      return { type: "turnstile" as const, siteKey: key || null };
    }

    // reCAPTCHA
    const recaptcha =
      document.querySelector(".g-recaptcha[data-sitekey]") ||
      document.querySelector("iframe[src*='google.com/recaptcha']");
    if (recaptcha) {
      const key =
        (recaptcha as HTMLElement).dataset?.sitekey ||
        new URL((recaptcha as HTMLIFrameElement).src || "").searchParams.get("k");
      const isV3 = document.querySelector(
        "script[src*='recaptcha/api.js?render=']",
      );
      return {
        type: isV3 ? ("recaptcha_v3" as const) : ("recaptcha_v2" as const),
        siteKey: key || null,
      };
    }

    // hCaptcha
    const hcaptcha =
      document.querySelector(".h-captcha[data-sitekey]") ||
      document.querySelector("iframe[src*='hcaptcha.com']");
    if (hcaptcha) {
      const key = (hcaptcha as HTMLElement).dataset?.sitekey || null;
      return { type: "hcaptcha" as const, siteKey: key || null };
    }

    // Cloudflare challenge page (no widget, full-page challenge)
    if (document.title === "Just a moment...") {
      return { type: "turnstile" as const, siteKey: null };
    }

    return { type: "unknown" as const, siteKey: null };
  });
}

/** Inject a solved captcha token into the page. */
export async function injectCaptchaToken(
  page: Page,
  info: CaptchaInfo,
  token: string,
): Promise<boolean> {
  return page.evaluate(
    ({ type, token }) => {
      if (type === "turnstile") {
        const resp = document.querySelector<HTMLInputElement>(
          '[name="cf-turnstile-response"]',
        );
        if (resp) {
          resp.value = token;
          return true;
        }
        // Try Turnstile JS callback
        if ((window as any).turnstile) {
          try {
            const widgets = document.querySelectorAll(".cf-turnstile");
            widgets.forEach((w) => {
              const id = (w as any)._widgetId;
              if (id) (window as any).turnstile.getResponse(id);
            });
          } catch {}
        }
        return false;
      }

      if (type.startsWith("recaptcha")) {
        const resp = document.querySelector<HTMLTextAreaElement>(
          "#g-recaptcha-response",
        );
        if (resp) {
          resp.value = token;
          resp.style.display = "none";
          // Trigger callback
          const cb = (window as any).___grecaptcha_cfg?.clients?.[0];
          if (cb) {
            const findCallback = (obj: any): Function | null => {
              for (const key of Object.keys(obj || {})) {
                if (typeof obj[key] === "function") return obj[key];
                if (typeof obj[key] === "object") {
                  const found = findCallback(obj[key]);
                  if (found) return found;
                }
              }
              return null;
            };
            const fn = findCallback(cb);
            if (fn) fn(token);
          }
          return true;
        }
        return false;
      }

      if (type === "hcaptcha") {
        const resp = document.querySelector<HTMLTextAreaElement>(
          "[name='h-captcha-response']",
        );
        if (resp) {
          resp.value = token;
          return true;
        }
        return false;
      }

      return false;
    },
    { type: info.type, token },
  );
}
