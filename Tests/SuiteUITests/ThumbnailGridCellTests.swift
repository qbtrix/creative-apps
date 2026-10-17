// ThumbnailGridCellTests.swift: ThumbnailGrid's per-cell surface for apps
// (#779): each cell reads as one accessibility element with `<prefix><id>`,
// the item's value and help, and its reject and unreadable marks; an AX
// press still selects through GridSelection; and `onVisibleChange` reports
// the cells on screen in display order. Read from a hosted window's
// accessibility tree, as KeyframeButtonTests does. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@Test func badgesAreNotDimmedUnlessAsked() {
    #expect(!ThumbnailBadges().dimmed)
    #expect(ThumbnailBadges(dimmed: true).dimmed)
}

/// One element per cell, so the id lands on the leaf (lesson 145), carrying
/// the value, the help, and a label that names each mark.
@MainActor @Test func eachCellReadsItsIdValueHelpAndMarks() {
    let items = [
        ThumbnailItem(id: "1", caption: "a.heic", accessibilityValue: "ready 3 stars", help: "a.heic, 256×171"),
        ThumbnailItem(id: "2", caption: "b.heic", badges: ThumbnailBadges(dimmed: true)),
        ThumbnailItem(id: "3", caption: "c.heic", help: "The file is missing.", isUnreadable: true),
    ]
    let window = host(ThumbnailGrid(
        items, cellSize: CGSize(width: 120, height: 90), selection: [], onSelectionChange: { _ in },
        cellIdentifierPrefix: "t.cell."), size: CGSize(width: 600, height: 300))
    defer { window.orderOut(nil) }
    let cells = axElements(in: window).filter { $0.id.hasPrefix("t.cell.") }
    #expect(cells.map(\.id) == ["t.cell.1", "t.cell.2", "t.cell.3"])
    #expect(cells.first?.value == "ready 3 stars")
    #expect(cells.first?.help == "a.heic, 256×171")
    #expect(cells.dropFirst().first?.label.contains("Rejected") == true)
    #expect(cells.dropFirst().first?.help == "b.heic")
    #expect(cells.last?.help == "The file is missing.")
    #expect(cells.last?.label.contains("Unreadable") == true)
}

/// Without a prefix no cell carries an id; the caption stays the tooltip.
@MainActor @Test func cellsHaveNoIdWithoutAPrefix() {
    let window = host(ThumbnailGrid(
        [ThumbnailItem(id: "1", caption: "a.heic")], cellSize: CGSize(width: 120, height: 90), selection: [],
        onSelectionChange: { _ in }), size: CGSize(width: 300, height: 200))
    defer { window.orderOut(nil) }
    let cell = axElements(in: window).first { $0.label.contains("a.heic") }
    #expect(cell?.id == "")
    #expect(cell?.help == "a.heic")
}

/// The new parameters leave selection alone: pressing a cell selects it.
@MainActor @Test func pressingAnIdentifiedCellSelectsIt() {
    let picked = Picked()
    let window = host(ThumbnailGrid(
        (1...3).map { ThumbnailItem(id: "\($0)", caption: "\($0).heic") }, cellSize: CGSize(width: 120, height: 90),
        selection: [], onSelectionChange: { picked.selection = $0 }, cellIdentifierPrefix: "t.cell."),
        size: CGSize(width: 600, height: 300))
    defer { window.orderOut(nil) }
    let cell = axNodes(in: window).first { ($0.accessibilityIdentifier?() ?? nil) == "t.cell.2" }
    #expect(cell?.accessibilityPerformPress?() == true)
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    #expect(picked.selection == ["2"])
}

/// A short window over many cells: the report is a display-order prefix of
/// the items, not all of them.
@MainActor @Test func visibleCellsAreReportedInDisplayOrder() {
    let picked = Picked()
    let order = (1...60).map { "\($0)" }
    let window = host(ThumbnailGrid(
        order.map { ThumbnailItem(id: $0, caption: "\($0).heic") }, cellSize: CGSize(width: 120, height: 90),
        selection: [], onSelectionChange: { _ in }, onVisibleChange: { picked.visible = $0 }),
        size: CGSize(width: 600, height: 300))
    defer { window.orderOut(nil) }
    #expect(!picked.visible.isEmpty)
    #expect(picked.visible.count < order.count)
    #expect(picked.visible == Array(order.prefix(picked.visible.count)))
}

@MainActor private final class Picked {
    var selection: Set<String> = []
    var visible: [String] = []
}

@MainActor private func host(_ view: some View, size: CGSize) -> NSWindow {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
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

@MainActor private func axElements(in element: Any) -> [(id: String, label: String, value: String?, help: String?)] {
    axNodes(in: element).map { node in
        let value: Any?? = node.accessibilityValue?()
        return ((node.accessibilityIdentifier?() ?? nil) ?? "", (node.accessibilityLabel?() ?? nil) ?? "",
                (value ?? nil) as? String, node.accessibilityHelp?() ?? nil)
    }
}
