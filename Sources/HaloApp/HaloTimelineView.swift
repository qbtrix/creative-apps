// HaloTimelineView.swift: the strip along the bottom of Halo's viewer: one
// SuiteUI TimelineStrip track per layer of the selected composition, its span
// bar running from the layer's in point to its out point, fitted so the whole
// composition shows. Dragging the ruler scrubs, clicking a track selects its
// layer, and while the strip has focus (any click on it gives it focus) I and
// O set the selected layer's in and out points at the playhead. Values in,
// closures out; HaloProject keeps the playhead and the points.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTimelineView: View {
    let composition: HaloComposition
    let rows: [HaloTimelineRow]
    var onScrub: @MainActor (Int) -> Void = { _ in }
    var onSelectLayer: @MainActor (HaloLayer.ID) -> Void = { _ in }
    var onSetInPoint: @MainActor () -> Void = {}
    var onSetOutPoint: @MainActor () -> Void = {}
    @FocusState private var hasFocus: Bool

    var body: some View {
        let tracks = rows.map { TimelineTrack(id: $0.id, name: $0.name, spans: [$0.span], isSelected: $0.isSelected) }
        GeometryReader { geometry in
            let lanes = Double(geometry.size.width - SuiteSize.timelineLabelColumn - SuiteSpacing.xl)
            TimelineStrip(
                tracks: tracks, duration: composition.durationFrames,
                frameWidth: CGFloat(composition.frameWidth(toFit: lanes)), playhead: composition.playheadFrame,
                onScrub: { frame in
                    hasFocus = true
                    onScrub(frame)
                },
                onSelectTrack: { id in
                    hasFocus = true
                    onSelectLayer(id)
                })
        }
        .frame(height: SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(rows.count))
        .focusable()
        .focused($hasFocus)
        .focusEffectDisabled()
        .onKeyPress(characters: CharacterSet(charactersIn: "iIoO")) { press in
            if press.characters.lowercased() == "i" { onSetInPoint() } else { onSetOutPoint() }
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
        .accessibilityIdentifier("halo.timeline")
        .help("Drag the ruler to move the playhead. I sets the selected layer's in point, O its out point.")
    }
}
