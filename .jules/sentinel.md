## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-04-10 - Secure Error Visibility in Keychain and Auth Failure Paths
**Vulnerability:** Core system security functions like `LAContext.canEvaluatePolicy` and `SecItemCopyMatching` often return precise diagnostic `NSError` objects or `OSStatus` codes when they fail. Failing to log these hides critical availability insights, but simply printing them out can leak deep system state into unified logs.
**Learning:** We need visibility into *why* a device locked out a user or why a Keychain read failed (e.g., to distinguish between a locked device vs. an expired token). The standard `os.Logger` provides a `privacy: .private` interpolation option that securely captures these granular codes for local debugging sessions without exposing them to production telemetry or public OS logs.
**Prevention:** Always log the `error` from `canEvaluatePolicy` and non-`errSecItemNotFound` statuses from Keychain operations using `logger.error("... \(error, privacy: .private)")` rather than swallowing the error or logging it dynamically without privacy protections.
