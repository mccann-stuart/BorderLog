## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-03-24 - Authentication Bypass Removal
**Vulnerability:** A toggle `isAppleSignInEnabled` along with local UUID spoofing permitted bypassing mandatory Apple Sign-In and running the app in a local-only unauthenticated mode.
**Learning:** Any form of mock or local-only authentication bypass in production code violates business logic and access control requirements. Relying on an explicit toggle (even if false) leaves dead code that a user or bug could flip.
**Prevention:** Hardcode required authentications without bypass mechanisms. Do not ship code capable of skipping authentication flows (like `authManager.signIn(userId: "local_user_\(UUID().uuidString)")`), even for internal debugging or incomplete feature flags, in public releases.
