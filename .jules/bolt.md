## 2026-02-18 - LedgerRecomputeService Dictionary Allocation Optimization
**Learning:** Initializing dictionaries by looping and manually assigning keys to an empty dictionary `var existingMap: [String: PresenceDay] = [:]` incurs continuous ARC thrashing and O(N log N) reallocation overhead because the dictionary must resize dynamically as elements are added.
**Action:** Use `.reduce(into: [Key: Value](minimumCapacity: count)) { $0[$1.key] = $1 }` when transforming an array of unique elements into a dictionary to statically preallocate exactly the required memory, ensuring a strict O(N) pass with O(1) auxiliary overhead beyond the dictionary itself.

## 2024-07-14 - Pre-allocate Dictionary Capacity During Iteration
**Learning:** Initializing an empty dictionary and populating it via a `for` loop with elements from an array is an anti-pattern in Swift. It results in repeated buffer reallocations and O(N) ARC overhead as the dictionary grows.
**Action:** Replace `for` loop dictionary mutations with `array.reduce(into: [Key: Value](minimumCapacity: array.count)) { $0[key] = value }` to perform transformations directly into a pre-sized buffer, bypassing heap allocation costs and redundant hashing overhead.
## 2024-07-21 - Avoid intermediate array allocations in loops
**Learning:** Using `.map` directly on a collection within a `for` loop declaration in Swift causes an unnecessary `O(N)` allocation of an intermediate array before iteration begins.
**Action:** Removed `.map` from the `for` loop declaration and evaluated the mapped expression (`Self.calendarCountry(from: countedCountry)`) directly inside the loop body, achieving `O(1)` memory overhead while maintaining exact functionality.
## 2026-07-21 - Extract massive View structs into subviews
**Learning:** Monolithic SwiftUI views with massively nested `@ViewBuilder` logic cause performance issues, make code harder to read, and result in dead code (like orphaned properties when UI elements change).
**Action:** Used python scripting to refactor `SettingsView` by splitting it into smaller, reusable structs (`SettingsProfileSection`, `SettingsDataSourcesSection`, etc.) and explicitly passing state via `@Binding` and closures, thus improving code health.
