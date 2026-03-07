## 2026-02-15 - Cloudflare Worker Security Headers Pattern
**Vulnerability:** Missing standard security headers (HSTS, CSP, etc.) in backend responses.
**Learning:** Cloudflare Workers require manual header injection for every response. Using a centralized `createResponse` helper ensures consistency across all exit paths (success, error, 404).
**Prevention:** Use the `createResponse` helper pattern in all future Worker endpoints to automatically apply strict security headers.
## 2026-02-18 - Explicit Content-Type on Error Responses
**Vulnerability:** HTTP API error responses (like 400, 404, 500) were being returned as plain text bodies without an explicit `Content-Type` header. This could potentially lead to content sniffing by certain clients.
**Learning:** Even simple string-based error responses should explicitly declare their content type (`text/plain; charset=UTF-8`) to prevent browsers/clients from trying to guess the format.
**Prevention:** Always use a helper like `createErrorResponse` that injects the required `Content-Type: text/plain; charset=UTF-8` header for non-JSON or error payloads in workers.
## 2026-03-07 - [App Switcher Privacy Leak Prevention]
**Vulnerability:** The app preview in the iOS app switcher multitasking view was exposing potentially sensitive location and tracking data when biometric authentication was required but the app had just been backgrounded.
**Learning:** `scenePhase` `.onChange` triggers are sometimes too slow or don't apply immediately to the iOS snapshot process. Obscuring data via `.overlay` directly bound to `scenePhase != .active` ensures synchronous obscuration before the system captures the snapshot.
**Prevention:** For sensitive views, always check `scenePhase` and use an overlay or blur whenever `scenePhase != .active` to protect iOS multitasking view previews.
