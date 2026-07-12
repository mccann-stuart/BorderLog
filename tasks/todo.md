# Biometric authentication lifecycle

- [x] Trace the app-level scene lifecycle and biometric authentication flow.
- [x] Start device-owner authentication only while the scene is active.
- [x] Treat system and app cancellation as a neutral locked state.
- [x] Add focused regression coverage for cancellation classification.
- [x] Run the narrowest relevant test/build and review the diff.

## Review

The lock overlay now receives the active-scene state, blocks authentication while
inactive, and starts one authentication request when the scene becomes active.
App and system cancellation leave the app locked without displaying a failure;
user cancellation and genuine authentication failures retain the retry message.

Focused cancellation-classifier tests were added. The app and test bundles compile
successfully with `xcodebuild build-for-testing` for a generic iOS Simulator. A
focused test execution was attempted on `iPhone 17`, but the simulator launcher did
not materialise a worker, so the run was stopped after compilation completed.
