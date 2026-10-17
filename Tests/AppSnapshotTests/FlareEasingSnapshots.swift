// FlareEasingSnapshots.swift: on FakeEasingEditing with x 0 → 24 on Ease
// Out (IT-8, #378), flare-timing-row.png is TIMING reading "Ease Out" and
// flare-easing-popover.png the popover's content, handle 1 ringed (a snapshot
// can't open a popover), both at FlareWindow.inspectorWidth.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareEasingSnapshots {
    @Test func easingEditor() throws {
        var start = FakeEasingEditing()
        start.setEasingPreset(.easeOut)
        #expect(start.currentEasingPreset == .easeOut)
        let row = FlareTimingRow(
            editor: start, onSelect: { _ in }, onPreset: { _ in }, onMoveHandle: { _, _ in }, onEndDrag: {})
        try snapshot(EasingPanel(content: FlareInspectorTiming(easing: row)), name: "flare-timing-row", scheme: .dark)
        let popover = FlareEasingPopover(
            editor: start, onPreset: { _ in }, onMoveHandle: { _, _ in }, onEndDrag: {}, focusedHandle: .first)
        try snapshot(EasingPanel(content: popover), name: "flare-easing-popover", scheme: .dark)
    }
}

private struct EasingPanel<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .padding(.horizontal, SuiteSpacing.m)
            .padding(.bottom, SuiteSpacing.m)
            .frame(width: FlareWindow.inspectorWidth, alignment: .topLeading)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
