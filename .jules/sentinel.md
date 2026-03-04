## 2026-02-15 - Cloudflare Worker Security Headers Pattern
**Vulnerability:** Missing standard security headers (HSTS, CSP, etc.) in backend responses.
**Learning:** Cloudflare Workers require manual header injection for every response. Using a centralized `createResponse` helper ensures consistency across all exit paths (success, error, 404).
**Prevention:** Use the `createResponse` helper pattern in all future Worker endpoints to automatically apply strict security headers.
## 2026-02-16 - Keychain Storage Security Enhancement
**Vulnerability:** Sensitive credentials saved to Keychain could be backed up or migrate to other devices.
**Learning:** The `kSecAttrAccessibleWhenUnlocked` option allows migration. For app-specific local security, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is safer.
**Prevention:** Always evaluate data flow requirements when using Keychain. Prefer `...ThisDeviceOnly` variants unless cross-device sync is explicitly needed.
