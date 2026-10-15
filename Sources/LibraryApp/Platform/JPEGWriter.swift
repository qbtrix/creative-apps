// Platform/JPEGWriter.swift: spine stub of the JPEGWriting platform adapter.
// The export feature replaces it with the ImageIO conformance (sRGB JPEG,
// never overwriting). Until then every call throws its "not built yet" reason.
import Foundation
import LibraryModel

struct JPEGWriter: JPEGWriting {
    static let notBuilt = LibraryError.invalid("Writing JPEG files isn't built yet (export).")

    func existingNames(in folder: String) async throws -> Set<String> { throw Self.notBuilt }
    func write(_ image: DisplayImage, quality: Int, folder: String, fileName: String) async throws {
        throw Self.notBuilt
    }
}
