// ShapeToolOptionsTests.swift (shape-tools SH-3): the shape tool's options.
// Each kind shows its rows (Polygon Sides, Star Points and Inner ratio,
// Rectangle Corner radius, Arrow Head; Ellipse and Line none); a value typed
// past a row's range emits the clamped intent once and earns the help that
// names the range; each chip and row is identified `suite.shape.*` in a hosted
// window's accessibility tree. macOS only (SuiteUI).
import AppKit
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct ShapeToolOptionsTests {
    @Test func eachKindShowsItsRows() {
        let fields = { (kind: ShapeKind) in ShapeOptionRow.rows(kind).map(\.field) }
        #expect(fields(.polygon) == [.sides])
        #expect(fields(.star) == [.points, .innerRatio])
        #expect(fields(.rectangle) == [.cornerRadius])
        #expect(fields(.arrow) == [.head])
        #expect(fields(.ellipse).isEmpty && fields(.line).isEmpty)
        let star = ShapeOptionRow.rows(.star)
        #expect(star.map(\.title) == ["Points", "Inner ratio"])
        #expect(star.map { $0.value(.defaults(.star)) } == [5, 50])
        #expect(star.map(\.identifier) == ["suite.shape.points", "suite.shape.inner-ratio"])
        #expect(ShapeOptionRow.points.range == 3...64 && ShapeOptionRow.innerRatio.range == 10...100)
        #expect(ShapeOptionRow.cornerRadius.range == 0...500 && ShapeOptionRow.head.range == 2...200)
    }

    @Test func aRowSendsItsIntent() {
        #expect(ShapeOptionRow.innerRatio.intent(25) == .innerRatio(0.25))
        #expect(ShapeOptionRow.points.intent(8) == .points(8))
        #expect(ShapeOptionRow.head.intent(30) == .head(30))
        let change = ShapeToolOptions.change(.points, typed: 8, spec: .defaults(.star))
        #expect(change.intent == .points(8) && change.help == nil)
    }

    @Test func twoSidesClampToThreeWithHelp() throws {
        let change = ShapeToolOptions.change(.sides, typed: 2, spec: .defaults(.polygon))
        #expect(change.intent == .sides(3))
        let help = try #require(change.help, "a typed 2 in Sides showed no help")
        #expect(help.contains("3") && help.contains("64"), "the help \(help) doesn't name the range")
        // Already at 3: the clamp changes nothing, so no intent is sent twice, but the help still shows.
        var three = ShapeSpec.defaults(.polygon)
        three.sides = 3
        let again = ShapeToolOptions.change(.sides, typed: 2, spec: three)
        #expect(again.intent == nil && again.help != nil)
        // A value typed past the top clamps to it.
        #expect(ShapeToolOptions.change(.cornerRadius, typed: 501, spec: .defaults(.rectangle)).intent == .cornerRadius(500))
    }

    @Test func eachChipSendsOneKind() {
        #expect(ShapeToolOptions.kinds.map(\.id) == ShapeKind.allCases)
        #expect(ShapeToolOptions.kinds.map(\.identifier) == ShapeKind.allCases.map { "suite.shape.chip-\($0.rawValue)" })
        #expect(ShapeToolOptions.kinds.map(\.title) == ["Rectangle", "Ellipse", "Polygon", "Star", "Line", "Arrow"])
    }

    @Test func chipsAndRowsAreIdentified() {
        let window = shapeWindow(ShapeToolOptions(spec: .defaults(.star), help: nil) { _ in })
        defer { window.orderOut(nil) }
        let ids = Set(shapeNodes(in: window).compactMap { $0.accessibilityIdentifier?() ?? nil })
        for kind in ShapeKind.allCases { #expect(ids.contains("suite.shape.chip-\(kind.rawValue)"), "no chip for \(kind)") }
        #expect(ids.isSuperset(of: ["suite.shape.points", "suite.shape.inner-ratio"]), "the star's rows are missing: \(ids)")
        #expect(!ids.contains("suite.shape.sides"), "a star shows Sides")
    }

    @Test func aRefusalShowsItsHelp() {
        let window = shapeWindow(ShapeToolOptions(
            spec: .defaults(.polygon), help: nil, refused: (.sides, "Type a number from 3 to 64")) { _ in })
        defer { window.orderOut(nil) }
        let ids = shapeNodes(in: window).compactMap { $0.accessibilityIdentifier?() ?? nil }
        #expect(ids.contains("suite.shape.help"), "the refused Sides shows no help")
    }
}

@MainActor private func shapeWindow(_ view: some View) -> NSWindow {
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 320, height: 480), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: view.frame(width: 320, height: 480))
    window.orderFrontRegardless()
    spinUntil {
        shapeNodes(in: window).contains { ($0.accessibilityIdentifier?() ?? nil) == "suite.shape.chip-rectangle" }
    }
    return window
}

/// Every node under `element` in the accessibility tree.
@MainActor private func shapeNodes(in element: Any) -> [AnyObject] {
    let node = element as AnyObject
    return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { shapeNodes(in: $0) }
}
