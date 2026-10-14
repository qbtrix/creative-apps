// Live/LiveLoupeImaging.swift: spine stub. The loupe-viewport feature replaces this file
// with the live conformance and sets `unavailable` to nil; until then every
// call throws the reason, and controls that need it are disabled with it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveLoupeImaging: LoupeImaging {
    public static let unavailable: String? = "The loupe picture isn't connected yet (loupe-viewport)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    let decoder: any PhotoDecoding
    let develop: any DevelopRendering
    public init(decoder: any PhotoDecoding, develop: any DevelopRendering) {
        self.decoder = decoder; self.develop = develop
    }

    public func render(_ photo: PhotoItem, settings: DevelopSettings, longSide: Int,
                       quality: RenderQuality) async throws -> RenderedPhoto {
        throw Self.notBuilt
    }

    public func prefetch(_ photos: [PhotoItem], longSide: Int) async {}
}
