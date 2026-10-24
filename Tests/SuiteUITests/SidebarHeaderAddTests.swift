// SidebarHeaderAddTests.swift (needs-ui #4831): a SuiteSidebarList section header's add button, hosted in a window
// and read from its accessibility tree. Inside the List's section header the button is its own button element,
// labelled with the action's title and identified by the action's identifier, or `suite.sidebar.add.<section id>`
// when the action has none, so VoiceOver and the journeys reach New Scene as the mouse does. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct SidebarHeaderAddTests {
    @Test func theHeadersAddButtonIsAButtonWithItsTitleAndIdentifier() {
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let sections = [
            SidebarSection(
                id: "scenes", title: "Scenes", items: [SidebarItem(id: "bounce", title: "Bounce", systemImage: "film")],
                addAction: ToolbarAction("New Scene", systemImage: "plus") {}),
            SidebarSection(
                id: "comps", title: "Compositions", items: [SidebarItem(id: "c1", title: "Comp 1", systemImage: "film")],
                addAction: ToolbarAction("New Composition…", systemImage: "plus", identifier: "halo.composition.new") {}),
        ]
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 260, height: 400), styleMask: [.titled],
                              backing: .buffered, defer: false)
        let list = SuiteSidebarList(sections: sections, selection: nil, onSelect: { _ in }).listStyle(.sidebar)
        window.contentView = NSHostingView(rootView: list)
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        let wanted = ["suite.sidebar.add.scenes", "halo.composition.new"]
        spinUntil { Set(axButtons(in: window).map(\.id)).isSuperset(of: wanted) }
        let ids = axButtons(in: window).map(\.id)
        for id in wanted { #expect(ids.contains(id), "no \(id) button in the sidebar's tree: \(ids)") }
        let labels = axButtonLabels(in: window)
        #expect(labels["suite.sidebar.add.scenes"] == "New Scene")
        #expect(labels["halo.composition.new"] == "New Composition…")
    }
}

/// Each identified button's label under `element`.
@MainActor private func axButtonLabels(in element: Any) -> [String: String] {
    let node = element as AnyObject
    var found = [String: String]()
    if node.accessibilityRole?() == .button, let id = node.accessibilityIdentifier?() ?? nil, !id.isEmpty {
        found[id] = node.accessibilityLabel?() ?? ""
    }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] { found.merge(axButtonLabels(in: child)) { $1 } }
    return found
}
