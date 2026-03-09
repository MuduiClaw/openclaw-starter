/**
 * Local test login server — validates the entire login-machine pipeline.
 * Two-step: email → password, then redirects to /dashboard.
 * Run: bun test/server.ts
 */

const PORT = 7799;
const TEST_EMAIL = "test@example.com";
const TEST_PASS = "hunter2";

// Session store
const sessions = new Set<string>();

function html(body: string, title = "Login") {
  return new Response(
    `<!DOCTYPE html>
<html><head><title>${title}</title><meta charset="utf-8">
<style>
  body { font-family: system-ui; max-width: 400px; margin: 60px auto; padding: 20px; }
  form { display: flex; flex-direction: column; gap: 12px; }
  input { padding: 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 16px; }
  button { padding: 10px; background: #0066ff; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
  button:hover { background: #0052cc; }
  .error { color: red; font-size: 14px; }
  h1 { font-size: 24px; margin-bottom: 8px; }
  .dashboard { background: #f0f8f0; padding: 20px; border-radius: 8px; }
</style></head>
<body>${body}</body></html>`,
    { headers: { "Content-Type": "text/html" } },
  );
}

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);

    // Step 1: Email form
    if (url.pathname === "/login" && req.method === "GET") {
      const error = url.searchParams.get("error");
      return html(`
        <h1>Sign In</h1>
        ${error ? `<p class="error">${error}</p>` : ""}
        <form method="POST" action="/login/email">
          <label for="email">Email address</label>
          <input type="email" id="email" name="email" placeholder="you@example.com" required>
          <button type="submit">Continue</button>
        </form>
      `);
    }

    // Step 1 submit
    if (url.pathname === "/login/email" && req.method === "POST") {
      const body = await req.formData();
      const email = body.get("email")?.toString() || "";
      if (email !== TEST_EMAIL) {
        return Response.redirect(`/login?error=Account+not+found`, 302);
      }
      return html(`
        <h1>Enter Password</h1>
        <p>Welcome back, ${email}</p>
        <form method="POST" action="/login/password">
          <input type="hidden" name="email" value="${email}">
          <label for="password">Password</label>
          <input type="password" id="password" name="password" placeholder="Password" required>
          <button type="submit">Sign In</button>
        </form>
      `, "Enter Password");
    }

    // Step 2 submit
    if (url.pathname === "/login/password" && req.method === "POST") {
      const body = await req.formData();
      const email = body.get("email")?.toString() || "";
      const password = body.get("password")?.toString() || "";
      if (password !== TEST_PASS) {
        return html(`
          <h1>Enter Password</h1>
          <p>Welcome back, ${email}</p>
          <form method="POST" action="/login/password">
            <input type="hidden" name="email" value="${email}">
            <label for="password">Password</label>
            <input type="password" id="password" name="password" placeholder="Password" required>
            <p class="error">Incorrect password. Try again.</p>
            <button type="submit">Sign In</button>
          </form>
        `, "Enter Password");
      }
      const sid = crypto.randomUUID();
      sessions.add(sid);
      const res = Response.redirect("/dashboard", 302);
      res.headers.set("Set-Cookie", `session=${sid}; Path=/`);
      return res;
    }

    // Dashboard (logged in)
    if (url.pathname === "/dashboard") {
      return html(`
        <div class="dashboard">
          <h1>🎉 Dashboard</h1>
          <p>Welcome! You are successfully logged in.</p>
          <p>This is your account overview.</p>
          <a href="/logout">Log out</a>
        </div>
      `, "Dashboard - Logged In");
    }

    // Verification code page (for testing verification_screen)
    if (url.pathname === "/verify" && req.method === "GET") {
      return html(`
        <h1>Verify Your Email</h1>
        <p>We sent a verification code to t***@example.com</p>
        <form method="POST" action="/verify">
          <label for="code">Verification code</label>
          <input type="text" id="code" name="code" maxlength="6" inputmode="numeric" pattern="[0-9]*" placeholder="Enter 6-digit code" required autocomplete="one-time-code">
          <button type="submit">Verify</button>
        </form>
      `, "Email Verification");
    }

    return Response.redirect("/login", 302);
  },
});

console.log(`Test login server running at http://localhost:${PORT}/login`);
console.log(`Credentials: ${TEST_EMAIL} / ${TEST_PASS}`);
