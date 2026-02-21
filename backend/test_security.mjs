import worker from './src/index.js';
import assert from 'node:assert';

// Mock execution context
const ctx = {
  waitUntil: () => {},
  passThroughOnException: () => {},
};

// Helper to check all security headers
function assertSecurityHeaders(res) {
  assert.strictEqual(res.headers.get("X-Content-Type-Options"), "nosniff", "Missing X-Content-Type-Options");
  assert.strictEqual(res.headers.get("Strict-Transport-Security"), "max-age=31536000; includeSubDomains", "Missing Strict-Transport-Security");
  assert.strictEqual(res.headers.get("Content-Security-Policy"), "default-src 'none'; frame-ancestors 'none'; sandbox", "Missing Content-Security-Policy");
  assert.strictEqual(res.headers.get("X-Frame-Options"), "DENY", "Missing X-Frame-Options");
  assert.strictEqual(res.headers.get("Referrer-Policy"), "strict-origin-when-cross-origin", "Missing Referrer-Policy");
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
    assertSecurityHeaders(res);
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
    assertSecurityHeaders(res);
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
    assertSecurityHeaders(res);
    assert.ok(loggedError.includes("R2 Connection Failed"), "Should log specific error");
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
    assertSecurityHeaders(res);
  });

  await runTest("Invalid Version format returns 400 + Security Headers", async () => {
    const req = new Request("http://localhost/config/zones/invalid$version");
    const env = {}; // Binding not needed for early validation check

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 400);
    assertSecurityHeaders(res);
  });

  await runTest("Unknown Route returns 404 + Security Headers", async () => {
    const req = new Request("http://localhost/unknown/route");
    const env = {};

    const res = await worker.fetch(req, env, ctx);

    assert.strictEqual(res.status, 404);
    assertSecurityHeaders(res);
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

    assert.strictEqual(res.status, 304);
    assertSecurityHeaders(res);
    assert.strictEqual(res.headers.get("Cache-Control"), "public, max-age=300", "Missing Cache-Control");
  });

  console.log("All tests passed!");
})();
