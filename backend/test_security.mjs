import worker from './src/index.js';
import assert from 'node:assert';

const API_CONTENT_SECURITY_POLICY = "default-src 'none'; frame-ancestors 'none'; sandbox";
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
const SUPPORT_EMAIL = "support@example.com";
const policyEnv = { SUPPORT_EMAIL };

// Mock execution context
const ctx = {
  waitUntil: () => {},
  passThroughOnException: () => {},
};

// Helper to check all security headers
function assertSecurityHeaders(res, expectedContentSecurityPolicy = API_CONTENT_SECURITY_POLICY) {
  assert.strictEqual(res.headers.get("X-Content-Type-Options"), "nosniff", "Missing X-Content-Type-Options");
  assert.strictEqual(res.headers.get("Strict-Transport-Security"), "max-age=31536000; includeSubDomains; preload", "Missing Strict-Transport-Security");
  assert.strictEqual(res.headers.get("Content-Security-Policy"), expectedContentSecurityPolicy, "Missing or incorrect Content-Security-Policy");
  assert.strictEqual(res.headers.get("X-Frame-Options"), "DENY", "Missing X-Frame-Options");
  assert.strictEqual(res.headers.get("Referrer-Policy"), "strict-origin-when-cross-origin", "Missing Referrer-Policy");
  assert.strictEqual(res.headers.get("Permissions-Policy"), "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=(), interest-cohort=()", "Missing Permissions-Policy");
  assert.strictEqual(res.headers.get("Cross-Origin-Opener-Policy"), "same-origin", "Missing Cross-Origin-Opener-Policy");
  assert.strictEqual(res.headers.get("Cross-Origin-Resource-Policy"), "same-origin", "Missing Cross-Origin-Resource-Policy");
}

// Helper to check error response headers specifically
function assertErrorHeaders(res) {
  assertSecurityHeaders(res);
  assert.strictEqual(res.headers.get("Content-Type"), "text/plain; charset=UTF-8", "Missing or incorrect Content-Type for error response");
  assert.strictEqual(res.headers.get("Cache-Control"), "no-store, no-cache, must-revalidate, proxy-revalidate", "Missing or incorrect Cache-Control for error response");
}

function assertHtmlHeaders(res) {
  assertSecurityHeaders(res, HTML_CONTENT_SECURITY_POLICY);
  assert.strictEqual(res.headers.get("Content-Type"), "text/html; charset=UTF-8", "Missing or incorrect HTML Content-Type");
  assert.strictEqual(res.headers.get("Cache-Control"), "public, max-age=3600", "Missing or incorrect HTML Cache-Control");
}

function assertNoExecutableOrExternalAssets(html) {
  assert.ok(!/<script\b/i.test(html), "Policy pages must not contain scripts");
  assert.ok(!/<(?:img|iframe|audio|video|source)\b/i.test(html), "Policy pages must not contain external media elements");
  assert.ok(!/<link\b[^>]*rel=["']?stylesheet/i.test(html), "Policy pages must not load external stylesheets");
  assert.ok(!/\s(?:src|srcset)\s*=/i.test(html), "Policy pages must not reference external assets");
}

// Helper to run test
async function runTest(name, fn) {
  try {
    await fn();
    console.log(`✅ ${name}`);
  } catch (e) {
    console.error(`❌ ${name}`);
    console.error(e);
    process.exit(1);
  }
}

// Main test runner
(async () => {
  console.log("Running security tests...");

  await runTest("Method Not Allowed returns 405 + Security Headers", async () => {
    const req = new Request("http://localhost/config/manifest", { method: "POST" });
    const env = {};

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 405);
    assertErrorHeaders(res);
  });

  for (const route of ["/privacy", "/support"]) {
    await runTest(`GET ${route} returns standalone HTML without R2`, async () => {
      const req = new Request(`https://example.com${route}`);
      const res = await worker.fetch(req, policyEnv, ctx);

      assert.strictEqual(res.status, 200);
      assertHtmlHeaders(res);

      const html = await res.text();
      assert.match(html, /^<!doctype html>/);
      assert.match(html, /<html lang="en-GB">/);
      assert.match(html, /<meta name="viewport"/);
      assert.match(html, /href="\/privacy"/);
      assert.match(html, /href="\/support"/);
      assert.match(html, new RegExp(`href="${SUPPORT_URL.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}"`));
      assert.match(html, new RegExp(`href="mailto:${SUPPORT_EMAIL}"`));
      assertNoExecutableOrExternalAssets(html);
    });

    await runTest(`HEAD ${route} returns HTML headers and no body`, async () => {
      const req = new Request(`https://example.com${route}`, { method: "HEAD" });
      const res = await worker.fetch(req, policyEnv, ctx);

      assert.strictEqual(res.status, 200);
      assertHtmlHeaders(res);
      assert.strictEqual(await res.text(), "");
    });

    await runTest(`POST ${route} remains blocked by API security policy`, async () => {
      const req = new Request(`https://example.com${route}`, { method: "POST" });
      const res = await worker.fetch(req, {}, ctx);

      assert.strictEqual(res.status, 405);
      assertErrorHeaders(res);
    });
  }

  for (const route of ["/privacy", "/support"]) {
    await runTest(`GET ${route} refuses to publish without a valid support email`, async () => {
      const missingResponse = await worker.fetch(new Request(`https://example.com${route}`), {}, ctx);
      assert.strictEqual(missingResponse.status, 503);
      assert.strictEqual(await missingResponse.text(), "Support contact is not configured");
      assertErrorHeaders(missingResponse);

      const invalidResponse = await worker.fetch(
        new Request(`https://example.com${route}`),
        { SUPPORT_EMAIL: "not-an-email" },
        ctx
      );
      assert.strictEqual(invalidResponse.status, 503);
      assertErrorHeaders(invalidResponse);
    });
  }

  await runTest("Privacy page accurately describes launch data practices", async () => {
    const res = await worker.fetch(
      new Request("https://example.com/privacy?source=app-store"),
      policyEnv,
      ctx
    );
    const html = await res.text();

    assert.strictEqual(res.status, 200);
    assert.match(html, /does not require an online account/i);
    assert.match(html, /does not sell personal data/i);
    assert.match(html, /MapKit and geocoding may process coordinates or place searches/i);
    assert.match(html, /Settings &gt; Reset All Data/);
    assert.match(html, /Keychain-backed values removed first/i);
    assert.match(html, /GitHub issues are normally public/i);
    assert.match(html, new RegExp(SUPPORT_EMAIL));
  });

  await runTest("Support page provides email contact and privacy-safe guidance", async () => {
    const res = await worker.fetch(new Request("https://example.com/support"), policyEnv, ctx);
    const html = await res.text();

    assert.strictEqual(res.status, 200);
    assert.match(html, new RegExp(SUPPORT_URL.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    assert.match(html, /GitHub issues are normally public/i);
    assert.match(html, /does not require an online account/i);
    assert.match(html, /Settings &gt; Reset All Data/);
    assert.match(html, /not legal or immigration advice/i);
    assert.match(html, /href="\/privacy"/);
    assert.match(html, new RegExp(`href="mailto:${SUPPORT_EMAIL}"`));
  });

  await runTest("Missing CONFIG_BUCKET binding returns 500 Generic Error", async () => {
    const req = new Request("http://localhost/config/manifest");
    const env = {}; // No CONFIG_BUCKET

    // Suppress console.error for expected errors
    const originalError = console.error;
    let loggedError = "";
    console.error = (msg) => { loggedError = msg; };

    const res = await worker.fetch(req, env, ctx);

    console.error = originalError;

    assert.strictEqual(res.status, 500);
    const text = await res.text();
    assert.strictEqual(text, "Internal Server Error");
    assertErrorHeaders(res);
    assert.ok(loggedError.includes("not configured"), "Should log internal details");
  });

  await runTest("R2 Fetch Error returns 500 Generic Error + Security Headers", async () => {
    const req = new Request("http://localhost/config/manifest");
    const env = {
      CONFIG_BUCKET: {
        get: async () => { throw new Error("R2 Connection Failed"); }
      }
    };

    // Suppress console.error
    const originalError = console.error;
    let loggedError = "";
    console.error = (msg) => { loggedError = msg; };

    const res = await worker.fetch(req, env, ctx);

    console.error = originalError;

    assert.strictEqual(res.status, 500);
    const text = await res.text();
    assert.strictEqual(text, "Internal Server Error");
    assertErrorHeaders(res);
    assert.ok(loggedError.includes("Error fetching from R2"), "Should log generic error message");
    assert.ok(!loggedError.includes("R2 Connection Failed"), "Should NOT log sensitive error details");
  });

  await runTest("R2 Key Not Found returns 404 + Security Headers", async () => {
    const req = new Request("http://localhost/config/manifest");
    const env = {
      CONFIG_BUCKET: {
        get: async () => null // Returns null for missing key
      }
    };

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 404);
    assertErrorHeaders(res);
  });

  await runTest("Invalid Version format returns 400 + Security Headers", async () => {
    const req = new Request("http://localhost/config/zones/invalid$version");
    const env = {}; // Binding not needed for early validation check

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 400);
    assertErrorHeaders(res);
  });

  await runTest("Invalid Version (too long) returns 400", async () => {
    const longVersion = "a".repeat(51);
    const req = new Request(`http://localhost/config/zones/${longVersion}`);
    const env = {};

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 400);
    assertErrorHeaders(res);
  });

  await runTest("Invalid Version (contains ..) returns 400", async () => {
    const req = new Request("http://localhost/config/zones/v1..2");
    const env = {};

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 400);
    assertErrorHeaders(res);
  });

  await runTest("Unknown Route returns 404 + Security Headers", async () => {
    const req = new Request("http://localhost/unknown/route");
    const env = {};

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 404);
    assertErrorHeaders(res);
  });

  await runTest("Successful Fetch includes Security Headers and Cache-Control", async () => {
    const req = new Request("http://localhost/config/manifest");
    const env = {
      CONFIG_BUCKET: {
        get: async () => ({
          body: "{}",
          httpEtag: "123",
          writeHttpMetadata: (headers) => {}
        })
      }
    };

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 200);
    assertSecurityHeaders(res);
    assert.strictEqual(res.headers.get("Cache-Control"), "public, max-age=300", "Missing Cache-Control");
  });

  await runTest("Not Modified includes Cache-Control", async () => {
    const req = new Request("http://localhost/config/manifest", {
      headers: { "If-None-Match": "123" }
    });

    let getCalledWithOptions = null;
    const env = {
      CONFIG_BUCKET: {
        get: async (key, options) => {
          getCalledWithOptions = options;
          // Simulate R2 behavior: if etagDoesNotMatch matches, return null body
          if (options && options.onlyIf && options.onlyIf.etagDoesNotMatch === "123") {
            return {
              body: null,
              httpEtag: "123",
              writeHttpMetadata: (headers) => {}
            };
          }
          return {
            body: "{}",
            httpEtag: "123",
            writeHttpMetadata: (headers) => {}
          };
        }
      }
    };

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 304);
    assertSecurityHeaders(res);
    assert.strictEqual(res.headers.get("Cache-Control"), "public, max-age=300", "Missing Cache-Control");

    // Verify optimization was used
    assert.ok(getCalledWithOptions, "bucket.get should be called with options");
    assert.deepStrictEqual(getCalledWithOptions.onlyIf, { etagDoesNotMatch: "123" }, "Should use onlyIf optimization");
  });

  console.log("All tests passed!");
})();
