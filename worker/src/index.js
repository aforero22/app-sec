// ─────────────────────────────────────────────
// Cloudflare Worker — CSE Homework Task 6
//
// Features:
//   1. Redirect cURL requests to CF Workers docs
//   2. Cookie bypass (cf-noredir=true skips redirect)
//   3. WAF-like blocking for SQLi and XSS patterns
// ─────────────────────────────────────────────

const REDIRECT_TARGET =
  "https://developers.cloudflare.com/workers/learning/";

// ── WAF Rule Definitions ─────────────────────
const SQLI_RULES = [
  { id: "SQLI-001", rx: /('|%27)\s*(OR|AND)\s+\d+\s*=\s*\d+/i },
  { id: "SQLI-002", rx: /UNION\s+(ALL\s+)?SELECT/i },
  { id: "SQLI-003", rx: /;\s*(DROP|ALTER|DELETE|INSERT|UPDATE)\s/i },
  { id: "SQLI-004", rx: /SLEEP\s*\(\d+\)/i },
  { id: "SQLI-005", rx: /INFORMATION_SCHEMA/i },
];

const XSS_RULES = [
  { id: "XSS-001", rx: /<script[\s>]/i },
  { id: "XSS-002", rx: /javascript\s*:/i },
  { id: "XSS-003", rx: /on(error|load|click|mouseover|focus|blur)\s*=/i },
  { id: "XSS-004", rx: /<iframe[\s>]/i },
  { id: "XSS-005", rx: /document\.(cookie|write|location)/i },
];

const ALL_RULES = [
  ...SQLI_RULES.map((r) => ({ ...r, category: "SQLi" })),
  ...XSS_RULES.map((r) => ({ ...r, category: "XSS" })),
];

// ── Helpers ──────────────────────────────────

/**
 * Check if the request carries the bypass cookie.
 * Cookies are semicolon-delimited: "key=val; key2=val2"
 */
function hasBypassCookie(request) {
  const raw = request.headers.get("cookie") || "";
  return raw.split(";").some((c) => c.trim() === "cf-noredir=true");
}

/**
 * Scan a string for SQLi / XSS patterns.
 * Returns the first matching rule, or null.
 */
function scanForThreats(input) {
  for (const rule of ALL_RULES) {
    if (rule.rx.test(input)) {
      return rule;
    }
  }
  return null;
}

/**
 * Build a 403 response and log the block event.
 */
function blocked(rule, url) {
  const blockId = crypto.randomUUID();

  // Structured log — visible via `wrangler tail`
  console.log(
    JSON.stringify({
      event: "WAF_BLOCK",
      blockId,
      ruleId: rule.id,
      category: rule.category,
      url,
      timestamp: new Date().toISOString(),
    })
  );

  return new Response(
    JSON.stringify({ error: "Blocked", ray: blockId, code: 403 }),
    {
      status: 403,
      headers: {
        "Content-Type": "application/json",
        "X-WAF-Block": rule.id,
        "X-WAF-Category": rule.category,
        "Cache-Control": "no-store",
      },
    }
  );
}

// ── Main Handler (ES Modules format) ─────────
export default {
  async fetch(request) {
    // 1. Cookie bypass — skip all processing
    if (hasBypassCookie(request)) {
      return fetch(request);
    }

    // 2. WAF — inspect URL path + query string (raw and decoded)
    const url = new URL(request.url);
    const targets = [
      url.pathname + url.search,
      decodeURIComponent(url.pathname + url.search),
    ];

    for (const target of targets) {
      const match = scanForThreats(target);
      if (match) {
        return blocked(match, request.url);
      }
    }

    // 3. cURL redirect
    const ua = request.headers.get("user-agent") || "";
    if (/curl/i.test(ua)) {
      return Response.redirect(REDIRECT_TARGET, 302);
    }

    // 4. Pass through to origin
    return fetch(request);
  },
};
