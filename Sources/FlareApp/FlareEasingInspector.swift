// FlareEasingInspector.swift: the easing editor in Flare's inspector, under
// two Studio caps headers. KEYFRAMES lists the selected layer's segments (an
// amber diamond, the property, "0 → 24", and the selected row's preset);
// EASING shapes the selected segment with SuiteUI's CurveEditor, ChoiceChips
// and four StudioScrubRows (x1, y1, x2, y2). Generic over the EasingEditing
// contract, so it runs on FakeEasingEditing in snapshots and on FlareWorkspace
// in the window. It only reads the editor and calls the closures; it never
// mutates the editor. Every drag, nudge or typed value ends in `onEndDrag`,
// so each is one undo step. Owns presentation state only: the hovered row.
// It brings no side gutter of its own; the inspector it sits in supplies one.
// When the editor gives an `easingUnavailableReason` (inside a symbol, on a
// locked layer), the EASING controls show disabled under that reason (#668).
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareEasingInspector<Editor: EasingEditing>: View {
    let editor: Editor
    let onSelect: @MainActor (EasingSegment) -> Void
    let onPreset: @MainActor (EasingPreset) -> Void
    let onMoveHandle: @MainActor (EasingHandle, Point) -> Void
    let onEndDrag: @MainActor () -> Void
    /// Starts with this handle ringed, as after a click (snapshots).
    var focusedHandle: EasingHandleIndex?
    @State private var hovered: EasingSegment?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Keyframes")
            ForEach(editor.easingSegments) { segmentRow($0) }
            header("Easing")
            easing
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(SuiteFont.sectionCaps)
            .textCase(.uppercase)
            .tracking(SuiteSize.capsTracking)
            .foregroundStyle(SuiteColor.secondaryText)
            .padding(.top, SuiteSpacing.m)
            .padding(.bottom, SuiteSpacing.xs)
    }

    private func segmentRow(_ segment: EasingSegment) -> some View {
        let selected = segment == editor.selectedEasingSegment
        let title = "\(segment.property) \(segment.startFrame) → \(segment.endFrame)"
        return Button { onSelect(segment) } label: {
            HStack(spacing: SuiteSpacing.s) {
                Image(systemName: "diamond.fill")
                    .font(SuiteFont.rulerLabel)
                    .imageScale(.small)
                    .foregroundStyle(SuiteColor.keyframed)
                Text(segment.property)
                    .font(SuiteFont.inspectorLabel)
                    .foregroundStyle(selected ? SuiteColor.accentText : Color.primary)
                Text("\(segment.startFrame) → \(segment.endFrame)")
                    .font(SuiteFont.inspectorValue)
                    .foregroundStyle(SuiteColor.secondaryText)
                Spacer(minLength: SuiteSpacing.s)
                if selected {
                    Text(editor.currentEasingPreset?.title ?? "Custom")
                        .font(SuiteFont.inspectorMeta)
                        .foregroundStyle(SuiteColor.secondaryText)
                }
            }
            .padding(.horizontal, SuiteSpacing.s)
            .frame(maxWidth: .infinity, minHeight: SuiteSize.chip, maxHeight: SuiteSize.chip, alignment: .leading)
            .background(
                selected ? SuiteColor.selectedWell : segment == hovered ? SuiteColor.panelRaised : Color.clear,
                in: RoundedRectangle(cornerRadius: SuiteRadius.small))
            .contentShape(RoundedRectangle(cornerRadius: SuiteRadius.small))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? segment : (hovered == segment ? nil : hovered) }
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var easing: some View {
        if let easing = editor.currentEasing, let handles = editor.currentEasingHandles {
            let reason = editor.easingUnavailableReason
            if let reason {
                Text(reason)
                    .font(SuiteFont.inspectorMeta)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, SuiteSpacing.xs)
                    .accessibilityIdentifier("flare.easing.unavailable")
            }
            VStack(spacing: SuiteSpacing.xs) {
                CurveEditor(
                    samples: editor.easingCurveSamples(count: 129).map { CGPoint(x: $0.x, y: $0.y) },
                    handles: (CGPoint(x: handles.first.x, y: handles.first.y), CGPoint(x: handles.second.x, y: handles.second.y)),
                    dimmedHandles: easing == .hold, focusedHandle: focusedHandle, id: "flare.easing",
                    onMove: { index, point in
                        onMoveHandle(index == .first ? .first : .second, Point(x: point.x, y: point.y))
                    },
                    onEnd: onEndDrag)
                ChoiceChips(
                    options: EasingPreset.allCases.map { InspectorOption(id: $0, title: $0.title) },
                    selected: editor.currentEasingPreset, onSelect: onPreset)
                    .padding(.vertical, SuiteSpacing.xs)
                scrubRow("X1", .first, handles.first, x: true)
                scrubRow("Y1", .first, handles.first, x: false)
                scrubRow("X2", .second, handles.second, x: true)
                scrubRow("Y2", .second, handles.second, x: false)
            }
            .disabled(reason != nil)
        } else {
            Text(editor.easingSegments.isEmpty ? "Key a property to shape its easing." : "Pick a keyframe above.")
                .font(SuiteFont.inspectorMeta)
                .foregroundStyle(SuiteColor.secondaryText)
        }
    }

    /// One coordinate of one handle: x in 0...1, y in -1...2, step 0.01.
    private func scrubRow(_ label: String, _ handle: EasingHandle, _ point: Point, x: Bool) -> some View {
        StudioScrubRow(
            label: label, value: x ? point.x : point.y, range: x ? 0...1 : -1...2, step: 0.01,
            onChange: { onMoveHandle(handle, x ? Point(x: $0, y: point.y) : Point(x: point.x, y: $0)) },
            onEnd: onEndDrag)
            .accessibilityIdentifier("flare.easing.row.\(label.lowercased())")
    }
}
