## 2026-02-18 - SwiftData Fetch Optimization
**Learning:** `LedgerRecomputeService` was fetching entire tables into memory to perform date filtering and min/max aggregation. This scales poorly (O(N) memory/time) as user history grows.
**Action:** Always prefer `FetchDescriptor` with `#Predicate` for filtering and `fetchLimit: 1` + `sortBy` for aggregations (min/max) to push work to the database engine (CoreData/SQLite).

## 2026-02-18 - R2 Conditional Fetch Optimization
**Learning:** Cloudflare Workers `R2Bucket.get()` fetches the object body by default even if `If-None-Match` matches the ETag (unless `onlyIf` is used). This wastes bandwidth and memory.
**Action:** Use `onlyIf: { etagDoesNotMatch: ... }` in `get()` calls when handling conditional requests to avoid fetching the body when the client already has the latest version.

## 2024-03-02 - FetchDescriptor Predicate Optimization
**Learning:** In SwiftData, fetching all entities (e.g. `Stay`) and filtering them in memory with `filter` causes full-table loads which is O(N) memory and compute. This can be heavily optimized by pushing the filter logic to the database using `#Predicate`.
**Action:** When working with SwiftData, always prefer `#Predicate` in `FetchDescriptor` over in-memory filtering for potentially large datasets like stays, locations, or photos.

## 2026-02-18 - Single-Pass Sequence Iteration vs Chained Filters
**Learning:** Chaining multiple `.filter` calls on Swift collections (`Array`) or executing `filter` multiple times over the same subset incurs a large O(N) memory allocation penalty because each `.filter` generates a new array.
**Action:** When computing multiple metrics or sub-sets over a sequence, prefer a single `for` loop pass with standard conditional checks. This reduces iteration count and eliminates unnecessary memory allocations (dropping space complexity from O(N) to O(1)).

## 2026-02-16 - Precalculating Fallbacks/Suggestions in Array Processing
**Learning:** Nested loops used for resolving missing data points (like scanning forward/backward in a chronological array to find the nearest non-nil value) can severely degrade performance to O(N²) when large gaps exist.
**Action:** When filling gaps in chronological data, perform two linear passes (O(N)) first: one forward pass to precalculate the previous known value, and one backward pass to precalculate the next known value. Store these in O(N) arrays. Then, iterate the original array once more to apply these suggestions in O(1) time per element.

## 2026-03-08 - Redundant Array Re-sorting from @Query
**Learning:** Calling `.sorted()` on arrays returned from a SwiftData `@Query(sort:)` after applying an in-memory `.filter` introduces an unnecessary O(N log N) sorting cost because SwiftData `@Query` results are already pre-sorted. In-memory `.filter` preserves the original order of the elements.
**Action:** When filtering a sorted array or `@Query` result, do not call `.sorted()` unless the sort criteria has explicitly changed. The resulting array from `.filter` inherently maintains the order.
