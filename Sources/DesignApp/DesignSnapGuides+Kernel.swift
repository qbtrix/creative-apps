// DesignSnapGuides+Kernel.swift: the canvas's smart guides (snapping SN-7), drawn in
// DesignCanvasFeedback's slot. While a drag runs, the guides of the live copy the canvas shows
// (`model.snapGuides`, never the window's Model mid-drag) are drawn by SuiteUI's SnapGuideMarks:
// accent lines, gap lines with end ticks (spacing dashed) and each gap's length in a pill, all one
// size at any zoom. XCUITest can't see marks drawn in a canvas, so a 1 pt ProbeElement,
// `design.canvas.guides`, reads them in words (as its label and its value): the running drag's
// summary, else the last drag's (kept after mouse-up), else "none"; a new press clears the kept
// one. The kept summary is
// written at most twice per gesture (the release and the next press), never per sample.
// DesignGuidePin lets the snapshots pin a fixed guide set for one render.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// A guide set the snapshots bind around a render, drawn in place of the Model's.
enum DesignGuidePin {
    @TaskLocal static var guides: DesignSnapGuides?
}

/// The drag's smart guides at `zoom` (points per page point), nil when no gesture runs.
struct DesignGuideOverlay: View {
    let guides: DesignSnapGuides?
    let zoom: Double
    /// The last drag's summary, kept from its release until the next press.
    @State private var last: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let guides {
                SnapGuideMarks(guides: guides, zoom: zoom).accessibilityHidden(true)
            }
            let words = Self.value(guides, last: last)
            ProbeElement(DesignControlID.canvasGuides, label: words, value: words, size: CGSize(width: 1, height: 1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .onChange(of: guides) { old, new in
            if new == nil, let old {
                last = Self.words(old)
            } else if new != nil, last != nil {
                last = nil
            }
        }
    }

    /// What `design.canvas.guides` reads: the running drag's guides, else `last`, else "none".
    nonisolated static func value(_ guides: DesignSnapGuides?, last: String?) -> String {
        guides.map(words) ?? last ?? "none"
    }

    /// `guides` in words: their summary, or "none" when the drag snapped to nothing.
    nonisolated static func words(_ guides: DesignSnapGuides) -> String {
        guides.summary.isEmpty ? "none" : guides.summary
    }
}
