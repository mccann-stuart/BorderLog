## 2026-02-18 - LedgerRecomputeService Dictionary Allocation Optimization
**Learning:** Initializing dictionaries by looping and manually assigning keys to an empty dictionary `var existingMap: [String: PresenceDay] = [:]` incurs continuous ARC thrashing and O(N log N) reallocation overhead because the dictionary must resize dynamically as elements are added.
**Action:** Use `.reduce(into: [Key: Value](minimumCapacity: count)) { $0[$1.key] = $1 }` when transforming an array of unique elements into a dictionary to statically preallocate exactly the required memory, ensuring a strict O(N) pass with O(1) auxiliary overhead beyond the dictionary itself.

## 2024-07-14 - Pre-allocate Dictionary Capacity During Iteration
**Learning:** Initializing an empty dictionary and populating it via a `for` loop with elements from an array is an anti-pattern in Swift. It results in repeated buffer reallocations and O(N) ARC overhead as the dictionary grows.
**Action:** Replace `for` loop dictionary mutations with `array.reduce(into: [Key: Value](minimumCapacity: array.count)) { $0[key] = value }` to perform transformations directly into a pre-sized buffer, bypassing heap allocation costs and redundant hashing overhead.
## 2026-02-22 - Explicit Validation of Methods Before Planning
**Learning:** Assuming a method exists based on naming conventions (e.g., `fail()`) leads to a Groundedness Rule violation during plan review.
**Action:** Always use a tool call (`grep` or `read_file`) to output the exact method signature into the trace before including it in an execution plan.

## 2026-02-22 - Thorough Testing of Async Continuations
**Learning:** Testing Swift continuations requires capturing the invocation in a detached `Task` to avoid deadlocks while setting up state or mock responses.
**Action:** Encapsulate the function under test in a `Task { await function() }`, use a polling mechanism to ensure internal state is updated (like pending waiter count), supply the mock data, and then await the task's value.
