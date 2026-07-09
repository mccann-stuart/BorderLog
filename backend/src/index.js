const SECURITY_HEADERS = {
  "X-Content-Type-Options": "nosniff",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains; preload",
  "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'; sandbox",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=(), interest-cohort=()",
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Resource-Policy": "same-origin"
};

const DEFAULT_SECURITY_HEADERS = new Headers(SECURITY_HEADERS);

const HTML_CONTENT_SECURITY_POLICY = [
  "default-src 'none'",
  "base-uri 'none'",
  "connect-src 'none'",
  "font-src 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
  "frame-src 'none'",
  "img-src 'none'",
  "manifest-src 'none'",
  "media-src 'none'",
  "object-src 'none'",
  "script-src 'none'",
  "style-src 'unsafe-inline'",
  "worker-src 'none'"
].join("; ");

const SUPPORT_URL = "https://github.com/mccann-stuart/BorderLog/issues";
const SUPPORT_EMAIL_PATTERN = /^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/i;

const PAGE_STYLES = `
  :root {
    color-scheme: light dark;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    font-synthesis: none;
    line-height: 1.6;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: Canvas;
    color: CanvasText;
  }
  header, main, footer {
    width: min(100% - 2rem, 48rem);
    margin-inline: auto;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    padding-block: 1.25rem;
    border-bottom: 1px solid color-mix(in srgb, CanvasText 18%, transparent);
  }
  .brand {
    color: CanvasText;
    font-size: 1.05rem;
    font-weight: 700;
    text-decoration: none;
  }
  nav { display: flex; gap: 1rem; }
  nav a, main a, footer a {
    color: LinkText;
    text-underline-offset: 0.18em;
  }
  nav a[aria-current="page"] { font-weight: 700; }
  main { padding-block: 2.5rem 3rem; }
  h1, h2 { line-height: 1.2; }
  h1 {
    margin: 0 0 0.5rem;
    font-size: clamp(2rem, 7vw, 3.2rem);
    letter-spacing: -0.035em;
  }
  h2 { margin-top: 2.2rem; font-size: 1.35rem; }
  p, li { max-width: 68ch; }
  .lede { font-size: 1.12rem; }
  .meta, footer { color: GrayText; }
  .notice {
    margin-block: 1.5rem;
    padding: 1rem 1.1rem;
    border: 1px solid color-mix(in srgb, LinkText 35%, transparent);
    border-radius: 0.8rem;
    background: color-mix(in srgb, LinkText 7%, Canvas);
  }
  footer {
    padding-block: 1.5rem 2.5rem;
    border-top: 1px solid color-mix(in srgb, CanvasText 18%, transparent);
    font-size: 0.92rem;
  }
  @media (max-width: 34rem) {
    header { align-items: flex-start; flex-direction: column; }
  }
`;

const createPage = ({ title, description, currentPath, content, supportEmail }) => `<!doctype html>
<html lang="en-GB">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${description}">
  <title>${title} - BorderLog</title>
  <style>${PAGE_STYLES}</style>
</head>
<body>
  <header>
    <a class="brand" href="/privacy">BorderLog</a>
    <nav aria-label="Policy pages">
      <a href="/privacy"${currentPath === "/privacy" ? ' aria-current="page"' : ""}>Privacy</a>
      <a href="/support"${currentPath === "/support" ? ' aria-current="page"' : ""}>Support</a>
    </nav>
  </header>
  <main>
    ${content}
  </main>
  <footer>
    <p>BorderLog is developed by Stuart McCann. Email <a href="mailto:${supportEmail}">${supportEmail}</a> or <a href="${SUPPORT_URL}">open a GitHub issue</a>.</p>
  </footer>
</body>
</html>`;

const createPrivacyPage = (supportEmail) => createPage({
  title: "Privacy Policy",
  description: "How BorderLog handles location, photo, calendar, profile and travel data.",
  currentPath: "/privacy",
  supportEmail,
  content: `
    <h1>Privacy Policy</h1>
    <p class="meta">Effective 9 July 2026</p>
    <p class="lede">BorderLog is a local-first iPhone app. It does not require an online account, run advertising or analytics, track people across apps or websites, or operate an app-owned server that stores travel data.</p>

    <h2>Data BorderLog uses</h2>
    <p>BorderLog can use the following information when you choose to provide it:</p>
    <ul>
      <li><strong>Location:</strong> optional location samples from the app and, when separately approved in iOS, opportunistic widget updates.</li>
      <li><strong>Photos:</strong> optional photo creation dates and location metadata. BorderLog does not read or upload the image contents.</li>
      <li><strong>Calendar:</strong> optional event details needed to identify travel, such as event titles, dates, locations and identifiers. BorderLog does not write to your calendar.</li>
      <li><strong>Profile and travel records:</strong> optional passport nationality, home country, manual stays, corrections and the daily country ledger created from your chosen signals.</li>
      <li><strong>Local app state:</strong> preferences and a random local session identifier used to maintain app state. The identifier is not an online account and is not sent to a BorderLog server.</li>
    </ul>
    <p>This information is used only to infer country presence, calculate travel-day summaries and show the app and widget features you request.</p>

    <h2>Storage and processing</h2>
    <p>Travel records and app state are stored on your device using Apple platform storage, including SwiftData, the app group container, UserDefaults and the Keychain. The current App Store release does not enable BorderLog iCloud synchronisation.</p>
    <p>Some features use Apple system services. For example, MapKit and geocoding may process coordinates or place searches to resolve a country, while iOS provides access to Location Services, Photos and Calendar after you grant permission. Apple processes that information under its own terms and privacy practices. BorderLog does not receive a copy through an app-owned server.</p>

    <h2>Retention and deletion</h2>
    <p>BorderLog keeps local data until you change it or use <strong>Settings &gt; Reset All Data</strong>. Reset All Data permanently removes the app's travel records, profile values, local session identifier and pending widget samples from the device.</p>
    <p>Resetting BorderLog does not change system permission choices. You can withdraw Location, Photos or Calendar access at any time in iOS Settings. If you intend to uninstall BorderLog and want its Keychain-backed values removed first, use Reset All Data before deleting the app.</p>

    <h2>Sharing, tracking and accounts</h2>
    <p>BorderLog does not sell personal data, share it with advertisers or data brokers, or use it to track you. It has no subscriptions and does not require or create an online BorderLog account.</p>
    <p>If you follow the support link to GitHub, you leave BorderLog. Information submitted to GitHub is processed by GitHub, and GitHub issues are normally public. Do not post travel records, precise locations, calendar details, photo identifiers or diagnostic exports in a public issue.</p>

    <h2>Your choices</h2>
    <p>All Location, Photos, Calendar and profile inputs are optional. BorderLog remains usable with manual entries when you do not grant access. You can review permission status and delete local data from Settings in the app.</p>

    <h2>Changes and contact</h2>
    <p>This policy may be updated when BorderLog's behaviour changes. The effective date above identifies the current version. For a privacy question or deletion concern, email <a href="mailto:${supportEmail}">${supportEmail}</a>. You can also provide a non-sensitive summary through <a href="${SUPPORT_URL}">BorderLog's public support tracker</a>.</p>
  `
});

const createSupportPage = (supportEmail) => createPage({
  title: "Support",
  description: "Support and troubleshooting information for BorderLog.",
  currentPath: "/support",
  supportEmail,
  content: `
    <h1>Support</h1>
    <p class="lede">Email <a href="mailto:${supportEmail}">${supportEmail}</a> for private support, general feedback or feature requests.</p>
    <p><a href="${SUPPORT_URL}"><strong>Open a BorderLog support issue</strong></a></p>
    <div class="notice">
      <strong>Protect your privacy.</strong> GitHub issues are normally public. Describe the problem without posting precise locations, travel history, calendar titles or identifiers, photo identifiers, personal profile details, or diagnostic exports.
    </div>

    <h2>Before opening an issue</h2>
    <ul>
      <li>Include the BorderLog version shown in Settings and your iOS version.</li>
      <li>Describe what you expected, what happened and the steps that reproduce the problem.</li>
      <li>For permission problems, review BorderLog's access under iOS Settings &gt; Privacy &amp; Security.</li>
      <li>For widget location problems, confirm that both BorderLog and the widget have permission to use location. Widget updates are opportunistic and are not continuous tracking.</li>
    </ul>

    <h2>Accounts, billing and data</h2>
    <p>The current release does not require an online account and has no subscription or paid tier. BorderLog stores travel data locally on the device.</p>
    <p>To remove BorderLog data, use <strong>Settings &gt; Reset All Data</strong>. This removes travel records, profile values, the local session identifier and pending widget samples. Permission choices remain under iOS Settings.</p>

    <h2>Accuracy and travel decisions</h2>
    <p>BorderLog provides informational estimates based on the data available to it. It is not legal or immigration advice, does not guarantee compliance, and may be incomplete when permissions or source data are unavailable. Check current rules and important travel decisions with the relevant official authority or a qualified adviser.</p>

    <h2>Privacy</h2>
    <p>Read the <a href="/privacy">BorderLog Privacy Policy</a> for details about optional data sources, Apple system processing, retention and deletion.</p>
  `
});

// Helper to get security headers
const getSecurityHeaders = (baseHeaders) => {
  if (!baseHeaders) {
    return new Headers(DEFAULT_SECURITY_HEADERS);
  }
  const headers = new Headers(baseHeaders);
  for (const [key, value] of DEFAULT_SECURITY_HEADERS.entries()) {
    headers.set(key, value);
  }
  return headers;
};

// Helper to create standardized error responses
const createErrorResponse = (message, status) => {
  const headers = getSecurityHeaders();
  headers.set("Content-Type", "text/plain; charset=UTF-8");
  headers.set("Cache-Control", "no-store, no-cache, must-revalidate, proxy-revalidate");
  return new Response(message, {
    status: status,
    headers: headers
  });
};

const createHtmlResponse = (content, method) => {
  const headers = getSecurityHeaders();
  headers.set("Content-Security-Policy", HTML_CONTENT_SECURITY_POLICY);
  headers.set("Content-Type", "text/html; charset=UTF-8");
  headers.set("Cache-Control", "public, max-age=3600");

  return new Response(method === "HEAD" ? null : content, { headers });
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (method !== "GET" && method !== "HEAD") {
      return createErrorResponse("Method Not Allowed", 405);
    }

    if (path === "/privacy" || path === "/support") {
      const supportEmail = typeof env.SUPPORT_EMAIL === "string" ? env.SUPPORT_EMAIL.trim() : "";
      if (supportEmail.length > 254 || !SUPPORT_EMAIL_PATTERN.test(supportEmail)) {
        return createErrorResponse("Support contact is not configured", 503);
      }
      const page = path === "/privacy"
        ? createPrivacyPage(supportEmail)
        : createSupportPage(supportEmail);
      return createHtmlResponse(page, method);
    }

    // Helper to validate version string (alphanumeric, dot, dash, underscore)
    const isValidVersion = (v) => {
        // Enforce max length and prevent path traversal sequences
        if (v.length > 50 || v.includes("..")) {
            return false;
        }
        return /^[a-zA-Z0-9.\-_]+$/.test(v);
    };

    // Helper to fetch from R2
    const fetchFromR2 = async (key) => {
      // Check if binding exists
      if (!env.CONFIG_BUCKET) {
        console.error("R2 Bucket 'CONFIG_BUCKET' not configured in environment");
        return createErrorResponse("Internal Server Error", 500);
      }

      try {
        // Optimize: use onlyIf to avoid downloading body if ETag matches
        const ifNoneMatch = request.headers.get("If-None-Match");
        const options = ifNoneMatch ? { onlyIf: { etagDoesNotMatch: ifNoneMatch } } : {};

        const object = await env.CONFIG_BUCKET.get(key, options);

        if (object === null) {
          return createErrorResponse("Not Found", 404);
        }

        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);
        headers.set("Cache-Control", "public, max-age=300");

        // Add security headers
        const securityHeaders = getSecurityHeaders(headers);

        // Handle conditional requests (If-None-Match)
        // If onlyIf condition matched (ETag matches), body is null
        if (ifNoneMatch && object.body === null) {
            return new Response(null, { status: 304, headers: securityHeaders });
        }

        // Check for manual match in case `onlyIf` wasn't used but logic requires it (unlikely here but safe)
        if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
             return new Response(null, { status: 304, headers: securityHeaders });
        }

        return new Response(object.body, {
          headers: securityHeaders,
        });
      } catch (e) {
        // Log a generic error message to avoid leaking sensitive details
        console.error("Error fetching from R2");
        return createErrorResponse("Internal Server Error", 500);
      }
    };

    // Route: GET /config/manifest
    if (path === "/config/manifest") {
      return fetchFromR2("manifest.json");
    }

    // Route: GET /config/{type}/{version}
    // types: zones, rules, countries
    const configMatch = path.match(/^\/config\/(zones|rules|countries)\/([^/]+)$/);
    if (configMatch) {
      const type = configMatch[1];
      const version = configMatch[2];

      if (!isValidVersion(version)) {
        return createErrorResponse("Invalid version format", 400);
      }
      return fetchFromR2(`${type}/${version}.json`);
    }

    // Default response
    return createErrorResponse("Not Found", 404);
  },
};
