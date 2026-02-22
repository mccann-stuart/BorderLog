## 2026-02-18 - SwiftData Fetch Optimization
**Learning:** `LedgerRecomputeService` was fetching entire tables into memory to perform date filtering and min/max aggregation. This scales poorly (O(N) memory/time) as user history grows.
**Action:** Always prefer `FetchDescriptor` with `#Predicate` for filtering and `fetchLimit: 1` + `sortBy` for aggregations (min/max) to push work to the database engine (CoreData/SQLite).

## 2026-02-18 - R2 Conditional Fetch Optimization
**Learning:** Cloudflare Workers `R2Bucket.get()` fetches the object body by default even if `If-None-Match` matches the ETag (unless `onlyIf` is used). This wastes bandwidth and memory.
**Action:** Use `onlyIf: { etagDoesNotMatch: ... }` in `get()` calls when handling conditional requests to avoid fetching the body when the client already has the latest version.

## 2026-02-23 - SwiftData Main Thread Bottleneck
**Learning:** Mapping a large `@Query` result array (e.g. `stays.map`) on the Main Actor faults every object in the array, causing UI hitches if the dataset is large (e.g., 10 years of history), even if only recent data is needed.
**Action:** Use a targeted `FetchDescriptor` with a `#Predicate` (e.g., matching a date window) inside the update logic to fetch only the necessary subset of data, rather than processing the entire `@Query` result.
