## 2026-02-15 - Cloudflare Worker Security Headers Pattern
**Vulnerability:** Missing standard security headers (HSTS, CSP, etc.) in backend responses.
**Learning:** Cloudflare Workers require manual header injection for every response. Using a centralized `createResponse` helper ensures consistency across all exit paths (success, error, 404).
**Prevention:** Use the `createResponse` helper pattern in all future Worker endpoints to automatically apply strict security headers.
## 2026-02-18 - Explicit Content-Type on Error Responses
**Vulnerability:** HTTP API error responses (like 400, 404, 500) were being returned as plain text bodies without an explicit `Content-Type` header. This could potentially lead to content sniffing by certain clients.
**Learning:** Even simple string-based error responses should explicitly declare their content type (`text/plain; charset=UTF-8`) to prevent browsers/clients from trying to guess the format.
**Prevention:** Always use a helper like `createErrorResponse` that injects the required `Content-Type: text/plain; charset=UTF-8` header for non-JSON or error payloads in workers.
## 2026-03-09 - iOS App Switcher Data Leakage
**Vulnerability:** When the app enters the background (e.g. going to the iOS app switcher), a snapshot of the UI is taken by the OS. Since the state variable updating `isUnlocked` to false inside `.onChange(of: scenePhase)` isn't processed quickly enough before the OS snapshot, sensitive travel data may be visible in the multitasking preview.
**Learning:** Depending solely on state changes in `.onChange(of: scenePhase)` to obscure views can be too slow to prevent sensitive data leakage in OS multitasking previews.
**Prevention:** Always directly bind security overlays or blur effects to `scenePhase != .active` within the view hierarchy (like in an `.overlay`) when biometrics/security locks are required.
## 2026-02-18 - Prevent Sensitive Data Leakage in Logs
**Vulnerability:** Core data processing services (`LedgerRecomputeService` and `LocationSampleService`) were using standard `print("... \(error)")` statements to log errors. In Swift, `print()` outputs are often captured in system logs without any privacy redaction, which can inadvertently leak sensitive user information (like travel coordinates or database states) attached to `Error` objects in a production environment.
**Learning:** All logging involving user state or potential error details should use the structured `os.Logger` framework, explicitly leveraging interpolation privacy wrappers like `\(error, privacy: .public)` or `.private` to control what gets written to persistent device logs and avoiding generic standard output dumps.
**Prevention:** Never use `print()` for error handling or diagnostic logging in Swift code. Always define a class/actor-specific `os.Logger` (e.g., `private static let logger = Logger(subsystem: "com.MCCANN.Border", category: "ServiceName")`) and log using explicit privacy modifiers.

## 2026-02-18 - Correction: Explicit Privacy on Error Logging
**Vulnerability:** Replacing `print` with `os.Logger` while using `privacy: .public` for error objects actually worsens the data leakage vulnerability since unified logging persists the plain text data in OS logs.
**Learning:** `Error` objects and user-state variables must NEVER be logged with `.public` modifiers.
**Prevention:** Use `privacy: .private` explicitly or omit the privacy modifier (which defaults dynamic variables to `<private>`) when logging potential user data or stack traces containing sensitive context.
