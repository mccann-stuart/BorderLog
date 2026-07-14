
## 2025-03-09 - Dictionary pre-allocation optimization
**Learning:** Initializing an empty dictionary `[:]` and populating it inside a loop forces Swift to perform multiple underlying memory reallocations as the dictionary grows.
**Action:** When populating a dictionary from a collection of known size (e.g., inside a `for` loop), initialize the dictionary using `[Key: Value](minimumCapacity: collection.count)` to allocate sufficient memory upfront and avoid reallocation overhead.
