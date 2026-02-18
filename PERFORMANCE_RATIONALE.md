# Performance Optimization Rationale: Redundant Sorting in StayValidation

## Current State
The `overlapCount` and `gapDays` functions in `StayValidation.swift` both sort the `stays` array by `enteredOn` in ascending order:
```swift
let sorted = stays.sorted { $0.enteredOn < $1.enteredOn }
```

## Problem
1. **Redundant Complexity**: In the primary usage path (`ContentView.swift`), the `stays` array is retrieved via a SwiftData `@Query` that already sorts it by `enteredOn` in reverse order:
   ```swift
   @Query(sort: [SortDescriptor(\Stay.enteredOn, order: .reverse)]) private var stays: [Stay]
   ```
2. **Computational Overhead**: Sorting an already sorted (or reverse-sorted) array takes O(N) with Swift's Timsort-based algorithm, but still involves multiple passes and O(N log N) in the general case.
3. **Memory Allocation**: `sorted()` creates a completely new array, leading to O(N) additional memory allocation.

## Optimization
Instead of re-sorting, we leverage the fact that the array is already sorted in reverse order. By calling `reversed()`, we:
1. **Reduce Time Complexity**: `reversed()` on an `Array` returns a `ReversedCollection` view, which is an O(1) operation. Iterating over this view is O(N).
2. **Eliminate Memory Allocation**: No new array is allocated for the sorting operation.
3. **Preserve Logic**: Both algorithms require stays to be processed in ascending order of `enteredOn`. Reversing a reverse-sorted (descending) array achieves this correctly.

## Verification
- Theoretical analysis confirms O(N) time and O(1) extra space (for the view) vs O(N log N) time and O(N) extra space for `sorted()`.
- Functional correctness is maintained as long as the input is sorted (ascending or descending). Given the app's structure, the input is consistently sorted by `enteredOn`.

# Performance Optimization Rationale: Database-Level Filtering in LedgerRecomputeService

## Current State
`LedgerRecomputeService` functions (`earliestSignalDate`, `fetchStays`, `fetchOverrides`, `fetchLocations`, `fetchPhotos`) fetch all records from the database into memory and then filter them using Swift's `filter` or `min()`:
```swift
let stays = (try? modelContext.fetch(FetchDescriptor<Stay>())) ?? []
return stays.filter { ... }
```

## Problem
1. **Memory Scalability**: Fetching all records (especially high-frequency `LocationSample` data) loads the entire dataset into memory, leading to O(N) memory usage where N is the total history size.
2. **Computational Overhead**: Iterating over all records in memory for filtering or finding min/max values is O(N) CPU time.
3. **Database Efficiency**: The database engine (CoreData/SQLite) is optimized for filtering and sorting, but these capabilities are bypassed.

## Optimization
Replace in-memory operations with `FetchDescriptor` configurations:
1. **Predicates for Range Queries**: Use `#Predicate` to filter records at the database level.
   - Reduces memory usage from O(Total Records) to O(Result Set Size).
   - Leverages database indexing (if available) for faster lookups (O(log N)).
2. **Sort + Limit for Aggregations**: Use `sortBy` and `fetchLimit: 1` to find the earliest date.
   - Reduces finding the minimum date from O(N) (scan all) to O(1) (index scan/first record).

## Verification
- Theoretical analysis confirms O(1) memory and time for finding min date (vs O(N)).
- Theoretical analysis confirms O(K) memory for range queries where K is the number of items in range (vs O(N) total items).
