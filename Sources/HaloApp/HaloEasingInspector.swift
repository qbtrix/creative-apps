// HaloEasingInspector.swift: the EASING group of Halo's layer inspector
// (#428, EZ-6), in the house shape of Flare's easing inspector. One row per
// `model.keySegments` segment (a plain Button: its title, "Position X 0 →
// 24", and its easing's title as value, selected while picked); a click picks
// it (`.selectKey`, Shift extends) and Escape picks nothing
// (`.clearKeySelection`). With a pick: ChoiceChips for the five presets (the
// on chip is `model.pickedPreset`, none for a custom curve) sending
// `.setEasing`, SuiteUI's CurveEditor (`halo.easing`, handles
// `halo.easing.handle1`/`handle2`) sending `.moveEasingHandle`, and X1 Y1 X2
// Y2 StudioScrubRows sending `.setCustomEasing`; every curve drag, nudge and
// scrub ends in `.endEasingDrag`, so each is one undo step. Empty: "Key a
// property to shape its easing." with no segment, "Pick a key above." with
// none picked. A refusal on `halo.easing` shows under the group. Every
// control goes through `.haloControl` with a `halo.easing.*` id, disabled
// with `model.unavailableHelp(for:)` as help. It only reads the model and
// calls `perform`. Owns presentation state only: the hovered row.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI

struct HaloEasingInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    @State private var hovered: HaloKeyRef?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorSection("Easing") {
                let segments = model.keySegments
                if segments.isEmpty {
                    note("Key a property to shape its easing.")
                } else {
                    ForEach(segments) { segmentRow($0) }
                    if let segment = model.pickedSegment, let handles = model.easingHandles {
                        editor(segment, handles: handles)
                    } else {
                        note("Pick a key above.")
                    }
                }
            }
            .onExitCommand { perform(.clearKeySelection) }
            if let refusal = model.refusal, refusal.control == "halo.easing" {
                HaloRefusalCaption(refusal: refusal)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segmentRow(_ segment: HaloKeySegment) -> some View {
        let key = segment.key
        let help = model.unavailableHelp(for: .selectKey(key, extending: false))
        return Button {
            perform(.selectKey(key, extending: NSEvent.modifierFlags.contains(.shift)))
        } label: {
            HStack(spacing: SuiteSpacing.s) {
                Image(systemName: "diamond.fill")
                    .font(SuiteFont.rulerLabel)
                    .imageScale(.small)
                    .foregroundStyle(SuiteColor.keyframed)
                Text(segment.title)
                    .font(SuiteFont.inspectorLabel)
                    .foregroundStyle(segment.isPicked ? SuiteColor.accentText : Color.primary)
                Spacer(minLength: SuiteSpacing.s)
                Text(segment.easingTitle)
                    .font(SuiteFont.inspectorMeta)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
            .padding(.horizontal, SuiteSpacing.s)
            .frame(maxWidth: .infinity, minHeight: SuiteSize.chip, maxHeight: SuiteSize.chip, alignment: .leading)
            .background(
                segment.isPicked ? SuiteColor.selectedWell : key == hovered ? SuiteColor.panelRaised : Color.clear,
                in: RoundedRectangle(cornerRadius: SuiteRadius.small))
            .contentShape(RoundedRectangle(cornerRadius: SuiteRadius.small))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? key : (hovered == key ? nil : hovered) }
        .disabled(help != nil)
        .help(help ?? segment.title)
        .accessibilityLabel(Text(verbatim: segment.title))
        .accessibilityValue(Text(verbatim: segment.easingTitle))
        .accessibilityAddTraits(segment.isPicked ? .isSelected : [])
        .haloControl(id: "halo.easing.key.\(key.property.rawValue).\(key.frame)", enabled: help == nil, help: help)
    }

    /// The chips, the curve and the four numbers for the picked segment.
    private func editor(_ segment: HaloKeySegment, handles: (first: HaloPoint, second: HaloPoint)) -> some View {
        let presetHelp = model.unavailableHelp(for: .setEasing(model.pickedPreset ?? .linear))
        let curveHelp = model.unavailableHelp(for: .moveEasingHandle(index: 0, x: handles.first.x, y: handles.first.y))
        return VStack(spacing: SuiteSpacing.xs) {
            ChoiceChips(
                options: HaloEasingPreset.allCases.map { InspectorOption(id: $0, title: $0.title) },
                selected: model.pickedPreset, onSelect: { perform(.setEasing($0)) })
                .padding(.vertical, SuiteSpacing.xs)
                .disabled(presetHelp != nil)
                .haloControl(id: "halo.easing.presets", enabled: presetHelp == nil, help: presetHelp, identifies: false)
            CurveEditor(
                samples: model.easingCurve(count: 129).map { CGPoint(x: $0.x, y: $0.y) },
                handles: (CGPoint(x: handles.first.x, y: handles.first.y), CGPoint(x: handles.second.x, y: handles.second.y)),
                dimmedHandles: segment.easing == .hold, id: "halo.easing",
                onMove: { index, point in
                    perform(.moveEasingHandle(index: index == .first ? 0 : 1, x: point.x, y: point.y))
                },
                onEnd: { perform(.endEasingDrag) })
                .disabled(curveHelp != nil)
                .haloControl(id: "halo.easing", enabled: curveHelp == nil, help: curveHelp, identifies: false)
                .haloControl(id: "halo.easing.handle1", enabled: curveHelp == nil, help: curveHelp, identifies: false)
                .haloControl(id: "halo.easing.handle2", enabled: curveHelp == nil, help: curveHelp, identifies: false)
            scrubRow("X1", handles, first: true, x: true)
            scrubRow("Y1", handles, first: true, x: false)
            scrubRow("X2", handles, first: false, x: true)
            scrubRow("Y2", handles, first: false, x: false)
        }
    }

    /// One coordinate of one handle: x in 0...1, y in -1...2, step 0.01.
    /// A change sends the whole curve with that coordinate moved.
    private func scrubRow(
        _ label: String, _ handles: (first: HaloPoint, second: HaloPoint), first: Bool, x: Bool
    ) -> some View {
        let point = first ? handles.first : handles.second
        let help = model.unavailableHelp(for: .setCustomEasing(Self.curve(handles)))
        return StudioScrubRow(
            label: label, value: x ? point.x : point.y, range: x ? 0...1 : -1...2, step: 0.01,
            onChange: { value in
                let moved = x ? HaloPoint(x: value, y: point.y) : HaloPoint(x: point.x, y: value)
                let curve = first ? (first: moved, second: handles.second) : (first: handles.first, second: moved)
                perform(.setCustomEasing(Self.curve(curve)))
            },
            onEnd: { perform(.endEasingDrag) })
            .disabled(help != nil)
            .help(help ?? label)
            .haloControl(id: "halo.easing.row.\(label.lowercased())", enabled: help == nil, help: help)
    }

    /// The cubic Bézier easing through `handles`.
    private static func curve(_ handles: (first: HaloPoint, second: HaloPoint)) -> HaloEasing {
        .cubicBezier(x1: handles.first.x, y1: handles.first.y, x2: handles.second.x, y2: handles.second.y)
    }
}
