## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2025-04-28 - Authentication Bypass in Local Environment
**Vulnerability:** A toggle for `isAppleSignInEnabled` and a corresponding UI bypass path in `WelcomeView.swift` existed that allowed arbitrary users (e.g. `local_user_\(UUID().uuidString)`) to authenticate, bypassing Apple Sign In.
**Learning:** Development or local-only authentication bypasses left in production or shared logic constitute serious security risks. Any capability to skip authentication flows can be exploited or cause logic flaws if not strictly gated out of release builds via preprocessor macros or outright removed.
**Prevention:** Hardcode required authentication checks without bypass mechanisms. Do not ship code capable of skipping authentication flows, even for internal testing, to ensure maximum access control stringency.
