// DesignSampleLoupe.swift (eyedropper DY-3): the Eyedropper's overlay on the canvas and its options in the
// inspector. While the tool is active the overlay takes the canvas's clicks: a click sends one `.pick` onto the
// side the Model's `loupe(at:modifiers:)` (DesignLoupe) names (the inspector's Fill or Stroke, Option for the other),
// so the view decides nothing. It draws SuiteUI's SampleLoupe at the pointer; the loupe lives in
// DesignCanvasHover, observed by this body alone, so it follows the pointer without re-running the canvas, the
// editor or the window. DesignSampleOptions is the inspector's Eyedropper section: SuiteUI's SampleSizeChips under
// a "Sample" caption, and a Fill/Stroke segmented picker. Both read the model and send intents; neither writes it.
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
                    SampleLoupe(color: loupe.color.map(\.hex), at: Self.place(loupe, zoom: zoom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
        guard let loupe = model.loupe(at: point, modifiers: modifiers) else { return }
        perform(.pick(loupe.point, toStroke: loupe.toStroke))
    }
}

/// The inspector's Eyedropper section: the square it reads and the side a plain click picks onto.
struct DesignSampleOptions: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text("Sample")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
            SampleSizeChips(size: model.sampleSize) { perform(.sampleSize($0)) }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Sample")
            InspectorRow("Pick onto") {
                Picker(
                    "Pick onto",
                    selection: Binding(get: { model.sampleToStroke }, set: { perform(.sampleTarget(toStroke: $0)) })
                ) {
                    Text("Fill").tag(false)
                    Text("Stroke").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("design.sample.target")
                .help("What a click picks onto; Option-click picks the other one.")
            }
        }
    }
}
