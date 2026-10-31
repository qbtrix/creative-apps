// ColorRowReturnTests.swift: Return in a color row's hex field commits the color and gives the keys back, so the
// next ⌘Z reaches the editor's undo, not the field's typing (#5928: Flare's FILL hex took FF8000 on Return and
// ⌘Z left it orange, because the field editor still had the keys and the Edit menu gave way to it). The row is
// hosted in an off-screen window; the test types through the field editor and sends it Return, no real events.
// macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor @Suite struct ColorRowReturnTests {
    private final class KeyWindow: NSWindow {
        override var canBecomeKey: Bool { true }
    }

    @MainActor private final class Heard {
        var picked: [HexColor] = []
        var ends = 0
    }

    private static func fields(in view: NSView) -> [NSTextField] {
        (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
    }

    @Test func returnCommitsTheHexAndGivesTheKeysBack() async throws {
        let heard = Heard()
        let row = InspectorColorWellRow(
            "Fill", color: HexColor(0, 0, 0), sampleable: false,
            onChange: { heard.picked.append($0) }, onEnd: { heard.ends += 1 })
        let host = NSHostingView(rootView: row.frame(width: 320))
        let window = KeyWindow(
            contentRect: CGRect(x: -20_000, y: -20_000, width: 320, height: 60), styleMask: [.borderless],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(200))

        let field = try #require(Self.fields(in: host).first { $0.isEditable }, "the row has no hex field")
        window.makeKey()
        window.makeFirstResponder(field)
        try await Task.sleep(for: .milliseconds(100))
        let editor = try #require(window.firstResponder as? NSTextView, "the hex field took no field editor")
        editor.selectAll(nil)
        editor.insertText("FF8000", replacementRange: editor.selectedRange())
        editor.insertNewline(nil)
        try await Task.sleep(for: .milliseconds(200))

        #expect(heard.picked == [HexColor(0xFF, 0x80, 0x00)], "Return committed \(heard.picked)")
        #expect(heard.ends == 1, "Return ended \(heard.ends) gestures")
        #expect(!(window.firstResponder is NSText), "after Return the hex field still has the keys, so ⌘Z undoes its typing")
    }
}
#endif
