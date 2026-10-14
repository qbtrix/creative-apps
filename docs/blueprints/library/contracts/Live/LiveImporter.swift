// Live/LiveImporter.swift: spine stub. The import feature replaces this file
// with the live conformance and sets `unavailable` to nil. Until then it
// does what needs no file (samples through `SampleImage`, pure rules) and
// throws its reason for anything that needs the feature, so the controls
// that need it are disabled with that reason.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveImporter: PhotoImporting {
    public static let unavailable: String? = "Import isn't connected yet (import)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    let decoder: any PhotoDecoding
    public init(decoder: any PhotoDecoding) { self.decoder = decoder }

    public func importFolder(_ folder: String, known: Set<String>,
                             progress: @escaping @Sendable (ImportProgress) -> Void,
                             added: @escaping @Sendable ([PhotoItem]) -> Void) async throws -> ImportResult {
        throw Self.notBuilt
    }
}
