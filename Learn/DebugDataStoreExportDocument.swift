#if DEBUG

//
//  DebugDataStoreExportDocument.swift
//  Learn
//
//  Created by Codex on 21/03/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct DebugDataStoreExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#endif
