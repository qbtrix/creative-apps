// FlareTimingRowTests.swift: TIMING's Easing button (`flare.inspector.easing`)
// keeps its frame whatever name it reads. Its popover hangs off the button's
// leading edge, so a button that shrank from "Ease Out" to "Custom" on the
// first drag sample slid the popover, and the curve under the pointer, about
// 7 pt right mid-drag (FlareJourneyTests testEasingPresetAndCurve: handle 1
// landed at x 0.22 for a drag to 0.25).
import AppKit
import FlareCore
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

@MainActor @Suite struct FlareTimingRowTests {
    @Test func theEasingButtonKeepsItsFrameFromEaseOutToCustom() throws {
        var editor = FakeEasingEditing()
        editor.setEasingPreset(.easeOut)
        let easeOut = try #require(easingButtonFrame(editor), "no flare.inspector.easing on Ease Out")
        editor.moveEasingHandle(.first, to: Point(x: 0.25, y: 0.45))
        #expect(editor.currentEasingPreset == nil, "the drag left a preset")
        let custom = try #require(easingButtonFrame(editor), "no flare.inspector.easing on Custom")
        #expect(custom == easeOut, "Ease Out reads \(easeOut), Custom \(custom)")
    }

    /// The Easing button's accessibility frame, in a window as wide as Flare's inspector.
    private func easingButtonFrame(_ editor: FakeEasingEditing) -> CGRect? {
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let row = FlareTimingRow(editor: editor, onSelect: { _ in }, onPreset: { _ in }, onMoveHandle: { _, _ in }, onEndDrag: {})
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: FlareWindow.inspectorWidth, height: 200), styleMask: [.titled],
            backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: VStack { row }.frame(width: FlareWindow.inspectorWidth))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        func find(_ element: Any) -> CGRect? {
            let node = element as AnyObject
            if (node.accessibilityIdentifier?() ?? nil) == "flare.inspector.easing" { return node.accessibilityFrame?() }
            return ((node.accessibilityChildren?() ?? nil) ?? []).lazy.compactMap(find).first
        }
        return find(window)
    }
}
