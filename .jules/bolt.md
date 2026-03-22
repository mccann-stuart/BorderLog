
## 2024-05-28 - O(N) array scans in UIKit delegate loops
**Learning:** Performing `O(N)` linear array scans (like `array.first(where:)`) inside repeatedly called UIKit rendering delegates (e.g., `UICalendarView.calendarView(_:decorationFor:)`) can severely bottleneck rendering performance.
**Action:** Pre-compute O(1) dictionary lookups inside the `didSet` observer of the state/snapshot object, rather than scanning the array inside the delegate loop. Use `Dictionary(_:uniquingKeysWith: { first, _ in first })` to ensure robustness against duplicates.
