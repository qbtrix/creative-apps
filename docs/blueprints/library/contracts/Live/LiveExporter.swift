// Live/LiveExporter.swift: spine stub. The export feature replaces this file
// with the live conformance and sets `unavailable` to nil; until then every
// call throws the reason, and controls that need it are disabled with it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveExporter: PhotoExporting {
    public static let unavailable: String? = "Export isn't connected yet (export)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    let decoder: any PhotoDecoding
    let develop: any DevelopRendering
    public init(decoder: any PhotoDecoding, develop: any DevelopRendering) {
        self.decoder = decoder; self.develop = develop
    }

    public func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        ExportPlan(items: [], options: options)
    }

    public func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage { throw Self.notBuilt }
}
