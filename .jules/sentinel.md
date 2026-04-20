## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-06-15 - Production Authentication Bypass
**Vulnerability:** A toggle (`isAppleSignInEnabled`) and fallback logic in `WelcomeView` allowed completely bypassing Apple Sign-In and proceeding as an authenticated user by generating a random local UUID (`local_user_UUID`).
**Learning:** Any form of mock or local-only authentication bypass shipped in production code violates access control. Even if intended for internal testing, leaving it in the codebase presents a critical risk of unauthorized access.
**Prevention:** Do not ship code capable of skipping authentication flows (e.g., using explicit toggles or local UUID spoofing), even for internal debugging. Hardcode required authentications without bypass mechanisms.
