# TODO

- [x] Locate active asset catalog and confirm missing AccentColor entry
- [x] Add AccentColor colorset with standard sRGB components
- [x] Verify AccentColor.colorset exists in asset catalog
- [x] Update WorldMapView onChange usage to iOS 17+ signature
- [x] Validate the change with Xcode diagnostics
- [x] Document result in Review section

# Review

- Result: AccentColor.colorset added under `Learn/Assets.xcassets`.
- Verification: Checked on-disk asset catalog contents for new colorset.
- Result: Updated WorldMapView onChange closures to the iOS 17+ two-parameter signature.
- Verification: `XcodeRefreshCodeIssuesInFile` reported no issues for `Learn/WorldMapView.swift`.
