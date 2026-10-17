// FlareEasingSnapshots.swift: Flare's easing inspector on FakeEasingEditing at
// the window's inspector width (FlareWindow.inspectorWidth, 304 pt with its
// gutters), where every preset title reads in full (#1853). Writes flare-easing-editor-light.png
// and -dark.png (the Fake as it starts: x 0 → 24 on Ease, handle 1 ringed),
// flare-easing-editor-hold-dark.png (y 0 → 24, Hold: dimmed handles and a
// step curve), and flare-easing-editor-2x-dark.png, the same panel drawn at
// twice the size through scaleEffect so the curve's sharpness can be judged
// (the shared snapshot helper is fixed at scale 1; the bottom rows fall
// outside the 900 px frame there). flare-easing-editor-unavailable-dark.png
// shows the controls disabled under the reason given inside a symbol (#668).
// flare-easing-editor-unkeyed-dark.png is a layer with no keys: the EASING
// header and its hint alone, no bare KEYFRAMES header (#1861).
import FlareCore
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

        let unkeyed = UnkeyedEasingEditing()
        #expect(unkeyed.showsKeyframesHeader == false)
        try snapshot(EasingPanel(editor: unkeyed, focus: nil), name: "flare-easing-editor-unkeyed-dark", scheme: .dark)
    }
}

/// A selected layer with no keys: no segments, nothing selected.
private struct UnkeyedEasingEditing: EasingEditing {
    var easingSegments: [EasingSegment] { [] }
    var selectedEasingSegment: EasingSegment? { nil }
    var currentEasing: Easing? { nil }
    var canUndo: Bool { false }
    var easingUnavailableReason: String? { nil }
    mutating func selectEasingSegment(_ segment: EasingSegment) {}
    mutating func setEasingPreset(_ preset: EasingPreset) {}
    mutating func moveEasingHandle(_ handle: EasingHandle, to point: Point) {}
    mutating func endEasingHandleDrag() {}
    func easingCurveSamples(count: Int) -> [Point] { [] }
    mutating func undo() {}
}

private struct EasingPanel<Editor: EasingEditing>: View {
    let editor: Editor
    var focus: EasingHandleIndex? = .first
    var scale: CGFloat = 1

    var body: some View {
        FlareEasingInspector(
            editor: editor, onSelect: { _ in }, onPreset: { _ in }, onMoveHandle: { _, _ in }, onEndDrag: {},
            focusedHandle: focus)
            .padding(.horizontal, SuiteSpacing.m)
            .padding(.bottom, SuiteSpacing.m)
            .frame(width: FlareWindow.inspectorWidth, alignment: .topLeading)
            .background(SuiteColor.panel)
            .scaleEffect(scale, anchor: .topLeading)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
