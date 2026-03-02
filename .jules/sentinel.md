## 2026-02-15 - Cloudflare Worker Security Headers Pattern
**Vulnerability:** Missing standard security headers (HSTS, CSP, etc.) in backend responses.
**Learning:** Cloudflare Workers require manual header injection for every response. Using a centralized `createResponse` helper ensures consistency across all exit paths (success, error, 404).
**Prevention:** Use the `createResponse` helper pattern in all future Worker endpoints to automatically apply strict security headers.

## 2026-03-02 - Secure Keychain Accessibility Attributes
**Vulnerability:** Use of `kSecAttrAccessibleWhenUnlocked` allows sensitive data to migrate via iCloud Keychain to other devices.
**Learning:** For device-specific sensitive data (like Apple User ID, or local app user preferences), it is more secure to bind the data strictly to the current device.
**Prevention:** Always default to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` or `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` for secrets that do not need to roam, which limits the attack surface if another device on the iCloud account is compromised.
