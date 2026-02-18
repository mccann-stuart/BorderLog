export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // Helper to create responses with standard security headers
    const createSecureResponse = (body, init = {}) => {
      const headers = new Headers(init.headers);
      headers.set("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload");
      headers.set("X-Frame-Options", "DENY");
      headers.set("X-Content-Type-Options", "nosniff");
      headers.set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none';");
      headers.set("Referrer-Policy", "no-referrer");
      headers.set("Permissions-Policy", "interest-cohort=()");

      return new Response(body, { ...init, headers });
    };

    if (method !== "GET" && method !== "HEAD") {
      return createSecureResponse("Method Not Allowed", { status: 405 });
    }

    // Helper to validate version string (alphanumeric, dot, dash, underscore)
    const isValidVersion = (v) => /^[a-zA-Z0-9.\-_]+$/.test(v);

    // Helper to fetch from R2
    const fetchFromR2 = async (key) => {
      // Check if binding exists
      if (!env.CONFIG_BUCKET) {
        console.error("R2 Bucket 'CONFIG_BUCKET' not configured in environment");
        return createSecureResponse("Internal Server Error", { status: 500 });
      }

      try {
        const object = await env.CONFIG_BUCKET.get(key);

        if (object === null) {
          return createSecureResponse("Not Found", { status: 404 });
        }

        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);

        // Handle conditional requests (If-None-Match)
        const ifNoneMatch = request.headers.get("If-None-Match");
        if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
            return createSecureResponse(null, { status: 304, headers });
        }

        return createSecureResponse(object.body, { headers });
      } catch (e) {
        // Log the actual error but return a generic message to the client
        console.error(`Error fetching from R2: ${e.message}`);
        return createSecureResponse("Internal Server Error", { status: 500 });
      }
    };

    // Route: GET /config/manifest
    if (path === "/config/manifest") {
      return fetchFromR2("manifest.json");
    }

    // Route: GET /config/zones/{version}
    // Example: /config/zones/v1
    const zonesMatch = path.match(/^\/config\/zones\/([^/]+)$/);
    if (zonesMatch) {
      const version = zonesMatch[1];
      if (!isValidVersion(version)) {
        return createSecureResponse("Invalid version format", { status: 400 });
      }
      return fetchFromR2(`zones/${version}.json`);
    }

    // Route: GET /config/rules/{version}
    const rulesMatch = path.match(/^\/config\/rules\/([^/]+)$/);
    if (rulesMatch) {
      const version = rulesMatch[1];
      if (!isValidVersion(version)) {
        return createSecureResponse("Invalid version format", { status: 400 });
      }
      return fetchFromR2(`rules/${version}.json`);
    }

    // Route: GET /config/countries/{version}
    const countriesMatch = path.match(/^\/config\/countries\/([^/]+)$/);
    if (countriesMatch) {
      const version = countriesMatch[1];
      if (!isValidVersion(version)) {
        return createSecureResponse("Invalid version format", { status: 400 });
      }
      return fetchFromR2(`countries/${version}.json`);
    }

    // Default response
    return createSecureResponse("Not Found", { status: 404 });
  },
};
