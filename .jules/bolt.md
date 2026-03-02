## 2026-02-18 - SwiftData Fetch Optimization
**Learning:** `LedgerRecomputeService` was fetching entire tables into memory to perform date filtering and min/max aggregation. This scales poorly (O(N) memory/time) as user history grows.
**Action:** Always prefer `FetchDescriptor` with `#Predicate` for filtering and `fetchLimit: 1` + `sortBy` for aggregations (min/max) to push work to the database engine (CoreData/SQLite).

## 2026-02-18 - R2 Conditional Fetch Optimization
**Learning:** Cloudflare Workers `R2Bucket.get()` fetches the object body by default even if `If-None-Match` matches the ETag (unless `onlyIf` is used). This wastes bandwidth and memory.
**Action:** Use `onlyIf: { etagDoesNotMatch: ... }` in `get()` calls when handling conditional requests to avoid fetching the body when the client already has the latest version.

## 2024-03-02 - FetchDescriptor Predicate Optimization
**Learning:** In SwiftData, fetching all entities (e.g. `Stay`) and filtering them in memory with `filter` causes full-table loads which is O(N) memory and compute. This can be heavily optimized by pushing the filter logic to the database using `#Predicate`.
**Action:** When working with SwiftData, always prefer `#Predicate` in `FetchDescriptor` over in-memory filtering for potentially large datasets like stays, locations, or photos.
