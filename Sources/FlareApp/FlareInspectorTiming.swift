// FlareInspectorTiming.swift: the inspector's TIMING section (IT-8, #378).
// FlareTimingRow is a Span picker over the layer's keyframe spans and an
// Easing button (`flare.inspector.easing`) reading the span's preset name, or
// "Custom", which opens FlareEasingPopover. It only reads the editor and
// calls the window's Model easing closures: every edit is one undo step.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareInspectorTiming<Easing: View>: View {
    let easing: Easing

    var body: some View { InspectorSection("Timing") { easing } }
}

struct FlareTimingRow<Editor: EasingEditing>: View {
    let editor: Editor
    let onSelect: @MainActor (EasingSegment) -> Void
    let onPreset: @MainActor (EasingPreset) -> Void
    let onMoveHandle: @MainActor (EasingHandle, Point) -> Void
    let onEndDrag: @MainActor () -> Void
    @State private var showsPopover = false

    var body: some View {
        if editor.easingSegments.isEmpty {
            Text("Key a property to shape its easing.")
                .font(SuiteFont.inspectorMeta)
                .foregroundStyle(SuiteColor.secondaryText)
        } else {
            InspectorPickerRow(
                "Span", options: spans, selection: editor.selectedEasingSegment,
                onChange: { if let segment = $0 { onSelect(segment) } })
                .accessibilityIdentifier("flare.inspector.span")
            InspectorRow("Easing") {
                Button(easingName) { showsPopover = true }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("flare.inspector.easing")
                    .disabled(editor.selectedEasingSegment == nil)
                    .help(editor.selectedEasingSegment == nil ? "Select a keyframe span to ease it." : "Edit the easing curve")
                    .popover(isPresented: $showsPopover, arrowEdge: .leading) {
                        FlareEasingPopover(
                            editor: editor, onPreset: onPreset, onMoveHandle: onMoveHandle, onEndDrag: onEndDrag)
                    }
            }
        }
    }

    /// The selected span's preset name, "Custom" off every preset, "None" with no span.
    private var easingName: String {
        guard editor.currentEasing != nil else { return "None" }
        return editor.currentEasingPreset?.title ?? "Custom"
    }

    /// Every span, after a "Choose…" placeholder that stands for no selection.
    private var spans: [InspectorOption<EasingSegment?>] {
        [InspectorOption(id: nil, title: "Choose…")]
            + editor.easingSegments.map { InspectorOption(id: $0, title: $0.title) }
    }
}
