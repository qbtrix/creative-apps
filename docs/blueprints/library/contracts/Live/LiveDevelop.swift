// Live/LiveDevelop.swift: spine stub. The develop feature replaces this file
// with the live conformance and sets `unavailable` to nil; until then every
// call throws the reason, and controls that need it are disabled with it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveDevelop: DevelopRendering {
    public static let unavailable: String? = "Develop isn't connected yet (develop)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    public init() {}

    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        // Neutral settings are already right; anything else waits for the feature.
        guard settings.isNeutral else { throw Self.notBuilt }
        return buffer
    }

    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins { .empty }  // no histogram until develop
}
