// Live/LiveThumbnails.swift: spine stub. The thumbnails feature replaces this file
// with the live conformance and sets `unavailable` to nil; until then every
// call throws the reason, and controls that need it are disabled with it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveThumbnails: ThumbnailProviding {
    public static let unavailable: String? = "Thumbnails aren't connected yet (thumbnails)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    let decoder: any PhotoDecoding
    let develop: any DevelopRendering
    public init(decoder: any PhotoDecoding, develop: any DevelopRendering) {
        self.decoder = decoder; self.develop = develop
    }

    public func thumbnail(for photo: PhotoItem, longSide: Int) async throws -> DisplayImage { throw Self.notBuilt }

    public func invalidate(_ id: String) async {}
}
