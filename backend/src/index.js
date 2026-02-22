export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // Helper to get security headers
    const getSecurityHeaders = (baseHeaders = {}) => {
        const headers = new Headers(baseHeaders);
        headers.set("X-Content-Type-Options", "nosniff");
        headers.set("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
        headers.set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; sandbox");
        headers.set("X-Frame-Options", "DENY");
        headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
        return headers;
    };

    if (method !== "GET" && method !== "HEAD") {
      return new Response("Method Not Allowed", {
        status: 405,
        headers: getSecurityHeaders()
      });
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
        return new Response("Internal Server Error", {
            status: 500,
            headers: getSecurityHeaders()
        });
      }

      try {
        // Optimize: use onlyIf to avoid downloading body if ETag matches
        const ifNoneMatch = request.headers.get("If-None-Match");
        const options = ifNoneMatch ? { onlyIf: { etagDoesNotMatch: ifNoneMatch } } : {};

        const object = await env.CONFIG_BUCKET.get(key, options);

        if (object === null) {
          return new Response("Not Found", {
            status: 404,
            headers: getSecurityHeaders()
          });
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
        // Log the actual error but return a generic message to the client
        console.error(`Error fetching from R2: ${e.message}`);
        return new Response("Internal Server Error", {
            status: 500,
            headers: getSecurityHeaders()
        });
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
        return new Response("Invalid version format", {
            status: 400,
            headers: getSecurityHeaders()
        });
      }
      return fetchFromR2(`${type}/${version}.json`);
    }

    // Default response
    return new Response("Not Found", {
        status: 404,
        headers: getSecurityHeaders()
    });
  },
};
