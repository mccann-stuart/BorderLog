## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-03-30 - Authentication Bypass Backdoor
**Vulnerability:** A local-only mock authentication bypass was left in production code (`AuthenticationManager.isAppleSignInEnabled = false`), allowing users to click "Continue without an account" and assign themselves a random UUID, circumventing the mandatory Apple Sign-In requirement.
**Learning:** Development toggles and bypass mechanisms that skip critical security flows (like authentication) must never be shipped to production. They break the app's access control model and allow unauthenticated access to the application state.
**Prevention:** Hardcode required authentications without bypass mechanisms or explicit development toggles in production code. Do not use local UUID spoofing to simulate authenticated states.
