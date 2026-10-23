// SuiteStatusPills.swift: the status bar's live pill rule (UC14), which
// ViewerStatusBar (EC-6a) takes its zoom and size text from. The zoom reads
// through ViewerZoom.percentText (the one formatter every app shares, so NaN,
// infinity and 0 read "–"), then "W × H" with each side rounded to the
// nearest whole unit (1919.6 reads 1920), then the trailing pills in their
// order. A side that isn't a finite number, or doesn't fit an Int, reads 0,
// never traps.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteStatusPills: StatusPillComposing {
    public init() {}

    public func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill] {
        let size = "\(Self.side(documentSize.width)) × \(Self.side(documentSize.height))"
        return [StatusPill(text: ViewerZoom.percentText(zoom)), StatusPill(text: size)] + trailing
    }

    /// A side in whole units, rounded half away from zero; 0 when it isn't finite or doesn't fit an Int.
    private static func side(_ value: Double) -> Int {
        Int(exactly: value.rounded(.toNearestOrAwayFromZero)) ?? 0
    }
}
