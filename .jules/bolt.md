
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

## 2026-02-18 - Lazy Evaluation for Limited Prefix Filtering
**Learning:** Filtering a large array using standard `.filter { ... }` executes immediately across all N elements, allocating a full intermediate array in memory. If the consuming logic only needs a small subset (e.g., `.prefix(5)` or `.isEmpty`), the vast majority of that computational work and memory allocation is wasted.
**Action:** Use `.lazy.filter { ... }.prefix(5)` before converting back to an Array. This transforms the operation from an O(N) full scan/allocation into an O(K) operation (where K is the number of elements checked to find the 5 matches), significantly reducing CPU time and completely eliminating the large intermediate array allocation.

## 2026-02-16 - Replace nested O(M) array scans with O(1) dictionary lookups in SwiftUI Forms
**Learning:** Using `.first(where:)` on an array of 250 elements (like all countries) inside a `.compactMap` operating on another array (like ledger counts) creates a hidden O(N * M) performance penalty that can degrade rendering performance, especially when typing or scrolling through SwiftUI Pickers.
**Action:** Replace linear `.first(where:)` scans with O(1) Dictionary lookups (`static let byCode: [String: CountryOption] = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })`) to instantly fetch static mapping data.

## 2026-06-12 - Replace Prefix of Sorted Array with O(N) Top-K Selection
**Learning:** Finding the top K elements (e.g., top 3 most visited countries) by calling `.sorted { ... }.prefix(K)` sorts the entire collection. This incurs an unnecessary O(N log N) processing cost and extra memory allocations. Inside widget generation paths or main loops, this degrades performance and creates ARC overhead.
**Action:** When you only need the highest scoring elements (like top 3), use a single O(N) iteration that manually tracks the top K items instead of sorting the whole array.
## 2026-02-18 - Early Break on Reverse Sorted Sequences
**Learning:** Filtering reverse-chronological datasets (like `PresenceDay` history) by time bounds using standard `.filter` or full `for` loops evaluates all N items unnecessarily.
**Action:** When iterating over a reverse-sorted dataset to find a specific time window, calculate the window's `Range<Date>` beforehand and use an early `break` when the current item is older than the `lowerBound`, turning O(N) into an O(K) operation.
## 2026-03-09 - Safe Dictionary Initialization
**Learning:** Using `Dictionary(uniqueKeysWithValues:)` to convert an array into a dictionary map is dangerous because it will crash the app if the source array contains duplicate keys (which can happen with dynamic database queries).
**Action:** Always use `Dictionary(_:uniquingKeysWith: { first, _ in first })` when initializing dictionaries from collections to guarantee safety against duplicate keys.

## 2026-06-12 - Safe Reverse-Sorted Array Evaluation
**Learning:** Applying an early `break` inside a loop assuming an array is reverse-sorted is dangerous if the sort order isn't guaranteed. Checking if `array.first >= array.last` is an unsafe heuristic because an unsorted array might accidentally satisfy this condition and cause the loop to prematurely skip valid elements in the middle.
**Action:** To safely apply early-exit optimizations on sorted data (like SwiftData `@Query` results), pass an explicit boolean flag (e.g., `isReverseSorted: Bool`) from the call-site rather than guessing the array's sort order via heuristics.

## 2026-03-19 - Optimize Unicode scalar preprocessing in flight parsing
**Learning:** Chaining `.unicodeScalars.filter`, `String(UnicodeScalarView(...))`, and `replacingOccurrences` in Swift causes multiple O(N) heap allocations and passes over the string.
**Action:** Use `raw.unicodeScalars.lazy.compactMap { ... }` and a `switch` statement on `scalar.value` to combine filtering and mapping into a single lazy pass, then initialize the result string directly with `String(scalars)`.

## 2026-03-22 - Fast-Path Normalized Strings in High-Frequency Loops
**Learning:** O(N) string operations like `trimmingCharacters(in:)` and `.uppercased()` generate significant heap memory allocation overhead when called repetitively inside high-frequency `for` loops (e.g., iterating over hundreds of `PresenceDay` models during SwiftUI view evaluation in `DashboardView` and `CountryDetailView`).
**Action:** Always add `O(1)` early-exit fast paths (like examining `code.utf8` sequences) to return the original unmodified string immediately if it already conforms to the required normalization standard. This avoids the hidden performance penalty of unnecessary heap reallocations.
## 2024-05-28 - O(N) array scans in UIKit delegate loops
**Learning:** Performing `O(N)` linear array scans (like `array.first(where:)`) inside repeatedly called UIKit rendering delegates (e.g., `UICalendarView.calendarView(_:decorationFor:)`) can severely bottleneck rendering performance.
**Action:** Pre-compute O(1) dictionary lookups inside the `didSet` observer of the state/snapshot object, rather than scanning the array inside the delegate loop. Use `Dictionary(_:uniquingKeysWith: { first, _ in first })` to ensure robustness against duplicates.
## 2026-06-12 - Replaced Sorting with Min for Top K Selection
**Learning:** Extracting a single top element using `.sorted { ... }.first` incurs an unnecessary O(N log N) processing cost and extra memory allocations compared to `.min(by: { ... })` (since `.min` returns the element that comes first under the predicate). Inside loops or widget generation paths, this degrades performance and creates ARC overhead.
**Action:** When you only need the highest scoring element, use `.min(by:)` (or `.max(by:)`) to perform a single O(N) pass with O(1) space complexity instead of sorting the whole array.
