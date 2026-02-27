## 2026-02-18 - SwiftData Fetch Optimization
**Learning:** `LedgerRecomputeService` was fetching entire tables into memory to perform date filtering and min/max aggregation. This scales poorly (O(N) memory/time) as user history grows.
**Action:** Always prefer `FetchDescriptor` with `#Predicate` for filtering and `fetchLimit: 1` + `sortBy` for aggregations (min/max) to push work to the database engine (CoreData/SQLite).

## 2026-02-18 - R2 Conditional Fetch Optimization
**Learning:** Cloudflare Workers `R2Bucket.get()` fetches the object body by default even if `If-None-Match` matches the ETag (unless `onlyIf` is used). This wastes bandwidth and memory.
**Action:** Use `onlyIf: { etagDoesNotMatch: ... }` in `get()` calls when handling conditional requests to avoid fetching the body when the client already has the latest version.

## 2026-02-18 - O(N²) Algorithmic Complexity in Presence Inference
**Learning:** `PresenceInferenceEngine`'s logic to suggest missing days previously scanned forward and backwards from the current index inside an already O(N) loop to find nearest known country signals, creating an O(N²) bottleneck for long gaps.
**Action:** When filling gaps or interpolating missing data in sorted collections, use two sequential pass operations to pre-calculate values into linear arrays (`backwardSuggestions`, `forwardSuggestions`) to maintain an overall O(N) runtime.
