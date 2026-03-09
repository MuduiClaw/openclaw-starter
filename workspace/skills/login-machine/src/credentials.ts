/**
 * 1Password credential integration.
 *
 * Fetches login credentials via the `op` CLI. Credentials are retrieved
 * transiently and never logged.
 */

import { execSync } from "child_process";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface Credentials {
  fields: Record<string, string>; // field name → value
  itemTitle: string;
}

interface OpField {
  id: string;
  type: string;
  label: string;
  value?: string;
  purpose?: string;
}

interface OpItem {
  id: string;
  title: string;
  urls?: Array<{ href: string }>;
  fields?: OpField[];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** 1Password vault to use (service accounts require explicit vault). */
const OP_VAULT = process.env.OP_VAULT || "Server-MacMini";

/** Run an `op` command with 1Password env sourced. */
function runOp(args: string): string {
  const cmd = `source ~/.config/openclaw/1password.env 2>/dev/null; op ${args}`;
  return execSync(cmd, {
    encoding: "utf-8",
    shell: "/bin/zsh",
    timeout: 15000,
    env: { ...process.env, PATH: process.env.PATH },
  }).trim();
}

/** Inject `--vault` into op item commands if not already present. */
function vaultFlag(): string {
  return `--vault "${OP_VAULT}"`;
}

/** Extract domain from a URL string. */
function extractDomain(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return url.replace(/^(https?:\/\/)?(www\.)?/, "").split("/")[0];
  }
}

/** Map LLM-detected input types to 1Password field values. */
function mapFieldsToCredentials(
  opFields: OpField[],
  requestedInputs: Array<{ type: string; name: string }>,
): Record<string, string> {
  const result: Record<string, string> = {};

  // Build lookup from op fields
  const username =
    opFields.find((f) => f.purpose === "USERNAME")?.value ||
    opFields.find((f) => f.id === "username")?.value ||
    opFields.find((f) => f.label?.toLowerCase() === "username")?.value ||
    opFields.find((f) => f.label?.toLowerCase() === "email")?.value ||
    "";

  const password =
    opFields.find((f) => f.purpose === "PASSWORD")?.value ||
    opFields.find((f) => f.id === "password")?.value ||
    opFields.find((f) => f.label?.toLowerCase() === "password")?.value ||
    "";

  const otp =
    opFields.find((f) => f.type === "OTP")?.value ||
    opFields.find((f) => f.id === "one-time password")?.value ||
    "";

  for (const input of requestedInputs) {
    switch (input.type) {
      case "email":
      case "text":
        result[input.name] = username;
        break;
      case "password":
        result[input.name] = password;
        break;
      case "otp":
        result[input.name] = otp;
        break;
      case "tel":
        // Try phone field
        const phone = opFields.find(
          (f) =>
            f.label?.toLowerCase().includes("phone") ||
            f.id?.includes("phone"),
        );
        result[input.name] = phone?.value || "";
        break;
      default:
        result[input.name] = "";
    }
  }

  return result;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Get credentials for a target URL.
 *
 * @param targetUrl - The URL we're trying to log into
 * @param itemRef - Optional 1Password item reference (name or ID)
 * @param requestedInputs - Fields the login form needs (from LLM analysis)
 */
export async function getCredentials(
  targetUrl: string,
  requestedInputs: Array<{ type: string; name: string }>,
  itemRef?: string,
): Promise<Credentials | null> {
  try {
    let item: OpItem;

    if (itemRef) {
      // Direct lookup by reference
      const json = runOp(`item get "${itemRef}" ${vaultFlag()} --format json`);
      item = JSON.parse(json);
    } else {
      // Fuzzy match by domain
      const domain = extractDomain(targetUrl);
      const listJson = runOp(`item list --categories Login ${vaultFlag()} --format json`);
      const items: OpItem[] = JSON.parse(listJson);

      // Score items by URL match
      const scored = items
        .map((it) => {
          let score = 0;
          // Check URLs
          for (const u of it.urls || []) {
            const itemDomain = extractDomain(u.href);
            if (itemDomain === domain) score += 10;
            else if (
              domain.includes(itemDomain) ||
              itemDomain.includes(domain)
            )
              score += 5;
          }
          // Check title
          if (it.title.toLowerCase().includes(domain.split(".")[0]))
            score += 3;
          return { item: it, score };
        })
        .filter((s) => s.score > 0)
        .sort((a, b) => b.score - a.score);

      if (scored.length === 0) {
        console.warn(
          `[credentials] No 1Password items found matching domain: ${domain}`,
        );
        return null;
      }

      // Get full item details for best match
      const bestId = scored[0].item.id;
      const json = runOp(`item get "${bestId}" ${vaultFlag()} --format json`);
      item = JSON.parse(json);
    }

    // Map fields
    const fields = mapFieldsToCredentials(
      item.fields || [],
      requestedInputs,
    );

    // Verify we have at least some credentials
    const hasValues = Object.values(fields).some((v) => v.length > 0);
    if (!hasValues) {
      if (process.env.DEBUG_AGENT) {
        console.warn(`[DEBUG] fields generated:`, JSON.stringify(fields));
        console.warn(`[DEBUG] requestedInputs:`, JSON.stringify(requestedInputs));
      }
      console.warn(
        `[credentials] Item "${item.title}" found but no matching fields`,
      );
      return null;
    }

    return {
      fields,
      itemTitle: item.title,
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    // Don't leak credential details in error messages
    if (msg.includes("not found") || msg.includes("No items")) {
      console.warn(`[credentials] Item not found in 1Password`);
    } else {
      console.warn(`[credentials] 1Password error: ${msg.substring(0, 100)}`);
    }
    return null;
  }
}
