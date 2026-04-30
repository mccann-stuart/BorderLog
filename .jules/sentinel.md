## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2024-05-01 - Enhance Keychain Accessibility and Logging
**Vulnerability:** Using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` leaves Keychain items potentially accessible after the device is merely unlocked once. Logging security events with generic categories makes audit and triage difficult.
**Learning:** `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` provides stronger security by tying the keychain item strictly to the presence of a device passcode, ensuring the item is removed if the passcode is removed. Security-related failures should be explicitly logged with a "Security" category to facilitate auditing.
**Prevention:** Always default to `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` for device-bound sensitive data unless broader accessibility is strictly required. Use dedicated logging categories for security events.
