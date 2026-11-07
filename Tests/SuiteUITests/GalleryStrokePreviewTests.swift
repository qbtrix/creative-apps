// GalleryStrokePreviewTests.swift (stroke-style SS-a, finding #3881): the gallery's `stroke-editor` page, hosted in a
// window and read from its accessibility tree the way SuiteStrokeJourneyTests reads it. The preview
// (`suite.gallery.stroke-editor.preview`) reports the page's stroke as its AXValue, "2 pt miter butt" to start, so the
// journey can see the width, join and cap the editor set. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct GalleryStrokePreviewTests {
    @Test func thePreviewReportsTheStartingStroke() {
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1000, height: 700), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: GalleryStrokeEditorPage())
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        let id = "suite.gallery.stroke-editor.preview"
        _ = spinUntil { !previewValues(id, in: window).isEmpty }
        let values = previewValues(id, in: window)
        #expect(!values.isEmpty, "no \(id) in the page's accessibility tree")
        #expect(values.allSatisfy { $0 == "2 pt miter butt" }, "the preview reads \(values)")
    }
}

/// The value of every element called `id` under `element`, "" for one with no string value.
@MainActor private func previewValues(_ id: String, in element: Any) -> [String] {
    let node = element as AnyObject
    var found = [String]()
    // AXValue, what XCUIElement.value reads: a value sent only as the value description doesn't count.
    if (node.accessibilityIdentifier?() ?? nil) == id {
        found.append((node as? NSObject)?.value(forKey: "accessibilityValue") as? String ?? "")
    }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] { found += previewValues(id, in: child) }
    return found
}
