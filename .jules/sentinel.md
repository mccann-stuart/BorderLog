## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-03-24 - Authentication Bypass in Production Code
**Vulnerability:** A static toggle `isAppleSignInEnabled` and an accompanying local fallback button in `WelcomeView` allowed developers (or potentially users if enabled) to completely bypass authentication by injecting a locally generated UUID ("local_user_XYZ") as a valid sign-in identity.
**Learning:** Any mechanism built into the application to mock or skip authentication directly violates access control and sets a precedent where production builds could mistakenly ship with bypass capabilities active. The identity token serves as a critical trust anchor for the app and cloud sync, which cannot be spoofed locally.
**Prevention:** Never leave local-only authentication fallbacks or test toggles in production code. All required authentication (such as Apple Sign-In) must be hard-coded as mandatory without configurable bypass conditions. Testing auth flows should be handled at the system environment level, not the app business logic layer.
