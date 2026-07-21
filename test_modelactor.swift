import Foundation
import SwiftData

@ModelActor
actor DebugDataStoreExportService {
    func test() {
        let container = self.modelContainer
        print(container)
    }
}
