# Verify user-captured photos

- [x] Trace the existing PhotoKit ingestion, inference, diagnostics, and migration seams.
- [x] Confirm the supported Photos and ImageIO metadata available on the deployment target.
- [x] Define and test a conservative capture-provenance classifier.
- [x] Filter ingestion using MakerNote, EXIF original capture date, and PhotoKit added date.
- [x] Rebuild previously imported photo signals once under the stricter policy.
- [x] Update diagnostics and canonical product/privacy documentation.
- [x] Compile targeted tests, build the app, and self-review the final diff.

## Review

Photo ingestion now fails closed unless locally available original metadata identifies a
camera capture whose timezone-aware EXIF dates agree with Photos creation/addition dates
within ten minutes. A one-time rebuild revalidates the full historical range represented
by stored signals. Retained photo metadata is contextual and zero-weight because no public
PhotoKit or EXIF field can prove who pressed the shutter. `build-for-testing` succeeded;
test execution was unavailable because this machine has no installed Simulator runtime.
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
