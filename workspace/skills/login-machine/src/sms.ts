/**
 * 5sim SMS verification — buy numbers, receive codes.
 * Config: ~/clawd/config/5sim.json
 */

import { readFileSync } from "fs";
import { resolve } from "path";

const CONFIG_PATH = resolve(
  process.env.HOME || "~",
  "clawd/config/5sim.json",
);

function loadApiKey(): string {
  const raw = readFileSync(CONFIG_PATH, "utf-8");
  return JSON.parse(raw).api_key;
}

const BASE = "https://5sim.net/v1";

interface SmsOrder {
  id: number;
  phone: string;
  country: string;
  operator: string;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Buy a phone number for receiving SMS.
 * @param product - Service name (e.g. "google", "twitter", "any")
 * @param country - Country code (e.g. "russia", "usa", "any")
 * @param operator - Operator (e.g. "any")
 */
export async function buyNumber(
  product = "any",
  country = "any",
  operator = "any",
): Promise<SmsOrder | null> {
  const key = loadApiKey();
  const res = await fetch(
    `${BASE}/user/buy/activation/${country}/${operator}/${product}`,
    { headers: { Authorization: `Bearer ${key}`, Accept: "application/json" } },
  );

  if (!res.ok) {
    console.warn(`[sms] 5sim buy error: ${res.status} ${await res.text()}`);
    return null;
  }

  const data = (await res.json()) as Record<string, unknown>;
  return {
    id: data.id as number,
    phone: data.phone as string,
    country: data.country as string,
    operator: data.operator as string,
  };
}

/**
 * Poll for incoming SMS code on a bought number.
 * Returns the extracted numeric code, or raw text if no code pattern found.
 */
export async function waitForCode(
  orderId: number,
  timeoutMs = 120_000,
): Promise<string | null> {
  const key = loadApiKey();
  const start = Date.now();

  while (Date.now() - start < timeoutMs) {
    const res = await fetch(`${BASE}/user/check/${orderId}`, {
      headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
    });

    if (!res.ok) {
      console.warn(`[sms] 5sim check error: ${res.status}`);
      await delay(5000);
      continue;
    }

    const data = (await res.json()) as Record<string, unknown>;
    const smsList = data.sms as Array<Record<string, string>> | undefined;

    if (smsList && smsList.length > 0) {
      const last = smsList[smsList.length - 1];
      // Extract 4-8 digit code
      const match = last.text?.match(/\b(\d{4,8})\b/);
      return match ? match[1] : last.code || last.text;
    }

    const status = data.status as string;
    if (["CANCELED", "TIMEOUT", "BANNED"].includes(status)) {
      console.warn(`[sms] Order ${orderId} ended: ${status}`);
      return null;
    }

    await delay(5000);
  }

  console.warn("[sms] Timeout waiting for SMS code");
  return null;
}

/** Cancel an active SMS order. */
export async function cancelOrder(orderId: number): Promise<void> {
  const key = loadApiKey();
  await fetch(`${BASE}/user/cancel/${orderId}`, {
    headers: { Authorization: `Bearer ${key}` },
  }).catch(() => {});
}

/** Check 5sim account balance. */
export async function getBalance(): Promise<number> {
  const key = loadApiKey();
  const res = await fetch(`${BASE}/user/profile`, {
    headers: { Authorization: `Bearer ${key}`, Accept: "application/json" },
  });
  if (!res.ok) return -1;
  const data = (await res.json()) as Record<string, unknown>;
  return (data.balance as number) || 0;
}

function delay(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
