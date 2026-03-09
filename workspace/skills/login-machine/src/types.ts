import { z } from "zod";

// ---------------------------------------------------------------------------
// Screen type enum
// ---------------------------------------------------------------------------

export const ScreenType = z.enum([
  "credential_login_form",
  "choice_screen",
  "magic_login_link",
  "logged_in_screen",
  "loading_screen",
  "blocked_screen",
  "captcha_screen",
  "verification_screen",
]);

// ---------------------------------------------------------------------------
// Element schemas
// ---------------------------------------------------------------------------

export const InputType = z.enum([
  "text",
  "email",
  "password",
  "tel",
  "select",
  "otp",
]);

export const InputElement = z.object({
  type: InputType,
  name: z.string().describe("Field name/identifier"),
  label: z.string().nullable().describe("Visible label for the field"),
  options: z
    .array(z.string())
    .optional()
    .nullable()
    .describe("Options for select fields"),
  playwrightLocator: z.string().describe("Playwright locator for this element"),
  errorMessage: z.string().optional().nullable(),
});

export const SubmitElement = z.object({
  type: z.enum(["submit", "button"]),
  name: z.string(),
  label: z.string().nullable(),
  playwrightLocator: z
    .string()
    .describe("Playwright locator for the submit button"),
});

export const ChoiceOption = z.object({
  optionText: z.string().describe("The text of this option"),
  optionPlaywrightLocator: z
    .string()
    .describe("Playwright locator for this option"),
});

// ---------------------------------------------------------------------------
// Unified login state schema — flat union with optional fields
// ---------------------------------------------------------------------------

export const LoginStateSchema = z.object({
  type: ScreenType.describe("The type of screen detected"),
  inputs: z
    .array(InputElement)
    .optional()
    .describe("Input fields for credential forms"),
  submit: SubmitElement.optional().describe(
    "Submit button for credential forms, or for choice screens that require a separate confirm/continue button",
  ),
  name: z.string().optional().describe("Name of choice screen"),
  label: z.string().nullable().optional().describe("Label for choice screen"),
  options: z
    .array(ChoiceOption)
    .optional()
    .describe("Options for choice screen"),
  instructionText: z
    .string()
    .optional()
    .describe("Instructions for magic link"),
  dismissPlaywrightLocator: z
    .string()
    .optional()
    .describe("Locator to dismiss blocking element"),
  // captcha_screen fields
  captchaType: z
    .enum(["turnstile", "recaptcha_v2", "recaptcha_v3", "hcaptcha", "cloudflare_challenge", "unknown"])
    .optional()
    .describe("Type of CAPTCHA detected"),
  siteKey: z
    .string()
    .nullable()
    .optional()
    .describe("CAPTCHA sitekey from DOM"),
  // verification_screen fields
  verificationMethod: z
    .enum(["sms", "email", "authenticator", "unknown"])
    .optional()
    .describe("How verification code is delivered"),
  verificationHint: z
    .string()
    .nullable()
    .optional()
    .describe("Phone/email hint shown on page, e.g. ***1234 or h***@gmail.com"),
});

export type LoginState = z.infer<typeof LoginStateSchema>;
export type InputElementType = z.infer<typeof InputElement>;
export type ChoiceOptionType = z.infer<typeof ChoiceOption>;

// ---------------------------------------------------------------------------
// Agent messages
// ---------------------------------------------------------------------------

export type AgentMessage =
  | { type: "thought"; content: string }
  | { type: "action"; action: string }
  | { type: "input_request"; screen: LoginState }
  | { type: "complete"; success: boolean; message: string }
  | { type: "error"; message: string };

// ---------------------------------------------------------------------------
// CLI result
// ---------------------------------------------------------------------------

export interface LoginResult {
  success: boolean;
  finalUrl: string;
  steps: number;
  screenTypes: string[];
  duration: number;
  error?: string;
}
