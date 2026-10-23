// SuiteGridSnapshots.swift: SuiteUI's ThumbnailGrid over sample data, a mix
// of placeholder cells (no image) and colored cells with badges, unselected
// and with three cells selected, in Light and Dark, plus a row of blue and teal
// photos with two selected (issue #101: the selection must read on them).
// Writes suiteui-grid-{light,dark}.png, suiteui-grid-selected-{light,dark}.png
// and suiteui-grid-selected-blue-{light,dark}.png. Each cell is registered
// as `suite.grid.<id>`. The grid golden (Golden/lists/grid-*.png, four
// appearances) and the LL-12 checks that the grid's click path goes through
// its GridSelecting rule and gives SJ18's selections. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteGridSnapshots {
    @Test func grid() throws {
        let items = Self.sampleItems()
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(GridSample(items: items, selection: []), name: "suiteui-grid-\(suffix)", scheme: scheme)
            try snapshot(
                GridSample(items: items, selection: ["2", "3", "8"]), name: "suiteui-grid-selected-\(suffix)", scheme: scheme)
            try snapshot(
                GridSample(items: Self.blueItems(), selection: ["blue", "teal"]),
                name: "suiteui-grid-selected-blue-\(suffix)", scheme: scheme)
        }
    }

    @Test func gridGolden() {
        let sample = GridSample(items: Array(Self.sampleItems().prefix(6)), selection: ["2", "3"])
        for appearance in SnapshotAppearance.allCases {
            assertGolden(sample, size: CGSize(width: 720, height: 420), name: "grid", area: "lists", appearance: appearance)
        }
    }

    /// SJ18 through the grid's click path: click 3, Shift-click 6, Command-click 4.
    @Test func clickPathGivesSJ18Selections() {
        let order = (1...12).map { "\($0)" }
        let spy = GridRuleSpy()
        var pick = GridPick<String>()
        var seen: [Set<String>] = []
        let steps: [(String, ClickKind)] = [("3", .plain), ("6", .extend), ("4", .toggle)]
        for (id, kind) in steps {
            pick = ThumbnailGrid<String>.picked(id, kind, selection: pick.selection, anchor: pick.anchor, order: order, rule: spy)
            seen.append(pick.selection)
        }
        #expect(seen == [["3"], ["3", "4", "5", "6"], ["3", "5", "6"]])
        #expect(spy.calls == ["plain 3", "extend 6", "toggle 4"])
    }

    /// A press on a hosted cell reaches the rule the grid was given, so a grid
    /// that called GridSelection itself fails here.
    @Test func pressingACellCallsTheRule() {
        let spy = GridRuleSpy()
        let grid = ThumbnailGrid(
            (1...4).map { ThumbnailItem(id: "\($0)", caption: "\($0).heic") }, cellSize: CGSize(width: 120, height: 90),
            selection: [], onSelectionChange: { _ in }, cellIdentifierPrefix: "suite.grid.", selecting: spy)
        let app = NSApplication.shared
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: grid.frame(width: 600, height: 300))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let cell = Self.nodes(in: window).first { ($0.accessibilityIdentifier?() ?? nil) == "suite.grid.3" }
        #expect(cell?.accessibilityPerformPress?() == true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        #expect(spy.calls == ["plain 3"])
    }

    private static func nodes(in element: Any) -> [AnyObject] {
        let node = element as AnyObject
        return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { nodes(in: $0) }
    }

    /// Sky and sea: a selected blue and teal photo beside an unselected blue
    /// one, so a selection that blends into the image shows.
    private static func blueItems() -> [ThumbnailItem<String>] {
        [("blue", [Color.blue, .blue]), ("teal", [.teal, .teal]), ("sky", [.blue, .cyan])].map { id, colors in
            ThumbnailItem(id: id, image: swatch(colors), caption: "\(id).heic")
        }
    }

    /// Twelve cells: every third has no image, the rest are gradients.
    private static func sampleItems() -> [ThumbnailItem<String>] {
        var palette = [[Color.orange, .pink], [.teal, .blue], [.yellow, .green], [.indigo, .purple],
                       [.red, .orange], [.mint, .cyan], [.brown, .yellow], [.blue, .indigo]].makeIterator()
        return (1...12).map { index in
            let image = index % 3 == 0 ? nil : palette.next().flatMap(swatch)
            let badges = ThumbnailBadges(
                rating: index % 6, isFlagged: index % 4 == 1,
                colorLabel: index % 5 == 2 ? (name: "Red", color: .red) : nil)
            return ThumbnailItem(id: "\(index)", image: image, caption: "IMG_\(4800 + index).heic", badges: badges)
        }
    }

    private static func swatch(_ colors: [Color]) -> Image? {
        let renderer = ImageRenderer(
            content: LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 320, height: 240))
        return renderer.cgImage.map { Image(decorative: $0, scale: 1) }
    }
}

private struct GridSample: View {
    let items: [ThumbnailItem<String>]
    let selection: Set<String>

    var body: some View {
        ThumbnailGrid(
            items, cellSize: CGSize(width: 200, height: 150), selection: selection, onSelectionChange: { _ in },
            cellIdentifierPrefix: "suite.grid.")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The live rule with a log of every click it was asked for.
private final class GridRuleSpy: GridSelecting, @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String] = []
    private let rule = SuiteGridSelecting()

    var calls: [String] { lock.withLock { log } }

    func click<ID: Hashable & Sendable>(_ id: ID, _ kind: ClickKind, current: GridPick<ID>, order: [ID]) -> GridPick<ID> {
        lock.withLock { log.append("\(kind) \(id)") }
        return rule.click(id, kind, current: current, order: order)
    }

    func move<ID: Hashable & Sendable>(
        _ arrow: GridArrow, extend: Bool, current: GridPick<ID>, order: [ID], columns: Int
    ) -> GridPick<ID> {
        rule.move(arrow, extend: extend, current: current, order: order, columns: columns)
    }

    func columns(width: Double, minimum: Double, spacing: Double) -> Int {
        rule.columns(width: width, minimum: minimum, spacing: spacing)
    }
}
