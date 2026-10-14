// FlareEasingSnapshots.swift: Flare's easing inspector on FakeEasingEditing at
// the inspector's ideal width (260 pt). Writes flare-easing-editor-light.png
// and -dark.png (the Fake as it starts: x 0 → 24 on Ease, handle 1 ringed),
// flare-easing-editor-hold-dark.png (y 0 → 24, Hold: dimmed handles and a
// step curve), and flare-easing-editor-2x-dark.png, the same panel drawn at
// twice the size through scaleEffect so the curve's sharpness can be judged
// (the shared snapshot helper is fixed at scale 1; the bottom rows fall
// outside the 900 px frame there). flare-easing-editor-unavailable-dark.png
// shows the controls disabled under the reason given inside a symbol (#668).
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareEasingSnapshots {
    @Test func easingEditor() throws {
        let start = FakeEasingEditing()
        #expect(start.currentEasingPreset == .ease)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(EasingPanel(editor: start), name: "flare-easing-editor-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
        try snapshot(EasingPanel(editor: start, scale: 2), name: "flare-easing-editor-2x-dark", scheme: .dark)

        var hold = start
        hold.selectEasingSegment(EasingSegment(property: "y", startFrame: 0, endFrame: 24))
        #expect(hold.currentEasingPreset == .hold)
        try snapshot(EasingPanel(editor: hold, focus: nil), name: "flare-easing-editor-hold-dark", scheme: .dark)

        let inSymbol = FakeEasingEditing(unavailableReason: "Exit the symbol to change its easing.")
        try snapshot(EasingPanel(editor: inSymbol, focus: nil), name: "flare-easing-editor-unavailable-dark", scheme: .dark)
    }
}

private struct EasingPanel: View {
    let editor: FakeEasingEditing
    var focus: EasingHandleIndex? = .first
    var scale: CGFloat = 1

    var body: some View {
        FlareEasingInspector(
            editor: editor, onSelect: { _ in }, onPreset: { _ in }, onMoveHandle: { _, _ in }, onEndDrag: {},
            focusedHandle: focus)
            .padding(.horizontal, SuiteSpacing.m)
            .padding(.bottom, SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
            .background(SuiteColor.panel)
            .scaleEffect(scale, anchor: .topLeading)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
