export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // Helper to add common headers to a Headers object
    const addCommonHeaders = (headers) => {
      headers.set("X-Content-Type-Options", "nosniff");
    };

    if (method !== "GET" && method !== "HEAD") {
      const headers = new Headers();
      addCommonHeaders(headers);
      return new Response("Method Not Allowed", {
        status: 405,
        headers
      });
    }

    // Helper to validate version string (alphanumeric, dot, dash, underscore)
    const isValidVersion = (v) => /^[a-zA-Z0-9.\-_]+$/.test(v);

    // Helper to fetch from R2
    const fetchFromR2 = async (key) => {
      // Check if binding exists
      if (!env.CONFIG_BUCKET) {
        console.error("R2 Bucket 'CONFIG_BUCKET' not configured in environment");
        const headers = new Headers();
        addCommonHeaders(headers);
        return new Response("Internal Server Error", {
            status: 500,
            headers
        });
      }

      try {
        const object = await env.CONFIG_BUCKET.get(key);

        if (object === null) {
          const headers = new Headers();
          addCommonHeaders(headers);
          return new Response("Not Found", {
            status: 404,
            headers
          });
        }

        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);

        // Add common headers
        addCommonHeaders(headers);

        // Add Cache-Control for performance
        // Cache for 5 minutes (300 seconds)
        headers.set("Cache-Control", "public, max-age=300");

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
        const headers = new Headers();
        addCommonHeaders(headers);
        return new Response("Internal Server Error", {
            status: 500,
            headers
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
        const headers = new Headers();
        addCommonHeaders(headers);
        return new Response("Invalid version format", {
            status: 400,
            headers
        });
      }
      return fetchFromR2(`zones/${version}.json`);
    }

    // Route: GET /config/rules/{version}
    const rulesMatch = path.match(/^\/config\/rules\/([^/]+)$/);
    if (rulesMatch) {
      const version = rulesMatch[1];
      if (!isValidVersion(version)) {
        const headers = new Headers();
        addCommonHeaders(headers);
        return new Response("Invalid version format", {
            status: 400,
            headers
        });
      }
      return fetchFromR2(`rules/${version}.json`);
    }

    // Route: GET /config/countries/{version}
    const countriesMatch = path.match(/^\/config\/countries\/([^/]+)$/);
    if (countriesMatch) {
      const version = countriesMatch[1];
      if (!isValidVersion(version)) {
        const headers = new Headers();
        addCommonHeaders(headers);
        return new Response("Invalid version format", {
            status: 400,
            headers
        });
      }
      return fetchFromR2(`countries/${version}.json`);
    }

    // Default response
    const headers = new Headers();
    addCommonHeaders(headers);
    return new Response("Not Found", {
        status: 404,
        headers
    });
  },
};
