// Live/LiveDevelop.swift: spine stub. The develop feature replaces this file
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

public struct LiveDevelop: DevelopRendering {
    public static let unavailable: String? = "Develop isn't connected yet (develop)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    public init() {}

    /// Neutral settings are already right; anything else waits for the feature.
    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        guard settings.isNeutral else { throw Self.notBuilt }
        return buffer
    }

    /// No histogram until develop, so the live loupe works in wave 2.
    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins { .empty }
}
