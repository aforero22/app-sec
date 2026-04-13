import { Hono } from "hono";
import { serve } from "@hono/node-server";

const app = new Hono();

// ── Health check ─────────────────────────────
app.get("/health", (c) => c.json({ status: "ok" }));

// ── Secure area (protected by Zero Trust) ────
app.get("/secure", (c) => {
  return c.html(`
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Secure Area</title></head>
    <body>
      <h1>Zero Trust Protected Area</h1>
      <p>If you can see this, you passed Cloudflare Access authentication.</p>
      <h2>Request Headers</h2>
      <pre>${JSON.stringify(Object.fromEntries(c.req.raw.headers), null, 2)}</pre>
    </body>
    </html>
  `);
});

// ── Echo all request headers (main endpoint) ─
app.all("/*", (c) => {
  const headers = Object.fromEntries(c.req.raw.headers);

  // Content negotiation: JSON for programmatic clients, HTML for browsers
  const accept = c.req.header("accept") || "";
  if (accept.includes("text/html")) {
    return c.html(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>Request Headers</title>
        <style>
          body { font-family: system-ui, sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; }
          h1 { color: #f6821f; }
          pre { background: #1a1a2e; color: #e0e0e0; padding: 1.5rem; border-radius: 8px; overflow-x: auto; }
          .meta { color: #888; font-size: 0.9rem; }
        </style>
      </head>
      <body>
        <h1>HTTP Request Headers</h1>
        <p class="meta">${c.req.method} ${c.req.url}</p>
        <pre>${JSON.stringify(headers, null, 2)}</pre>
      </body>
      </html>
    `);
  }

  return c.json({ method: c.req.method, url: c.req.url, headers });
});

// ── Start server ─────────────────────────────
const port = parseInt(process.env.PORT || "8080", 10);
serve({ fetch: app.fetch, port }, () => {
  console.log(`Origin server listening on :${port}`);
});
