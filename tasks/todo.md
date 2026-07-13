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
