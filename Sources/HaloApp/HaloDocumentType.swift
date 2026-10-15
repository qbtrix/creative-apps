// HaloDocumentType.swift: the `.halo` file type and the document Save As…'s
// exporter writes. The type comes from the extension, conforming to JSON;
// until the bundle's Info.plist declares it (an issue on line:suiteui asks
// for that), the system gives it a dynamic type, which both panels accept.
// HaloProjectDocument carries a snapshot of the project and encodes it with
// `fileData()` when the exporter writes, off the main actor.
import HaloModel
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A Halo project file, "Spot.halo".
    static let halo = UTType(filenameExtension: "halo", conformingTo: .json) ?? .json
}

/// The project as the save panel writes it.
struct HaloProjectDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.halo]

    let project: HaloProject

    init(project: HaloProject) { self.project = project }

    /// The exporter never reads; opening goes through HaloProject's file service.
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try project.fileData())
    }
}
