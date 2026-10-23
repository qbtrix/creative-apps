// DesignFillRowsTests.swift: the Fill section shows one colour control at a time. A solid layer shows its
// colour well (`design.fill`); a gradient layer shows SuiteUI's GradientEditor, whose stop row
// (`suite.gradient.color`) is its colour, and not the solid well, which would edit a colour the canvas no
// longer paints. Flare and Halo swap the two the same way. Hosts DesignInspector in a window tall enough
// for every row and reads its accessibility tree. macOS only.
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignFillRowsTests {
    /// The accessibility identifiers in the inspector with `id` selected on DesignGradientSeed's `cards`.
    private func identifiers(selecting id: String) -> Set<String> {
        let app = NSApplication.shared
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let inspector = DesignInspector(model: DesignGradientSeed.cards(selecting: id), perform: { _ in })
        let size = CGSize(width: 320, height: 2400)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        defer { window.orderOut(nil) }
        window.contentView = NSHostingView(rootView: inspector.frame(width: size.width, height: size.height))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return Set(axNodes(in: window).compactMap { $0.accessibilityIdentifier?() ?? nil })
    }

    @Test func aGradientLayerShowsTheEditorAndNotTheSolidWell() {
        let ids = identifiers(selecting: "node-2")
        #expect(ids.contains("suite.gradient.color"))
        #expect(!ids.contains("design.fill"), "the solid well edits a colour a gradient layer doesn't paint")
    }

    @Test func aSolidLayerShowsTheSolidWell() {
        let ids = identifiers(selecting: "node-3")
        #expect(ids.contains("design.fill"))
        #expect(!ids.contains("suite.gradient.color"))
    }
}

/// Every node under `element` in the accessibility tree, in tree order.
@MainActor private func axNodes(in element: Any) -> [AnyObject] {
    let node = element as AnyObject
    return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { axNodes(in: $0) }
}
