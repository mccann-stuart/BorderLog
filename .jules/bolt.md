## 2026-02-18 - SwiftData Fetch Optimization
**Learning:** `LedgerRecomputeService` was fetching entire tables into memory to perform date filtering and min/max aggregation. This scales poorly (O(N) memory/time) as user history grows.
**Action:** Always prefer `FetchDescriptor` with `#Predicate` for filtering and `fetchLimit: 1` + `sortBy` for aggregations (min/max) to push work to the database engine (CoreData/SQLite).
