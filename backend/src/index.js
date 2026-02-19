export default {
  async fetch(request, env, ctx) {
    // Helper to create response with security headers
    const createResponse = (body, init = {}) => {
      const response = new Response(body, init);
      response.headers.set("X-Content-Type-Options", "nosniff");
      response.headers.set("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
      response.headers.set("Content-Security-Policy", "default-src 'none'");
      response.headers.set("X-Frame-Options", "DENY");
      return response;
    };

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (method !== "GET" && method !== "HEAD") {
      return createResponse("Method Not Allowed", {
        status: 405,
      });
    }

    // Helper to validate version string (alphanumeric, dot, dash, underscore)
    const isValidVersion = (v) => /^[a-zA-Z0-9.\-_]+$/.test(v);

    // Helper to fetch from R2
    const fetchFromR2 = async (key) => {
      // Check if binding exists
      if (!env.CONFIG_BUCKET) {
        console.error("R2 Bucket 'CONFIG_BUCKET' not configured in environment");
        return createResponse("Internal Server Error", {
            status: 500,
        });
      }

      try {
        const object = await env.CONFIG_BUCKET.get(key);

        if (object === null) {
          return createResponse("Not Found", {
            status: 404,
          });
        }

        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);

        // Handle conditional requests (If-None-Match)
        const ifNoneMatch = request.headers.get("If-None-Match");
        if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
            return createResponse(null, { status: 304, headers });
        }

        return createResponse(object.body, {
          headers,
        });
      } catch (e) {
        // Log the actual error but return a generic message to the client
        console.error(`Error fetching from R2: ${e.message}`);
        return createResponse("Internal Server Error", {
            status: 500,
        });
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
        return createResponse("Invalid version format", {
            status: 400,
        });
      }
      return fetchFromR2(`zones/${version}.json`);
    }

    // Route: GET /config/rules/{version}
    const rulesMatch = path.match(/^\/config\/rules\/([^/]+)$/);
    if (rulesMatch) {
      const version = rulesMatch[1];
      if (!isValidVersion(version)) {
        return createResponse("Invalid version format", {
            status: 400,
        });
      }
      return fetchFromR2(`rules/${version}.json`);
    }

    // Route: GET /config/countries/{version}
    const countriesMatch = path.match(/^\/config\/countries\/([^/]+)$/);
    if (countriesMatch) {
      const version = countriesMatch[1];
      if (!isValidVersion(version)) {
        return createResponse("Invalid version format", {
            status: 400,
        });
      }
      return fetchFromR2(`countries/${version}.json`);
    }

    // Default response
    return createResponse("Not Found", {
        status: 404,
    });
  },
};
