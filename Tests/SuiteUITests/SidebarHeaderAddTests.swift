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
        ]
        _ = sections
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 208, height: 400), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: SuiteSidebarList(sections: sections, selection: nil, onSelect: { _ in }))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        spinUntil(timeout: 3) { axLabelledButtons(in: window)["New Scene"] != nil }
        print(axDump(window, 0))
        let frame = axLabelledButtons(in: window)["New Scene"]
        #expect(frame != nil, "no New Scene button in the sidebar's tree")
        if let frame { #expect(window.frame.contains(frame), "New Scene \(frame) is outside the sidebar \(window.frame)") }
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

@MainActor private func axDump(_ element: Any, _ depth: Int) -> String {
    let node = AXNode(object: element as! NSObject)
    var out = String(repeating: "  ", count: depth) + "\(node.role) '\(node.label)' \(node.frame) \(type(of: node.object))\n"
    guard depth < 16 else { return out }
    for child in node.children { out += axDump(child.object, depth + 1) }
    return out
}

/// Each labelled button's frame under `element`.
@MainActor private func axLabelledButtons(in element: Any, depth: Int = 0) -> [String: CGRect] {
    let node = AXNode(object: element as! NSObject)
    var found = [String: CGRect]()
    if node.role == NSAccessibility.Role.button.rawValue, !node.label.isEmpty { found[node.label] = node.frame }
    guard depth < 16 else { return found }
    for child in node.children { found.merge(axLabelledButtons(in: child.object, depth: depth + 1)) { $1 } }
    return found
}
