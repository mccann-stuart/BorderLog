# Git Issue Resolution Plan

- [x] Analyze the current git state and the divergence.
- [x] Attempt to integrate `origin/main` into the local `main` branch.
- [x] Resolve any merge conflicts that arise.
- [x] Verify the application builds/compiles successfully and tests pass (Verification before done).
- [x] Finalize the integration (e.g., commit changes, push, or advise user).

## Review
- Successfully analyzed git divergence (2 local commits, 6 remote commits).
- Integrated `origin/main` without any merge conflicts using `git merge`.
- Verified compilation with `xcodebuild build`.
- Verified python tests pass for ContentView perf tests.

---

# Task Plan (Flighty Unicode Route Parsing)

- [x] Inspect current calendar parser and ingestor behavior for Flighty-style `MAN→MUC` titles.
- [ ] Add parser preprocessing to normalize hidden Unicode separators and non-breaking spaces before regex matching.
- [ ] Add notes line fallback parsing for plain city route lines (`Origin to Destination`).
- [ ] Extend parser tests for hidden Unicode IATA route and notes fallback while retaining existing pattern coverage.
- [ ] Re-run targeted tests for parser + calendar ingestor core suites.
- [ ] Record verification evidence and residual risks.

## Review (Flighty Unicode Route Parsing)

- Pending implementation.
