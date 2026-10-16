// LibraryLoupeGridButtonTests.swift: the loupe's visible way back to the grid.
// Escape and G were the only ways out, so a person who didn't know them was
// stuck. Hosts LibraryLoupe in a window and reads its accessibility tree (as
// SuiteUITests' ThumbnailGridCellTests does): a button `library.loupe.grid`
// is there, enabled, and pressing it calls `onGrid`. macOS only.
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryLoupeGridButtonTests {
    @Test func theGridButtonIsThereEnabledAndGoesBack() throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let photo = try #require(catalog.sortedItems.first)
        let pressed = Pressed()
        let window = host(LibraryLoupe(photo: photo, position: "1 of 60", onGrid: { pressed.count += 1 }))
        defer { window.orderOut(nil) }
        let button = axNodes(in: window).first { ($0.accessibilityIdentifier?() ?? nil) == "library.loupe.grid" }
        let found = try #require(button, "the loupe has no library.loupe.grid button")
        #expect(found.accessibilityRole?() == .button)
        #expect(found.isAccessibilityEnabled?() == true)
        #expect(found.accessibilityPerformPress?() == true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        #expect(pressed.count == 1)
    }
}

@MainActor private final class Pressed {
    var count = 0
}

@MainActor private func host(_ view: some View) -> NSWindow {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let size = CGSize(width: 900, height: 600)
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    return window
}

/// Every node under `element` in the accessibility tree, in tree order.
@MainActor private func axNodes(in element: Any) -> [AnyObject] {
    let node = element as AnyObject
    return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { axNodes(in: $0) }
}
