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
  return new Response(message, {
    status: status,
    headers: headers
  });
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    if (method !== "GET" && method !== "HEAD") {
      return createErrorResponse("Method Not Allowed", 405);
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
