# Ignore shared photo albums

- [x] Locate the Photos asset fetch used by ingestion.
- [x] Restrict ingestion to assets from the user's library.
- [x] Run the narrowest relevant verification and review the diff.

## Review

Added `PHAssetSourceType.typeUserLibrary` to the existing PhotoKit fetch options so
shared-album assets are excluded without changing date, image-type, or limited-library
behaviour. The Learn scheme builds successfully for a generic iOS Simulator.
