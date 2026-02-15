export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (method !== "GET" && method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    // Helper to validate version string (alphanumeric, dot, dash, underscore)
    const isValidVersion = (v) => /^[a-zA-Z0-9.\-_]+$/.test(v);

    // Helper to fetch from R2
    const fetchFromR2 = async (key) => {
      // Check if binding exists
      if (!env.CONFIG_BUCKET) {
        // If binding is missing, return a mock response for development/testing
        // or a 500 error if strict. Given this is a template, a clear error or mock is better.
        // Let's return a 500 with a clear message.
        return new Response("R2 Bucket 'CONFIG_BUCKET' not configured in environment", { status: 500 });
        // If binding is missing, return a generic error in production, but log internally
        console.error("R2 Bucket 'CONFIG_BUCKET' not configured in environment");
        return new Response("Internal Server Error", { status: 500 });
      }

      try {
        const object = await env.CONFIG_BUCKET.get(key);

        if (object === null) {
          return new Response(`Object '${key}' Not Found`, { status: 404 });
          return new Response("Not Found", { status: 404 });
        }

        const headers = new Headers();
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);
        // Add security headers
        headers.set("X-Content-Type-Options", "nosniff");

        // Handle conditional requests (If-None-Match)
        const ifNoneMatch = request.headers.get("If-None-Match");
        if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
            return new Response(null, { status: 304, headers });
        }

        return new Response(object.body, {
          headers,
        });
      } catch (e) {
        return new Response(`Error fetching from R2: ${e.message}`, { status: 500 });
        // Log the actual error but return a generic message to the client
        console.error(`Error fetching from R2: ${e.message}`);
        return new Response("Internal Server Error", {
            status: 500,
            headers: { "X-Content-Type-Options": "nosniff" }
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
      // Assuming structure in bucket is zones/{version}.json or just zones/{version}
      // PRD implies JSON content, so let's try to append .json if not present or just use key as is?
      // "zones.json (Schengen membership...)" -> likely zones.json is the file, but versioning implies zones-v1.json or zones/v1.json
      // PRD: "GET /config/zones/{version} → zone definitions"
      // Let's assume the key is `zones/${version}.json` for clarity.
      if (!isValidVersion(version)) {
        return new Response("Invalid version format", {
            status: 400,
            headers: { "X-Content-Type-Options": "nosniff" }
        });
      }
      return fetchFromR2(`zones/${version}.json`);
    }

    // Route: GET /config/rules/{version}
    const rulesMatch = path.match(/^\/config\/rules\/([^/]+)$/);
    if (rulesMatch) {
      const version = rulesMatch[1];
      if (!isValidVersion(version)) {
        return new Response("Invalid version format", {
            status: 400,
            headers: { "X-Content-Type-Options": "nosniff" }
        });
      }
      return fetchFromR2(`rules/${version}.json`);
    }

    // Route: GET /config/countries/{version}
    const countriesMatch = path.match(/^\/config\/countries\/([^/]+)$/);
    if (countriesMatch) {
      const version = countriesMatch[1];
      if (!isValidVersion(version)) {
        return new Response("Invalid version format", {
            status: 400,
            headers: { "X-Content-Type-Options": "nosniff" }
        });
      }
      return fetchFromR2(`countries/${version}.json`);
    }

    // Default response
    return new Response("Not Found", { status: 404 });
  },
};
