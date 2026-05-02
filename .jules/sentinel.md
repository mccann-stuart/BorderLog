## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-04-20 - Insecure Keychain Default Accessibility
**Vulnerability:** Using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` allows storing sensitive data (like session IDs and passport nationality) in the Keychain even if the user has disabled their device passcode. This fundamentally undermines the security assumptions of encrypted storage.
**Learning:** For a travel app handling sensitive PII and authentication tokens, data should *never* be persisted to the Keychain unless it is actively protected by a device passcode.
**Prevention:** Use `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` as the default accessibility constant for Keychain writes. This ensures writes fail (with errSecDecode) if no passcode is set, preventing silent downgrades to unencrypted storage.
