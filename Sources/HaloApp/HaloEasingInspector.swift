// HaloEasingInspector.swift: the EASING group of Halo's layer inspector
// (#428, EZ-6), in the house shape of Flare's easing inspector. One row per
// `model.keySegments` segment (a plain Button on a filled Studio row,
// `HaloEasingSegmentLabel`: its title, "Position X, frames 0–24", in
// secondary text left and its easing's title right on one line while both
// fit whole, else the easing under the title, so neither truncates; while
// picked, the selected well and a 1 pt accent border); a click picks it (`.selectKey`, Shift extends) and Escape picks
// nothing (`.clearKeySelection`). With a pick: the five presets as
// PresetGrid chips in `chipRows` (two short ones a row, "Ease In and Out"
// alone, so no title truncates; the on chip is `model.pickedPreset`, none
// for a custom curve) sending `.setEasing`, SuiteUI's CurveEditor
// (`halo.easing`, handles `halo.easing.handle1`/`handle2`) sending
// `.moveEasingHandle` (tooltip `curveTip`), and X1 Y1 X2 Y2 StudioScrubRows (`handleHelp` says
// what each is) sending `.setCustomEasing`, captioned `curveNote`; every curve drag, nudge and scrub ends in `.endEasingDrag`, so
// each is one undo step. With no segment the group starts collapsed (no
// extra height under the fold, #1412); open, it reads `emptyNote`. None
// picked: `unpickedNote`. A refusal on
// `halo.easing` shows under the group. Every control goes through
// `.haloControl` with a `halo.easing.*` id, disabled with
// `model.unavailableHelp(for:)` as help. It only reads the model and calls
// `perform`. Owns presentation state only: the hovered row.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI

struct HaloEasingInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    /// Whether the group opens with no segment to list; the empty snapshot
    /// opens it to show its text.
    var expandsWhenEmpty = false
    @State private var hovered: HaloKeyRef?

    /// The open group's text with no segment: how to make one (#1417).
    static let emptyNote = "Click a property's stopwatch, then add a second key to shape the easing between them."
    /// The text under the rows with none picked: a row is a span (#1454).
    static let unpickedNote = "Pick a span above to shape its easing."
    /// The caption under X1 to Y2: what the curve's axes and dashed line are (#1416).
    static let curveNote = "X is time, Y is progress: 0 at this key, 1 at the next. The dashed line is Linear."
    /// The curve's tooltip while it can act (#1416).
    static let curveTip = "Drag a handle to shape the easing between this key and the next."

    /// The preset chips a row: the short titles two by two, "Ease In and
    /// Out" alone, so every title fits at the inspector's minimum width.
    static let chipRows: [[HaloEasingPreset]] = [[.linear, .hold], [.easeIn, .easeOut], [.easeInOut]]

    /// The X1 to Y2 rows' tooltips: which handle, and what its number means.
    static func handleHelp(_ label: String) -> String {
        let handle = label.hasSuffix("1") ? "first" : "second"
        return label.hasPrefix("X")
            ? "Time of the \(handle) handle, from 0 (this key) to 1 (the next key)."
            : "Progress at the \(handle) handle, from 0 (this key's value) to 1 (the next key's value)."
    }

    /// A segment row's fill: the selected well while picked, else the
    /// Studio row's, lighter under the pointer.
    static func rowFill(picked: Bool, hovered: Bool) -> Color {
        picked ? SuiteColor.selectedWell : hovered ? SuiteColor.rowHover : SuiteColor.row
    }

    /// A segment row's border: accent while picked, so color isn't the
    /// pick's only cue (#1422); none otherwise.
    static func rowBorder(picked: Bool) -> Color? {
        picked ? SuiteColor.accent : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let segments = model.keySegments
            if segments.isEmpty {
                InspectorSection("Easing", isExpanded: expandsWhenEmpty) {
                    note(Self.emptyNote)
                }
            } else {
                InspectorSection("Easing") {
                    ForEach(segments) { segmentRow($0) }
                    if let segment = model.pickedSegment, let handles = model.easingHandles {
                        editor(segment, handles: handles)
                    } else {
                        note(Self.unpickedNote)
                    }
                }
                .onExitCommand { perform(.clearKeySelection) }
            }
            if let refusal = model.refusal, refusal.control == "halo.easing" {
                HaloRefusalCaption(refusal: refusal)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segmentRow(_ segment: HaloKeySegment) -> some View {
        let key = segment.key
        let help = model.unavailableHelp(for: .selectKey(key, extending: false))
        return Button {
            perform(.selectKey(key, extending: NSEvent.modifierFlags.contains(.shift)))
        } label: {
            HaloEasingSegmentLabel(title: segment.title, value: segment.easingTitle, picked: segment.isPicked)
                .frame(maxWidth: .infinity, minHeight: SuiteSize.chip, alignment: .leading)
                .background(
                    Self.rowFill(picked: segment.isPicked, hovered: key == hovered),
                    in: RoundedRectangle(cornerRadius: SuiteRadius.small))
                .overlay {
                    if let border = Self.rowBorder(picked: segment.isPicked) {
                        RoundedRectangle(cornerRadius: SuiteRadius.small).strokeBorder(border, lineWidth: 1)
                    }
                }
            .contentShape(RoundedRectangle(cornerRadius: SuiteRadius.small))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? key : (hovered == key ? nil : hovered) }
        .disabled(help != nil)
        .help(help ?? "\(segment.help) \(segment.easingTitle).")
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
            VStack(spacing: 0) {
                ForEach(Self.chipRows, id: \.self) { row in
                    PresetGrid(
                        options: row.map { InspectorOption(id: $0, title: $0.title) },
                        selected: model.pickedPreset, columns: row.count, onSelect: { perform(.setEasing($0)) })
                }
            }
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
                .help(curveHelp ?? Self.curveTip)
                .haloControl(id: "halo.easing", enabled: curveHelp == nil, help: curveHelp, identifies: false)
                .haloControl(id: "halo.easing.handle1", enabled: curveHelp == nil, help: curveHelp, identifies: false)
                .haloControl(id: "halo.easing.handle2", enabled: curveHelp == nil, help: curveHelp, identifies: false)
            scrubRow("X1", handles, first: true, x: true)
            scrubRow("Y1", handles, first: true, x: false)
            scrubRow("X2", handles, first: false, x: true)
            scrubRow("Y2", handles, first: false, x: false)
            note(Self.curveNote)
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
            .help(help ?? Self.handleHelp(label))
            .haloControl(id: "halo.easing.row.\(label.lowercased())", enabled: help == nil, help: help)
    }

    /// The cubic Bézier easing through `handles`.
    private static func curve(_ handles: (first: HaloPoint, second: HaloPoint)) -> HaloEasing {
        .cubicBezier(x1: handles.first.x, y1: handles.first.y, x2: handles.second.x, y2: handles.second.y)
    }
}

/// A segment row's text (#1450, #1453): the title left and the easing's
/// title right on one line while both fit whole, else the easing under the
/// title. Neither truncates. `oneLine` and `twoLines` are exactly what the
/// row draws, so HaloEasingSnapshots measures them.
struct HaloEasingSegmentLabel: View {
    let title: String
    let value: String
    var picked = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            oneLine
            twoLines
        }
    }

    /// Title and value side by side, at least `SuiteSpacing.s` apart.
    var oneLine: some View {
        HStack(spacing: 0) {
            titleText
            Spacer(minLength: SuiteSpacing.s)
            valueText
        }
        .padding(.horizontal, SuiteSpacing.m)
    }

    /// The value under the title, each on its own line.
    var twoLines: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xxs) {
            titleText
            valueText
        }
        .padding(.horizontal, SuiteSpacing.m)
        .padding(.vertical, SuiteSpacing.xs)
    }

    private var titleText: some View {
        Text(verbatim: title)
            .font(SuiteFont.inspectorLabel)
            .foregroundStyle(picked ? SuiteColor.accentText : SuiteColor.textSecondary)
            .lineLimit(1)
            .fixedSize()
    }

    private var valueText: some View {
        Text(verbatim: value)
            .font(SuiteFont.inspectorValue)
            .foregroundStyle(SuiteColor.textPrimary)
            .lineLimit(1)
            .fixedSize()
    }
}
