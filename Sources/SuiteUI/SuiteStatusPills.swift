// SuiteStatusPills.swift: the status bar's live pill rule (UC14), declared
// with its final signature so ViewerStatusBar (EC-6a) can take its zoom and
// size text from it. ViewerStatusBar is live in every app, so this stub
// already gives today's text: the zoom through ViewerZoom.percentText (the one
// formatter every app shares), then "W × H" in whole units, then the trailing
// pills in order. A side that isn't a finite number reads 0, never traps.
// EC-6b adds the edge cases (rounding each side).
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

    /// A side in whole units, truncated; 0 when it isn't finite or doesn't fit an Int.
    private static func side(_ value: Double) -> Int {
        Int(exactly: value.rounded(.towardZero)) ?? 0
    }
}
