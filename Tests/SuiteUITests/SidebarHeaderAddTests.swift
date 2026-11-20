// SidebarHeaderAddTests.swift (#4831): a SuiteSidebarList section's add button, hosted in a window and read from
// its accessibility tree: a button labelled with the action's title, laid out inside the sidebar's bounds, so
// VoiceOver and the journeys reach New Scene as the mouse does. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct SidebarHeaderAddTests {
    @Test func theSectionsAddButtonIsAButtonInsideTheSidebar() {
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let sections = [
            SidebarSection(
                id: "scenes", title: "Scenes", items: [SidebarItem(id: "bounce", title: "Bounce", systemImage: "film")],
                addAction: ToolbarAction("New Scene", systemImage: "plus") {}),
            SidebarSection(id: "library", title: "Library", items: [SidebarItem(id: "all", title: "All", systemImage: "photo")]),
        ]
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 208, height: 400), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: SuiteSidebarList(sections: sections, selection: nil, onSelect: { _ in }))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        // The row also has its title as a heading, and the button sits inside the sidebar, left of its trailing edge.
        spinUntil(timeout: 3) { (axElements(in: window)["AXButton New Scene"]?.width ?? 0) > 0 }
        let found = axElements(in: window)
        let button = found["AXButton New Scene"]
        #expect(button != nil, "no New Scene button in the sidebar's tree: \(found.keys.sorted())")
        if let button {
            #expect(window.frame.insetBy(dx: 1, dy: 0).contains(button), "New Scene \(button) is outside \(window.frame)")
        }
        #expect(found["AXHeading Scenes"] != nil, "no Scenes heading: \(found.keys.sorted())")
        // A section with no add button keeps the List's own header.
        #expect(found["AXHeading Library"] != nil, "no Library heading: \(found.keys.sorted())")
    }
}

/// One accessibility node: AppKit's table parts answer the attribute API, SwiftUI's nodes the protocol methods.
@MainActor private struct AXNode {
    let object: NSObject
    private func attribute(_ name: NSAccessibility.Attribute) -> Any? { object.accessibilityAttributeValue(name) }
    var role: String { (object as AnyObject).accessibilityRole?()?.rawValue ?? (attribute(.role) as? String) ?? "?" }
    var label: String { ((object as AnyObject).accessibilityLabel?() ?? nil) ?? (attribute(.description) as? String) ?? "" }
    var frame: CGRect { (object as AnyObject).accessibilityFrame?() ?? .zero }
    var children: [AXNode] {
        let modern = ((object as AnyObject).accessibilityChildren?() ?? nil) ?? []
        let all = modern.isEmpty ? (attribute(.children) as? [Any]) ?? [] : modern
        return all.compactMap { ($0 as? NSObject).map(AXNode.init) }
    }
}

/// Each labelled element's frame under `element`, keyed "<role> <label>".
@MainActor private func axElements(in element: NSObject, depth: Int = 0) -> [String: CGRect] {
    let node = AXNode(object: element)
    var found = [String: CGRect]()
    if !node.label.isEmpty { found["\(node.role) \(node.label)"] = node.frame }
    guard depth < 16 else { return found }
    for child in node.children { found.merge(axElements(in: child.object, depth: depth + 1)) { $1 } }
    return found
}
