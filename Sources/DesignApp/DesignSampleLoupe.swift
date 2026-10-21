// DesignSampleLoupe.swift (eyedropper DY-3): the Eyedropper's overlay on the canvas. While the tool is active it
// takes the canvas's clicks: a click sends one `.pick` onto the selection's fill, an Option-click one onto its
// stroke, both asked of the Model's `loupe(at:modifiers:size:)` (DesignLoupe) so the view decides nothing. It
// draws SuiteUI's SampleLoupe at the pointer and SuiteUI's SampleSizeChips, on a GlassPanel, at the artboard's
// top left. The loupe and the sample size live in DesignCanvasHover, observed by this body alone, so the loupe
// follows the pointer without re-running the canvas, the editor or the window. It reads the model and never
// writes it.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignSampleLoupe: View {
    let model: DesignWorkspace
    let zoom: Double
    var perform: DesignPerform
    /// The store the canvas this overlay belongs to reads and writes.
    let store = DesignCanvasHover.current
    #if DEBUG
    /// How many times the overlay's body ran: once per pointer sample that moved the loupe.
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        if model.tool == .eyedropper {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(.rect)
                    .gesture(SpatialTapGesture().onEnded { pick(at: $0.location, modifiers: .current) })
                if let loupe = store.loupe(for: model) {
                    SampleLoupe(color: loupe.color.map { HexColor($0.red, $0.green, $0.blue) }, at: Self.place(loupe, zoom: zoom))
                }
                Self.sizeChips(store.sampleSize) { store.setSampleSize($0, on: model) }
                    .padding(SuiteSpacing.s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// SuiteUI's sample-size chips at the narrowest inspector column's width, on a GlassPanel. They float over the
    /// artwork: at their bare fitting width a 1x display rounds "Point" over into "Poi…", and with no backing the
    /// chosen chip's light label vanishes on a white artboard in Dark.
    static func sizeChips(_ size: SampleSize, onChange: @escaping @MainActor (SampleSize) -> Void) -> some View {
        GlassPanel { SampleSizeChips(size: size, onChange: onChange).frame(width: SuiteSize.inspectorWidth.min) }
            .fixedSize()
    }

    /// Where the loupe draws on the artboard at `zoom`.
    nonisolated static func place(_ loupe: DesignLoupe, zoom: Double) -> CGPoint {
        let scale = usable(zoom)
        return CGPoint(x: loupe.point.x * scale, y: loupe.point.y * scale)
    }

    /// A click at `location` (artboard points) with `modifiers` held: one pick, or none when the Model shows no loupe.
    func pick(at location: CGPoint, modifiers: DesignModifiers) {
        let scale = usable(zoom)
        let point = DesignPoint(x: location.x / scale, y: location.y / scale)
        guard let loupe = model.loupe(at: point, modifiers: modifiers, size: store.sampleSize) else { return }
        perform(.pick(loupe.point, toStroke: loupe.toStroke))
    }
}
