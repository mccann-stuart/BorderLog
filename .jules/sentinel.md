## 2026-02-15 - Cloudflare Worker Security Headers Pattern
**Vulnerability:** Missing standard security headers (HSTS, CSP, etc.) in backend responses.
**Learning:** Cloudflare Workers require manual header injection for every response. Using a centralized `createResponse` helper ensures consistency across all exit paths (success, error, 404).
**Prevention:** Use the `createResponse` helper pattern in all future Worker endpoints to automatically apply strict security headers.
## 2026-02-18 - Explicit Content-Type on Error Responses
**Vulnerability:** HTTP API error responses (like 400, 404, 500) were being returned as plain text bodies without an explicit `Content-Type` header. This could potentially lead to content sniffing by certain clients.
**Learning:** Even simple string-based error responses should explicitly declare their content type (`text/plain; charset=UTF-8`) to prevent browsers/clients from trying to guess the format.
**Prevention:** Always use a helper like `createErrorResponse` that injects the required `Content-Type: text/plain; charset=UTF-8` header for non-JSON or error payloads in workers.
## 2026-02-18 - iOS App Switcher Data Leakage
**Vulnerability:** When "Require Biometrics" was enabled, the app's current view containing sensitive user data (like travel history) was still visible in the iOS app switcher (multitasking preview). The state update `isUnlocked = false` in `.onChange(of: scenePhase)` (when entering `.background`) happens too late; the OS takes the snapshot *before* the SwiftUI view reflects the change.
**Learning:** Relying purely on imperative `.onChange` lifecycle hooks to obscure data for the app switcher is unreliable. The snapshot is often captured while the app transitions to the inactive/background state.
**Prevention:** Use a declarative SwiftUI `.overlay` bound directly to `scenePhase != .active` to obscure the screen (e.g., with a black color) as soon as the app begins its transition away from the active state, ensuring the OS snapshot captures the obscured view.
