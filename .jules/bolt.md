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

## 2026-02-17 - Avoid .filter {}.count on sorted arrays
**Learning:** Chaining `.filter {}.count` on Swift arrays not only iterates over the entire collection but needlessly allocates memory for intermediate arrays. In `ContentView.swift`, multiple properties were doing this on the same `presenceDays` array which is pre-sorted by SwiftData (`@Query(sort: [SortDescriptor(\PresenceDay.date, order: .reverse)])`). This leads to unnecessary memory pressure and garbage collection overhead.
**Action:** Replace multiple `.filter {}.count` calls with a single `for` loop that computes all metrics in one pass using integer counters `O(1)` memory. Additionally, if the source array is pre-sorted, use early loop exits (`break` or `continue`) to stop the scan once the condition bounds are breached.

## 2026-02-16 - Prevent Multi-pass Filtering
**Learning:** Chaining `.filter()` calls, or evaluating arrays into intermediate arrays before iterating again, results in unnecessary O(N) heap allocations, Arc thrashing, and constant-factor latency increases, especially for frequently rendered dashboard views evaluating large histories.
**Action:** Replace sequential `.filter`s with a single `for` loop that evaluates multiple conditions in-line. Combine condition checks or use early break/continue when properties guarantee ordered data.

## 2026-03-09 - Avoid O(N log N) Sorting when Extracting a Single Max/Min
**Learning:** Sorting an array or dictionary (`.sorted { ... }`) to extract only the top element (`.first`) results in unnecessary O(N log N) processing and allocates a new sequence in memory.
**Action:** When finding the highest or lowest scoring item in a Swift collection, always use `.max(by:)` or `.min(by:)` to perform a single O(N) pass with O(1) space complexity instead of sorting.

## 2026-04-14 - Optimize Top-K Selection to Avoid Sorting
**Learning:** Finding the top 1 or 2 elements from a dictionary/array (e.g., top-scoring countries) by calling `.sorted { ... }` sorts the entire collection. This incurs an unnecessary O(N log N) processing cost and extra memory allocations. Inside hot loops (like processing thousands of presence days), this accumulates and degrades performance.
**Action:** When you only need the highest scoring element or the top few, use a single O(N) iteration that manually tracks the "winner" and "runner-up", or use `.max(by:)` if only the absolute best is needed.
