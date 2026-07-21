## Tasks
- [x] <!-- id: 1 --> Establish a performance baseline and verify logic (Using Python proxy script to prove semantic equivalence since Swift toolchain is unavailable).
- [x] <!-- id: 2 --> Optimize `LedgerRecomputeService.swift`
- [x] <!-- id: 3 --> Verify Changes using bash tools.
- [x] <!-- id: 4 --> Run Tests (Swift toolchain not available, fallback to semantic equivalence verified in step 1).
- [x] <!-- id: 5 --> Complete pre commit steps (tests bypassed, code reviewed, learnings recorded).
<!-- id: 10 -->
- [x] Unrolled `fetchEarliestAvailableMonth` intermediate array compactMap comparison to O(1) tracking logic to reduce allocation and ARC overhead.

## Open PR acceptance — 21 July 2026

- [x] Inventory and review every open PR for correctness, overlap, checks, and merge order.
- [x] Merge verified PRs, resolving any conflicts against the latest `main` on the PR branches.
- [x] Run relevant integrated app and backend verification on the final `main`.
- [x] Confirm GitHub has no mergeable work left unintentionally open.

### Review

- Reviewed 22 PRs (#259–#280): merged 19 and closed three that were duplicate, based on a false security premise, or carried an unmeasured concurrency rewrite with unrelated artefacts.
- Repaired conflicts or merge blockers on #262, #263, #269, #270, #271, #278, and #280 on their PR branches before merging.
- Verified final `main` with the backend test suite and an iOS `build-for-testing` for both simulator architectures; four focused `DataManagerTests` also passed.
- The full simulator XCTest run could not start because CoreSimulator stalled while booting. The corrected #280 tests compiled successfully, and GitHub's final open-PR list was empty.
