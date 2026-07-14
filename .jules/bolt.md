
## 2024-07-14 - Pre-allocate Dictionary Capacity During Iteration
**Learning:** Initializing an empty dictionary and populating it via a `for` loop with elements from an array is an anti-pattern in Swift. It results in repeated buffer reallocations and O(N) ARC overhead as the dictionary grows.
**Action:** Replace `for` loop dictionary mutations with `array.reduce(into: [Key: Value](minimumCapacity: array.count)) { $0[key] = value }` to perform transformations directly into a pre-sized buffer, bypassing heap allocation costs and redundant hashing overhead.
