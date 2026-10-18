// SuiteStatusPills.swift: the status pills' live rule (UC14). A stub with its
// final signature until EC-6b of the editor-chrome packet adds the edge cases
// (a rounded size). ViewerStatusBar is live in every app, so the stub already
// gives today's text: the zoom from ViewerZoom.percentText ("200%", "–" for a
// zoom that isn't a number), then "W × H", then the trailing pills in order.
// Foundation only.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteStatusPills: StatusPillComposing {
    public init() {}
    public func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill] {
        [StatusPill(text: ViewerZoom.percentText(zoom)), StatusPill(text: StatusPillSize.text(documentSize))] + trailing
    }
}
