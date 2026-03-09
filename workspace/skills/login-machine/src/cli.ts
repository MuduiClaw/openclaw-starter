#!/usr/bin/env bun
/**
 * Login Machine CLI — Universal browser login automation.
 *
 * Usage:
 *   login-machine <url> [--item <1password-item>] [--model <model>] [--cdp <url>]
 *                       [--max-steps <n>] [--timeout <sec>] [--verbose]
 */

import { createSession, closeSession } from "./browser";
import { analyzeLoginPage, handleScreen } from "./agent";
import { getCredentials } from "./credentials";
import type { LoginState, LoginResult } from "./types";

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

interface CliArgs {
  url: string;
  item?: string;
  model?: string;
  cdp: string;
  maxSteps: number;
  timeout: number;
  verbose: boolean;
  headed: boolean;
  help: boolean;
}

function parseArgs(argv: string[]): CliArgs {
  const args: CliArgs = {
    url: "",
    cdp: "launch",
    maxSteps: 20,
    timeout: 120,
    verbose: false,
    headed: false,
    help: false,
  };

  const positional: string[] = [];

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    switch (arg) {
      case "--help":
      case "-h":
        args.help = true;
        break;
      case "--item":
        args.item = argv[++i];
        break;
      case "--model":
        args.model = argv[++i];
        break;
      case "--cdp":
        args.cdp = argv[++i];
        break;
      case "--max-steps":
        args.maxSteps = parseInt(argv[++i], 10);
        break;
      case "--timeout":
        args.timeout = parseInt(argv[++i], 10);
        break;
      case "--verbose":
      case "-v":
        args.verbose = true;
        break;
      case "--headed":
        args.headed = true;
        break;
      default:
        if (!arg.startsWith("-")) {
          positional.push(arg);
        }
    }
  }

  args.url = positional[0] || "";
  return args;
}

function printHelp() {
  console.log(`
login-machine — Universal browser login automation

Usage:
  bun src/cli.ts <url> [options]

Arguments:
  url                Target login page URL

Options:
  --item <ref>       1Password item reference (name or ID)
  --model <model>    LLM model (default: claude-sonnet-4-5)
  --cdp <url>        CDP WebSocket URL (default: ws://127.0.0.1:18800)
  --max-steps <n>    Max loop iterations (default: 20)
  --timeout <sec>    Overall timeout in seconds (default: 120)
  --verbose, -v      Show detailed step logs
  --help, -h         Show this help

Environment:
  LM_BASE_URL        LLM API base URL (default: http://127.0.0.1:8045/v1)
  LM_API_KEY         LLM API key (default: Antigravity key)
  LM_MODEL           LLM model override

Examples:
  bun src/cli.ts https://github.com/login --item "GitHub"
  bun src/cli.ts https://app.example.com/signin --verbose
  bun src/cli.ts https://netflix.com/login --item "Netflix" --timeout 60
`);
}

// ---------------------------------------------------------------------------
// Main login loop
// ---------------------------------------------------------------------------

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help || !args.url) {
    printHelp();
    process.exit(args.help ? 0 : 1);
  }

  // Set model env if specified
  if (args.model) {
    process.env.LM_MODEL = args.model;
  }

  const startTime = Date.now();
  const screenTypes: string[] = [];
  let step = 0;

  const log = (msg: string) => {
    if (args.verbose) console.log(`[step ${step}] ${msg}`);
  };

  // Overall timeout
  const timer = setTimeout(() => {
    const result: LoginResult = {
      success: false,
      finalUrl: "",
      steps: step,
      screenTypes,
      duration: Date.now() - startTime,
      error: `Timeout after ${args.timeout}s`,
    };
    console.log(JSON.stringify(result, null, 2));
    process.exit(1);
  }, args.timeout * 1000);

  let session;
  try {
    // Connect to browser
    log("Connecting to browser...");
    session = await createSession(args.cdp, { headed: args.headed });

    // Navigate to target URL
    log(`Navigating to ${args.url}`);
    await session.page.goto(args.url, {
      waitUntil: "domcontentloaded",
      timeout: 30000,
    });
    // Give SPAs (X, React apps) time to hydrate before first analysis
    await session.page.waitForTimeout(5000);

    // Main observe-act loop
    let currentScreen: LoginState | null = null;
    let consecutiveSameType = 0;
    let lastScreenType = "";

    while (step < args.maxSteps) {
      step++;

      // Observe: analyze the page
      if (!currentScreen) {
        log("Analyzing page...");
        const analysis = await analyzeLoginPage(session, args.verbose);
        currentScreen = analysis.screen;
      }

      screenTypes.push(currentScreen.type);
      log(`Screen type: ${currentScreen.type}`);

      // Stuck detection: bail if same screen type 4 times in a row
      if (currentScreen.type === lastScreenType) {
        consecutiveSameType++;
        if (consecutiveSameType >= 4) {
          clearTimeout(timer);
          const result: LoginResult = {
            success: false,
            finalUrl: session.page.url(),
            steps: step,
            screenTypes,
            duration: Date.now() - startTime,
            error: `Stuck: same screen type "${currentScreen.type}" detected ${consecutiveSameType} times in a row`,
          };
          console.log(JSON.stringify(result, null, 2));
          await closeSession(session);
          process.exit(1);
        }
      } else {
        consecutiveSameType = 1;
      }
      lastScreenType = currentScreen.type;

      // Terminal states
      if (currentScreen.type === "logged_in_screen") {
        clearTimeout(timer);
        const result: LoginResult = {
          success: true,
          finalUrl: session.page.url(),
          steps: step,
          screenTypes,
          duration: Date.now() - startTime,
        };
        console.log(JSON.stringify(result, null, 2));
        await closeSession(session);
        process.exit(0);
      }

      // Credential form: fetch from 1Password
      let userInput: Record<string, string> | undefined;
      if (
        currentScreen.type === "credential_login_form" &&
        currentScreen.inputs
      ) {
        log("Fetching credentials from 1Password...");
        const creds = await getCredentials(
          args.url,
          currentScreen.inputs.map((i) => ({
            type: i.type,
            name: i.name,
          })),
          args.item,
        );

        if (creds) {
          log(`Using credentials from: ${creds.itemTitle}`);
          userInput = creds.fields;
        } else {
          // No credentials found — report and exit
          clearTimeout(timer);
          const result: LoginResult = {
            success: false,
            finalUrl: session.page.url(),
            steps: step,
            screenTypes,
            duration: Date.now() - startTime,
            error:
              "No matching credentials found in 1Password. Use --item to specify.",
          };
          console.log(JSON.stringify(result, null, 2));
          await closeSession(session);
          process.exit(1);
        }
      }

      // Act: handle the screen
      const { nextScreen, message } = await handleScreen(
        session,
        currentScreen,
        userInput,
        args.verbose,
      );

      log(`Action result: ${message.type} — ${
        "action" in message
          ? message.action
          : "content" in message
            ? message.content
            : "message" in message
              ? message.message
              : ""
      }`);

      // Check for terminal messages
      if (message.type === "complete") {
        clearTimeout(timer);
        const result: LoginResult = {
          success: message.success,
          finalUrl: session.page.url(),
          steps: step,
          screenTypes,
          duration: Date.now() - startTime,
          error: message.success ? undefined : message.message,
        };
        console.log(JSON.stringify(result, null, 2));
        await closeSession(session);
        process.exit(message.success ? 0 : 1);
      }

      if (message.type === "error") {
        log(`Error: ${message.message}`);
        // Continue loop — might recover on next analysis
      }

      // Prepare next iteration
      currentScreen = nextScreen; // null means re-analyze next time
    }

    // Max steps reached
    clearTimeout(timer);
    const result: LoginResult = {
      success: false,
      finalUrl: session.page.url(),
      steps: step,
      screenTypes,
      duration: Date.now() - startTime,
      error: `Max steps (${args.maxSteps}) reached without successful login`,
    };
    console.log(JSON.stringify(result, null, 2));
    await closeSession(session);
    process.exit(1);
  } catch (err) {
    clearTimeout(timer);
    const msg = err instanceof Error ? err.message : String(err);
    const result: LoginResult = {
      success: false,
      finalUrl: session?.page?.url() || "",
      steps: step,
      screenTypes,
      duration: Date.now() - startTime,
      error: msg,
    };
    console.log(JSON.stringify(result, null, 2));
    if (session) await closeSession(session).catch(() => {});
    process.exit(1);
  }
}

main();
