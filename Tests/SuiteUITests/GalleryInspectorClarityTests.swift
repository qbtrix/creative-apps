// GalleryInspectorClarityTests.swift: first-use clarity on the gallery's
// inspector pages (#2951, #2955). StudioScrubRow carries a unit, so the
// curves page's Duration reads "0.50 s" and speaks "0.5 s"; the Onion chip's
// tooltip says what onion skin does instead of repeating "Onion", and the Cap
// picker's says it is the line cap. Read from a hosted window's accessibility
// tree, as ScrubAccessibilityTests does. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct GalleryInspectorClarityTests {
    @Test func aStudioRowShowsAndSpeaksItsUnit() throws {
        #expect(NumericInput.text(0.5, decimals: 2, unit: "s") == "0.50 s")
        let window = clarityWindow(StudioScrubRow(
            label: "Duration", value: 0.5, range: 0...10, step: 0.1, unit: "s", onChange: { _ in }))
        defer { window.orderOut(nil) }
        let slider = try #require(clarityNodes(in: window).first { $0.accessibilityRole?() == NSAccessibility.Role.slider })
        #expect((slider as? NSObject)?.value(forKey: "accessibilityValueDescription") as? String == "0.5 s")
    }

    @Test func theCurvesPageDurationIsInSeconds() throws {
        let page = try #require(GalleryInspector.pages["curves"])
        let window = clarityWindow(page())
        defer { window.orderOut(nil) }
        let duration = clarityNodes(in: window).filter {
            ($0.accessibilityIdentifier?() ?? nil) == "suite.gallery.curves.duration"
        }
        let spoken = duration.compactMap { ($0 as? NSObject)?.value(forKey: "accessibilityValueDescription") as? String }
        #expect(spoken.contains("0.5 s"), "Duration speaks \(spoken)")
    }

    @Test func theOnionChipAndCapPickerSayWhatTheyAre() throws {
        #expect(GalleryInspector.onionHelp != "Onion" && GalleryInspector.onionHelp.contains("frames"))
        #expect(GalleryInspector.capHelp.contains("stroke ends"))
        let page = try #require(GalleryInspector.pages["inspector"])
        let window = clarityWindow(page())
        defer { window.orderOut(nil) }
        let nodes = clarityNodes(in: window)
        let help = { (id: String) in
            nodes.filter { ($0.accessibilityIdentifier?() ?? nil) == id }.compactMap { $0.accessibilityHelp?() ?? nil }
        }
        #expect(help("suite.gallery.inspector.chip-onion").contains(GalleryInspector.onionHelp))
        #expect(help("suite.gallery.inspector.cap").contains(GalleryInspector.capHelp))
    }
}

@MainActor private func clarityWindow(_ view: some View) -> NSWindow {
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 360, height: 1200), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: view.frame(width: 360, height: 1200))
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    return window
}

/// Every node under `element` in the accessibility tree, in tree order.
@MainActor private func clarityNodes(in element: Any) -> [AnyObject] {
    let node = element as AnyObject
    return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { clarityNodes(in: $0) }
}
