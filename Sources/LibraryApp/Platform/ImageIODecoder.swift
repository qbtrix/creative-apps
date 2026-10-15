// Platform/ImageIODecoder.swift: spine stub of the PhotoDecoding platform
// adapter. The import feature replaces it with the ImageIO conformance
// (scan, metadata, decode with orientation to sRGB RGBA8). Until then every
// call throws its "not built yet" reason, which the live services' own
// stubs already show on the controls that need it.
import Foundation
import LibraryModel

struct ImageIODecoder: PhotoDecoding {
    static let notBuilt = LibraryError.invalid("Reading photo files isn't built yet (import).")

    func scan(folder: String) async throws -> FolderScan { throw Self.notBuilt }
    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage { throw Self.notBuilt }
}
