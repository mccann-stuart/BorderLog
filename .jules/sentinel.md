## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-04-02 - Removed Apple Sign-In Authentication Bypass
**Vulnerability:** A static toggle `isAppleSignInEnabled` and a corresponding fallback branch existed in the codebase, enabling a bypass of the Apple Sign-In authentication process (e.g., by automatically logging in as a randomly generated UUID when `isAppleSignInEnabled` was set to `false`).
**Learning:** Any mechanism intended for "local testing" or "bypassing" authentication in production code creates an immediate, critical access control vulnerability. Production code shouldn't include any pathways to override or skip necessary user verification routines, as they are likely to be accidentally flipped or exploited by malicious actors mapping application logic.
**Prevention:** Hardcode necessary authentication paths completely and delete any bypass logic. Do not build bypasses for internal debugging; instead, require proper test environments or mock user data that respects the entire authentication chain.
