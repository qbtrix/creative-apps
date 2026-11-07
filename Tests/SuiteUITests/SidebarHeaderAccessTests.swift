// SidebarHeaderAccessTests.swift: a SuiteSidebarList section header's add
// button is its own accessibility element (#4831): a button labelled with the
// action's title and identified `suite.sidebar.add.<section id>`, reachable
// inside the List's section header, so VoiceOver and Flare's J16 journey
// (New Scene) find it. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Test func aSectionHeadersAddButtonIsItsOwnAccessibilityElement() {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let scenes = SidebarSection(
        id: "scenes", title: "Scenes", items: [SidebarItem(id: "s1", title: "Scene 1", systemImage: "film")],
        addAction: ToolbarAction("New Scene", systemImage: "plus") {})
    let host = NSHostingView(rootView: SuiteSidebarList(sections: [scenes], selection: nil, onSelect: { _ in })
        .frame(width: 240, height: 200))
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 240, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = host
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    _ = spinUntil { axLabelledButtons(in: window).contains { $0.label == "New Scene" } }
    let buttons = axLabelledButtons(in: window)
    #expect(buttons.contains { $0.label == "New Scene" && $0.id == "suite.sidebar.add.scenes" }, "buttons: \(buttons)")
}

/// Every button under `element` in the accessibility tree, with its label and identifier.
@MainActor private func axLabelledButtons(in element: Any) -> [(label: String, id: String)] {
    let node = element as AnyObject
    var found = [(label: String, id: String)]()
    if node.accessibilityRole?() == .button {
        found.append(((node.accessibilityLabel?() ?? nil) ?? "", (node.accessibilityIdentifier?() ?? nil) ?? ""))
    }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] { found += axLabelledButtons(in: child) }
    return found
}
