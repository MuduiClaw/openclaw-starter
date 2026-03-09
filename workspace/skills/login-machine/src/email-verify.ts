/**
 * Email verification — poll IMAP for verification codes/links.
 * Config: ~/clawd/config/email.json (bm@xiu.ai)
 */

import { readFileSync } from "fs";
import { resolve } from "path";
import { execSync } from "child_process";

interface EmailConfig {
  email: string;
  password: string;
  imap_server: string;
  imap_port: number;
}

const CONFIG_PATH = resolve(
  process.env.HOME || "~",
  "clawd/config/email.json",
);

function loadConfig(): EmailConfig {
  const raw = readFileSync(CONFIG_PATH, "utf-8");
  return JSON.parse(raw);
}

export interface VerificationResult {
  code?: string;
  link?: string;
  subject: string;
  body: string;
}

/**
 * Poll IMAP inbox for a verification email and extract code/link.
 * Uses Python's imaplib via subprocess (zero extra npm deps).
 */
export async function waitForVerificationEmail(
  options: {
    subjectPattern?: string;
    fromPattern?: string;
    timeoutMs?: number;
    pollIntervalMs?: number;
  } = {},
): Promise<VerificationResult | null> {
  const {
    subjectPattern = "verif|code|confirm|activate|OTP|验证",
    fromPattern,
    timeoutMs = 120_000,
    pollIntervalMs = 8_000,
  } = options;
  const config = loadConfig();
  const start = Date.now();

  while (Date.now() - start < timeoutMs) {
    try {
      const result = fetchRecentEmails(config, subjectPattern, fromPattern);
      if (result) return result;
    } catch {
      // IMAP connection failed, retry
    }
    await new Promise((r) => setTimeout(r, pollIntervalMs));
  }

  console.warn("[email] Timeout waiting for verification email");
  return null;
}

/** Fetch email address from config. */
export function getEmailAddress(): string {
  return loadConfig().email;
}

// ---------------------------------------------------------------------------
// IMAP fetch via Python subprocess
// ---------------------------------------------------------------------------

function fetchRecentEmails(
  config: EmailConfig,
  subjectPattern: string,
  fromPattern?: string,
): VerificationResult | null {
  // Python script to fetch recent unseen emails via IMAP
  const pyScript = `
import imaplib, email, json, re, sys
from email.header import decode_header

m = imaplib.IMAP4_SSL("${config.imap_server}", ${config.imap_port})
m.login("${config.email}", "${config.password}")
m.select("INBOX")

# Search unseen emails from last few minutes
_, nums = m.search(None, "UNSEEN")
if not nums[0]:
    m.logout()
    sys.exit(1)

ids = nums[0].split()[-10:]  # last 10 unseen
results = []
for mid in ids:
    _, data = m.fetch(mid, "(RFC822)")
    msg = email.message_from_bytes(data[0][1])
    
    # Decode subject
    subj_parts = decode_header(msg["Subject"] or "")
    subj = ""
    for part, enc in subj_parts:
        if isinstance(part, bytes):
            subj += part.decode(enc or "utf-8", errors="ignore")
        else:
            subj += str(part)
    
    # Get body
    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            ct = part.get_content_type()
            if ct == "text/plain":
                body = part.get_payload(decode=True).decode("utf-8", errors="ignore")
                break
            elif ct == "text/html" and not body:
                body = part.get_payload(decode=True).decode("utf-8", errors="ignore")
    else:
        body = msg.get_payload(decode=True).decode("utf-8", errors="ignore")
    
    results.append({"subject": subj, "from": msg["From"] or "", "body": body[:3000]})

m.logout()
print(json.dumps(results))
`;

  const output = execSync(`python3 -c ${shellEscape(pyScript)}`, {
    encoding: "utf-8",
    timeout: 15000,
    stdio: ["pipe", "pipe", "pipe"],
  }).trim();

  if (!output) return null;

  const emails: Array<{ subject: string; from: string; body: string }> =
    JSON.parse(output);
  const pattern = new RegExp(subjectPattern, "i");
  const fromRe = fromPattern ? new RegExp(fromPattern, "i") : null;

  for (const em of emails) {
    const subjectMatch = pattern.test(em.subject);
    const bodyMatch = pattern.test(em.body);
    const fromMatch = fromRe ? fromRe.test(em.from) : true;

    if ((subjectMatch || bodyMatch) && fromMatch) {
      // Extract verification code (4-8 digits)
      const codeMatch = em.body.match(/\b(\d{4,8})\b/);
      // Extract verification link
      const linkMatch = em.body.match(
        /https?:\/\/[^\s"'<>]+(?:verif|confirm|activate|token|code|auth)[^\s"'<>]*/i,
      );

      return {
        code: codeMatch?.[1],
        link: linkMatch?.[0],
        subject: em.subject,
        body: em.body.substring(0, 500),
      };
    }
  }

  return null;
}

/** Escape a string for use as a shell argument. */
function shellEscape(s: string): string {
  return "'" + s.replace(/'/g, "'\\''") + "'";
}
