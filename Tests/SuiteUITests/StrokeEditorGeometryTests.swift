// StrokeEditorGeometryTests.swift (stroke-style DK-a, #3867): StrokeEditor in an inspector-width Stroke section, read
// from a hosted window's accessibility tree. The Join, Cap and Dash chip groups share the Width row's leading and
// trailing edges, each group's chips sit on one line (Custom is never left alone under Solid), and Remove Stroke
// starts on its leading edge: no extra inset inside the section. It sets both AX attributes and waits (spinUntil) for
// every row it reads, so it passes run alone. macOS only.
import AppKit
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct StrokeEditorGeometryTests {
    @Test func chipsShareRowEdges() {
        let window = strokeWindow()
        defer { window.orderOut(nil) }
        let frames = strokeFrames(in: window)
        guard let width = frames["suite.stroke.width"], width.width > 0 else {
            Issue.record("no Width row in \(frames.keys.sorted())")
            return
        }
        for id in ["suite.stroke.join", "suite.stroke.cap", "suite.stroke.dash"] {
            guard let chips = frames[id] else {
                Issue.record("no \(id)")
                continue
            }
            #expect(abs(chips.minX - width.minX) <= 0.5, "\(id) starts at \(chips.minX), Width at \(width.minX)")
            #expect(abs(chips.maxX - width.maxX) <= 0.5, "\(id) ends at \(chips.maxX), Width at \(width.maxX)")
        }
        for group in ["join", "cap", "dash"] {
            let chips = frames.filter { $0.key.hasPrefix("suite.stroke.\(group).") }
            #expect(chips.count >= 3, "\(group) has \(chips.count) chips")
            let lines = Set(chips.values.map { $0.midY.rounded() })
            #expect(lines.count == 1, "\(group) chips wrap onto \(lines.count) lines: \(chips.mapValues(\.midY))")
        }
        if let remove = frames["suite.stroke.remove"] {
            #expect(abs(remove.minX - width.minX) <= 0.5, "Remove Stroke starts at \(remove.minX), Width at \(width.minX)")
        } else {
            Issue.record("no Remove Stroke")
        }
    }
}

@MainActor private func strokeWindow() -> NSWindow {
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let size = CGSize(width: SuiteSize.inspectorWidth.ideal, height: 640)
    let view = InspectorSection("Stroke") {
        StrokeEditor(stroke: VectorStroke(width: 2), help: nil, dashHelp: nil, showsTrim: false) { _ in }
    }
    .frame(width: size.width, height: size.height, alignment: .top)
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: view)
    window.orderFrontRegardless()
    spinUntil {
        let ids = strokeFrames(in: window).keys
        return ["width", "join", "cap", "dash", "remove"].allSatisfy { ids.contains("suite.stroke.\($0)") }
    }
    return window
}

/// The frame of every `suite.stroke.*` element under `element` in the accessibility tree (the first of each id).
@MainActor private func strokeFrames(in element: Any) -> [String: CGRect] {
    let node = element as AnyObject
    var found = [String: CGRect]()
    if let id = (node.accessibilityIdentifier?() ?? nil), id.hasPrefix("suite.stroke.") {
        found[id] = node.accessibilityFrame?() ?? .zero
    }
    for child in (node.accessibilityChildren?() ?? nil) ?? [] {
        found.merge(strokeFrames(in: child)) { first, _ in first }
    }
    return found
}
