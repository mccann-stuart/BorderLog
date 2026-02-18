export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // Helper to add security headers
    const addSecurityHeaders = (headers) => {
      headers.set("X-Content-Type-Options", "nosniff");
      headers.set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload");
      headers.set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; sandbox");
      headers.set("X-Frame-Options", "DENY");
      headers.set("Referrer-Policy", "no-referrer");
      headers.set("Permissions-Policy", "interest-cohort=()");
      return headers;
    };

    // Helper to create responses with security headers
    const createResponse = (body, status = 200, extraHeaders = {}) => {
        const headers = new Headers(extraHeaders);
        addSecurityHeaders(headers);
        return new Response(body, { status, headers });
    };

    if (method !== "GET" && method !== "HEAD") {
      return createResponse("Method Not Allowed", 405);
    }

    // Helper to validate version string (alphanumeric, dot, dash, underscore)
    const isValidVersion = (v) => /^[a-zA-Z0-9.\-_]+$/.test(v);

    // Helper to fetch from R2
    const fetchFromR2 = async (key) => {
      // Check if binding exists
      if (!env.CONFIG_BUCKET) {
        console.error("R2 Bucket 'CONFIG_BUCKET' not configured in environment");
        return createResponse("Internal Server Error", 500);
      }

      try {
        const object = await env.CONFIG_BUCKET.get(key);

        if (object === null) {
          return createResponse("Not Found", 404);
        }

        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);

        // Add security headers
        addSecurityHeaders(headers);

        // Handle conditional requests (If-None-Match)
        const ifNoneMatch = request.headers.get("If-None-Match");
        if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
            return new Response(null, { status: 304, headers });
        }

        return new Response(object.body, {
          headers,
        });
      } catch (e) {
        // Log the actual error but return a generic message to the client
        console.error(`Error fetching from R2: ${e.message}`);
        return createResponse("Internal Server Error", 500);
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
        return createResponse("Invalid version format", 400);
      }
      return fetchFromR2(`zones/${version}.json`);
    }

    // Route: GET /config/rules/{version}
    const rulesMatch = path.match(/^\/config\/rules\/([^/]+)$/);
    if (rulesMatch) {
      const version = rulesMatch[1];
      if (!isValidVersion(version)) {
        return createResponse("Invalid version format", 400);
      }
      return fetchFromR2(`rules/${version}.json`);
    }

    // Route: GET /config/countries/{version}
    const countriesMatch = path.match(/^\/config\/countries\/([^/]+)$/);
    if (countriesMatch) {
      const version = countriesMatch[1];
      if (!isValidVersion(version)) {
        return createResponse("Invalid version format", 400);
      }
      return fetchFromR2(`countries/${version}.json`);
    }

    // Default response
    return createResponse("Not Found", 404);
  },
};
