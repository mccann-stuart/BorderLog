#if canImport(XCTest)
import XCTest
@testable import Learn

final class LedgerRecomputeRecoveryStoreTests: XCTestCase {
    func testDirtyKeysPersistAcrossStoreInstancesAndClearSelectively() throws {
        let suiteName = "LedgerRecomputeRecoveryStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = LedgerRecomputeRecoveryStore(defaults: defaults)
        let firstToken = firstStore.markDirty(dayKeys: ["2026-07-10"])
        firstStore.markDirty(dayKeys: ["2026-07-11"])

        let relaunchedStore = LedgerRecomputeRecoveryStore(defaults: defaults)
        XCTAssertEqual(
            relaunchedStore.dirtyDayKeys(),
            Set(["2026-07-10", "2026-07-11"])
        )

        relaunchedStore.clearDirty(matching: firstToken)
        XCTAssertEqual(relaunchedStore.dirtyDayKeys(), Set(["2026-07-11"]))
    }

    func testOlderCompletionTokenCannotClearNewerDirtyWrite() throws {
        let suiteName = "LedgerRecomputeRecoveryStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LedgerRecomputeRecoveryStore(defaults: defaults)
        let olderToken = store.markDirty(dayKeys: ["2026-07-11"])
        let newerToken = store.markDirty(dayKeys: ["2026-07-11"])

        store.clearDirty(matching: olderToken)
        XCTAssertEqual(store.dirtyDayKeys(), Set(["2026-07-11"]))

        store.clearDirty(matching: newerToken)
        XCTAssertTrue(store.dirtyDayKeys().isEmpty)
    }

    func testSourceReconciliationVersionPersists() throws {
        let suiteName = "LedgerRecomputeRecoveryStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LedgerRecomputeRecoveryStore(defaults: defaults)
        XCTAssertTrue(store.needsSourceReconciliation(version: 1))

        store.recordSourceReconciliation(version: 1)

        let relaunchedStore = LedgerRecomputeRecoveryStore(defaults: defaults)
        XCTAssertFalse(relaunchedStore.needsSourceReconciliation(version: 1))
        XCTAssertTrue(relaunchedStore.needsSourceReconciliation(version: 2))
    }
}
#endif
