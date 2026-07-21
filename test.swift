import Foundation
import SwiftData

@ModelActor
actor DebugDataStoreExportService {
    func buildPayload() async throws {
        let container = self.modelContainer
        print(container)
    }
}
