## 2026-02-15 - Cloudflare Worker Security Headers Pattern
**Vulnerability:** Missing standard security headers (HSTS, CSP, etc.) in backend responses.
**Learning:** Cloudflare Workers require manual header injection for every response. Using a centralized `createResponse` helper ensures consistency across all exit paths (success, error, 404).
**Prevention:** Use the `createResponse` helper pattern in all future Worker endpoints to automatically apply strict security headers.
## 2025-02-15 - [Keychain Accessibility Security]
**Vulnerability:** Keychain items were configured with `kSecAttrAccessibleWhenUnlocked`, which allows data to be included in backups and migrated to new devices.
**Learning:** Always use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for sensitive user identity/authentication data to prevent unintended data extraction via backups or device migration.
**Prevention:** Default to `ThisDeviceOnly` variants for all `kSecAttrAccessible` properties in `KeychainHelper` and similar persistence utilities.
