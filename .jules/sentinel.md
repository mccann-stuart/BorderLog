## 2025-03-08 - UI Error Information Disclosure
**Vulnerability:** Displaying `error.localizedDescription` directly in the UI in `Learn/CalendarTabView.swift`.
**Learning:** Raw framework error descriptions can leak sensitive implementation details or system states to users.
**Prevention:** Catch errors, log them securely using `os.Logger` with `privacy: .private`, and display generic, safe error messages (like "Failed to load data. Please try again.") to the user.

## 2026-03-24 - Biometric Authentication Passcode Fallback
**Vulnerability:** Implementing custom fallback logic when `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)` fails can still permanently lock out users if `canEvaluatePolicy` succeeds but `evaluatePolicy` fails (e.g. broken FaceID sensor or repeated face mismatches without fallback to passcode).
**Learning:** `LAContext` native `.deviceOwnerAuthentication` policy securely and automatically handles falling back to device passcode when biometric authentication is unavailable or fails. The passcode remains a valid root of trust on the device.
**Prevention:** Always use `.deviceOwnerAuthentication` instead of `.deviceOwnerAuthenticationWithBiometrics` as the primary authentication policy when requiring user verification to unlock sensitive data in iOS apps, to ensure a seamless and reliable fallback to passcode.

## 2026-06-25 - Keychain Logging Information Noise
**Vulnerability:** Missing error logging for iOS Keychain `read` and `delete` operations, and lack of a centralized `Security` category for OS logging, obscures real security events. Simply adding generic logging introduces log spam with false positive `errSecItemNotFound` errors.
**Learning:** Security frameworks frequently return status codes like `errSecItemNotFound` during normal operation (e.g., checking if an item exists by trying to read it, or ensuring deletion). Logging these as errors obscures actual security failures. Additionally, using general categories like "Keychain" or the default makes it harder to filter for critical security events in device console logs.
**Prevention:** Always log security-related events using `os.Logger` with the `Security` category. When logging Keychain operation statuses, explicitly ignore `errSecItemNotFound` to prevent alert fatigue and maintain a high signal-to-noise ratio in security auditing.

## 2025-06-04 - Keychain Data Accessible When Unlocked
**Vulnerability:** The Keychain accessibility class `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` was used for sensitive data. This allows data to be read even when the device is locked, if it was unlocked once after booting.
**Learning:** For sensitive app data, especially when it acts as an authentication/session mechanism, it should be bound to the passcode. Using `WhenUnlockedThisDeviceOnly` only protects it before the *first* unlock, after which it remains available in memory for any process that can access the keychain group until the device reboots.
**Prevention:** Always use `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` for sensitive data stored in the iOS Keychain. This ensures that a device passcode is mandatory and that the data is encrypted using a key derived from the passcode.

## 2026-06-25 - Hardcoded Keychain Access Groups
**Vulnerability:** Hardcoding Apple Team IDs in source code to configure `kSecAttrAccessGroup` for cross-target Keychain sharing (like App Extensions).
**Learning:** Hardcoding team IDs reduces project portability, breaks builds when signing certificates change or are re-provisioned, and exposes internal team identifiers unnecessarily.
**Prevention:** Always use a dynamic runtime resolution strategy to determine the Team ID. This can be achieved by writing a dummy item to the keychain and immediately reading its `kSecAttrAccessGroup` property, which the OS automatically populates with the correct active Team ID prefix.
