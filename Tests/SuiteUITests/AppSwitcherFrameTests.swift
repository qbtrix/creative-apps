// AppSwitcherFrameTests.swift: each switcher item's accessibility frame is
// its own step wide, the current one too. The current item's glass capsule is
// wider than the 80 pt step (90 pt), and drawn inside the button it widened
// that button's frame over both neighbours, which the app audit's overlap
// check failed on Library's Develop screen. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct AppSwitcherFrameTests {
    @Test func theCurrentItemsFrameStaysInItsStep() throws {
        let items = ["flare", "photo", "library", "halo"].map {
            AppSwitcherItem(id: $0, title: $0, app: nil, shortcut: "")
        }
        let spacing: CGFloat = 80
        #expect(AppSwitcher.capsuleWidth(spacing: spacing) > spacing, "the capsule no longer outgrows the step")
        let app = NSApplication.shared
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 120), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = NSHostingView(
            rootView: AppSwitcher(items: items, current: "photo", spacing: spacing, onSelect: { _ in }))
        window.orderFrontRegardless()
        defer { window.close() }
        var widths = [String: CGFloat]()
        _ = spinUntil {
            widths = Self.switcherWidths(in: window)
            return widths.count == items.count
        }
        try #require(widths.count == items.count, "found \(widths.keys.sorted())")
        for (id, width) in widths {
            #expect(abs(width - spacing) <= 1, "\(id) is \(width) pt wide at a \(spacing) pt step")
        }
    }

    /// The width of each `suite.switcher.<id>` element under `element` in the accessibility tree.
    private static func switcherWidths(in element: Any) -> [String: CGFloat] {
        let node = element as AnyObject
        var found = [String: CGFloat]()
        if let id = node.accessibilityIdentifier?() ?? nil, id.hasPrefix("suite.switcher.") {
            found[id] = node.accessibilityFrame?().width ?? 0
        }
        for child in (node.accessibilityChildren?() ?? nil) ?? [] {
            found.merge(switcherWidths(in: child)) { a, _ in a }
        }
        return found
    }
}
#endif
