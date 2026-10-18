// InspectorSectionTests.swift: the identifier an InspectorSection's header
// carries, so journeys and the app audit find it (#262), and its Reset's
// place: hosted at 240 pt, Reset sits beside the header button with a hit
// area of at least iconButtonHit square and no overlap, and a section without
// `onReset` has no Reset (#285, #622; read from the window's accessibility
// tree, as KeyframeButtonTests does). macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@Test func sectionHeaderIdentifierIsTheTitleInLowerCaseHyphenated() {
    #expect(InspectorSection<EmptyView>.headerIdentifier("Metadata") == "suite.inspector.section.metadata")
    #expect(InspectorSection<EmptyView>.headerIdentifier("Tool Options") == "suite.inspector.section.tool-options")
    #expect(InspectorSection<EmptyView>.headerIdentifier("Hue/Saturation") == "suite.inspector.section.hue-saturation")
}

@Test func distinctSectionTitlesGetDistinctIdentifiers() {
    let titles = ["Composition", "Layers", "Layer", "Frame", "Fill", "Align"]
    #expect(Set(titles.map(InspectorSection<EmptyView>.headerIdentifier)).count == titles.count)
}

/// Reset is its own button beside the header button: at least iconButtonHit
/// square, and its frame never meets the header button's (#285: it sat over
/// the header, so a click meant for one could hit the other).
@MainActor @Test func resetSitsBesideTheHeaderWithAFullHitArea() throws {
    let id = InspectorSection<EmptyView>.headerIdentifier("Layer")
    let buttons = sectionButtons(onReset: {})
    let header = try #require(buttons.first { $0.id == id })
    let reset = try #require(buttons.first { $0.id == id + ".reset" })
    #expect(reset.frame.width >= SuiteSize.iconButtonHit && reset.frame.height >= SuiteSize.iconButtonHit)
    #expect(!reset.frame.intersects(header.frame))
    #expect(reset.frame.minX >= header.frame.maxX)
}

/// No `onReset`, no Reset: the icon shows only while it would change something.
@MainActor @Test func aSectionWithoutOnResetHasNoReset() {
    let id = InspectorSection<EmptyView>.headerIdentifier("Layer")
    let ids = sectionButtons(onReset: nil).map(\.id)
    #expect(ids.contains(id))
    #expect(!ids.contains(id + ".reset"))
}

/// The buttons of a "Layer" section hosted in a 240 pt wide window.
@MainActor private func sectionButtons(onReset: (@MainActor () -> Void)?) -> [(id: String, frame: CGRect)] {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let section = InspectorSection("Layer", onReset: onReset) { Text("Opacity") }
        .frame(width: 240, alignment: .topLeading)
    let host = NSHostingView(rootView: section)
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 240, height: 120), styleMask: [.titled], backing: .buffered,
        defer: false)
    window.contentView = host
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    return axButtons(in: window)
}
