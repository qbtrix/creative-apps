import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Test func zzDumpSidebarTree() {
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let scenes = SidebarSection(
        id: "scenes", title: "Scenes", items: [SidebarItem(id: "s1", title: "Scene 1", systemImage: "film")],
        addAction: ToolbarAction("New Scene", systemImage: "plus") {})
    let host = NSHostingView(rootView: SuiteSidebarList(sections: [scenes], selection: nil, onSelect: { _ in })
        .frame(width: 240, height: 200))
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 240, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = host
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    _ = spinUntil(timeout: 2) { false }
    func dump(_ e: Any, _ d: Int) {
        guard let n = e as? NSObject else { return }
        func a(_ k: String) -> Any? { n.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: k)) }
        print("AXDUMP" + String(repeating: "  ", count: d), a("AXRole") ?? "-", a("AXDescription") ?? "", a("AXTitle") ?? "", a("AXIdentifier") ?? "", type(of: n))
        for c in (a("AXChildren") as? [Any]) ?? [] { dump(c, d + 1) }
    }
    dump(window, 0)
}
