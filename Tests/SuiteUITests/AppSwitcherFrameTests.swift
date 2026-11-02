// AppSwitcherFrameTests.swift: the switcher's items, read from a hosted
// row's accessibility tree, sit side by side at every spacing step: the
// current item's capsule is wider than its slot, but it never widens the
// item's frame over a neighbour (#6011: the journeys' overlap audit failed on
// Home over Flare and Library over Halo by 5 pt at the 40 pt step). macOS only.
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@MainActor @Test(arguments: AppSwitcher.spacingSteps + [AppSwitcher.compactSpacing])
func switcherItemsNeverOverlap(spacing: CGFloat) {
    let state = AppSwitcherState.placeholder(processName: "FlareApp")
    let size = CGSize(width: 600, height: 80)
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: AppSwitcher(items: state.items, current: state.current, spacing: spacing) { _ in }
        .frame(width: size.width, height: size.height))
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    var frames: [(id: String, frame: CGRect)] = []
    _ = spinUntil {
        frames = switcherNodes(in: window)
        return frames.count == state.items.count
    }
    #expect(frames.count == state.items.count)
    let row = frames.sorted { $0.frame.minX < $1.frame.minX }
    for (a, b) in zip(row, row.dropFirst()) {
        #expect(a.frame.maxX - b.frame.minX <= 0.5, "\(a.id) overlaps \(b.id) by \(a.frame.maxX - b.frame.minX) pt at \(spacing)")
    }
}

/// Each `suite.switcher.<id>` item's accessibility frame.
@MainActor private func switcherNodes(in element: Any) -> [(id: String, frame: CGRect)] {
    let node = element as AnyObject
    let id = (node.accessibilityIdentifier?() ?? nil) ?? ""
    let mine = id.hasPrefix("suite.switcher.") ? [(id, node.accessibilityFrame?() ?? .zero)] : []
    return mine + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { switcherNodes(in: $0) }
}
