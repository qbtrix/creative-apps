// FlareEasingPopover.swift: the easing popover TIMING's Easing button opens
// (FlareInspectorTiming.swift; IT-8, #378), under a Studio caps header and
// the selected span's title.
// EASING shapes the selected segment with SuiteUI's CurveEditor, ChoiceChips
// and four StudioScrubRows (x1, y1, x2, y2), each with a tooltip naming its
// handle, axis and range (#1847). Generic over the EasingEditing
// contract, so it runs on FakeEasingEditing in snapshots and on FlareWorkspace
// in the window. It only reads the editor and calls the closures; it never
// mutates the editor. Every drag, nudge or typed value ends in `onEndDrag`,
// so each is one undo step. It owns no state.
// When the editor gives an `easingUnavailableReason` (inside a symbol, on a
// locked layer), the EASING controls show disabled under that reason (#668).
// The preset chips get theirs once ChoiceChips takes one per option (#1148).
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareEasingPopover<Editor: EasingEditing>: View {
    let editor: Editor
    let onPreset: @MainActor (EasingPreset) -> Void
    let onMoveHandle: @MainActor (EasingHandle, Point) -> Void
    let onEndDrag: @MainActor () -> Void
    /// Starts with this handle ringed, as after a click (snapshots).
    var focusedHandle: EasingHandleIndex?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Easing")
            if let segment = editor.selectedEasingSegment {
                Text(segment.title)
                    .font(SuiteFont.inspectorMeta)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .padding(.bottom, SuiteSpacing.xs)
            }
            easing
        }
        .padding([.horizontal, .bottom], SuiteSpacing.m)
        .frame(width: SuiteSize.editorPanelWidth)
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
                scrubRow(.first, .x, handles.first)
                scrubRow(.first, .y, handles.first)
                scrubRow(.second, .x, handles.second)
                scrubRow(.second, .y, handles.second)
            }
            .disabled(reason != nil)
        } else {
            Text("Pick a keyframe span to shape its easing.")
                .font(SuiteFont.inspectorMeta)
                .foregroundStyle(SuiteColor.secondaryText)
        }
    }

    /// One coordinate of one handle: x in 0...1, y in -1...2, step 0.01.
    private func scrubRow(_ handle: EasingHandle, _ axis: EasingAxis, _ point: Point) -> some View {
        let x = axis == .x
        return StudioScrubRow(
            label: handle.label(axis), value: x ? point.x : point.y, range: axis.range, step: 0.01,
            onChange: { onMoveHandle(handle, x ? Point(x: $0, y: point.y) : Point(x: point.x, y: $0)) },
            onEnd: onEndDrag)
            .help(handle.help(axis))
            .accessibilityIdentifier("flare.easing.row.\(handle.label(axis).lowercased())")
    }
}
