## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-03-24 - Authentication Bypass via Local Fallback
**Vulnerability:** A toggle flag `isAppleSignInEnabled` was used to conditionally disable Apple Sign-In and present a "Continue without an account" button that minted a random UUID, allowing a complete bypass of the application's required authentication flow.
**Learning:** Any form of mock or local-only authentication bypass in production code violates access control. These development/testing hooks can be easily accidentally shipped or manipulated, leaving the app vulnerable to unauthorized access.
**Prevention:** Do not ship code capable of skipping authentication flows (e.g., using explicit toggles or local UUID spoofing), even for internal debugging. Hardcode required authentications without bypass mechanisms.
