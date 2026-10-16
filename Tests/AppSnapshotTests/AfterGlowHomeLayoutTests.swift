// AfterGlowHomeLayoutTests.swift: the home's layout spec (blueprint suite.md
// 7.3, HM-2b) at 880, 1000, 1280 and 1728 pt on `weekOfWork`. A 200 pt
// sidebar column beside HomeContent; the New row's tiles, the recents
// (whose first row is the RECENT header) and the sidebar report their frames
// through HomeLayoutAnchors, and the cards, drawn inside SuiteUI's
// ThumbnailGrid, through the hosted window's accessibility tree, as
// ThumbnailGridCellTests reads them. Also records afterglow-home-<width> in
// the four appearances (no baseline yet). homeFitsTheWindow keeps the New
// row, the recents and the running strip inside the window (#1752), and
// emptyStateFillsTheRecents centers the empty state (#1757). macOS only.
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import AfterGlowApp

@MainActor
@Suite struct AfterGlowHomeLayoutTests {
    nonisolated static let widths: [CGFloat] = [880, 1000, 1280, 1728]
    nonisolated static let height: CGFloat = 960
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func model(empty: Bool = false) async -> (HomeModel, SuiteServices) {
        let week = SuiteFixtures.store("weekOfWork", documents: "/fixture", now: now)?.recents ?? RecentsList()
        let services = empty ? SuiteServices.fake() : SuiteServices.fake(recents: week)
        let model = HomeModel(services: services, fileExists: { _ in true }, makeID: { "h1" })
        await model.reload(now: now)
        return (model, services)
    }

    /// The window at `width`: the sidebar column, then the home's content.
    private func home(_ model: HomeModel, _ services: SuiteServices, width: CGFloat,
                      height: CGFloat = AfterGlowHomeLayoutTests.height) -> some View {
        HStack(spacing: 0) {
            SuiteColor.panel.frame(width: CGFloat(HomeLayout.sidebar)).homeLayoutAnchor("sidebar")
            HomeContent(model: model, services: services, images: [:]).homeLayoutAnchor("content")
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    @Test(arguments: AfterGlowHomeLayoutTests.widths) func homeFollowsTheLayoutSpec(width: CGFloat) async {
        let (model, services) = await model()
        #expect(model.state.cards.count == 8)
        let (frames, cards) = measure(home(model, services, width: width), size: CGSize(width: width, height: Self.height))
        guard let sidebar = frames["sidebar"], let content = frames["content"], let tiles = frames["tiles"],
              let recents = frames["recents"] else {
            Issue.record("missing frames at \(width): \(frames.keys.sorted())")
            return
        }
        let margin = CGFloat(HomeLayout.margin)
        let left = content.minX + margin, right = content.maxX - margin
        #expect(abs(sidebar.width - 200) <= 0.5 && SuiteSize.sidebarWidth.ideal == 200)
        #expect(abs(tiles.minX - left) <= 0.5, "tiles at \(tiles.minX), content edge \(left)")
        #expect(abs(recents.minX - tiles.minX) <= 0.5, "RECENT at \(recents.minX), tiles at \(tiles.minX)")

        let apps = SuiteApp.apps.map(\.rawValue)
        let tileFrames = apps.compactMap { frames["tile.\($0)"] }
        #expect(tileFrames.count == 5)
        for tile in tileFrames { #expect(tile.maxX <= right + 0.5, "a tile ends at \(tile.maxX) past \(right)") }
        // #1755: one height and top for the five tiles, one top for their presets.
        if let first = tileFrames.first {
            for tile in tileFrames {
                #expect(abs(tile.minY - first.minY) <= 0.5 && abs(tile.height - first.height) <= 0.5,
                        "tile \(tile) against \(first) at \(width)")
            }
        }
        let presets = apps.compactMap { frames["chips.\($0)"] ?? frames["menu.\($0)"] }
        #expect(presets.count == 5)
        for preset in presets { #expect(abs(preset.minY - (presets.first?.minY ?? 0)) <= 0.5, "presets at \(preset.minY)") }
        // #1768: the Presets menu is a small control, no taller than a chip.
        for menu in apps.compactMap({ frames["menu.\($0)"] }) {
            #expect(menu.height <= SuiteSize.chip + 0.5, "menu \(menu.height) pt tall at \(width)")
        }
        let chips = width >= 1280
        #expect(apps.allSatisfy { (frames["chips.\($0)"] != nil) == chips && (frames["menu.\($0)"] != nil) == !chips },
                "chips expected: \(chips) at \(width)")

        #expect(cards.count == 8, "cards read: \(cards.count)")
        for card in cards { #expect(card.maxX <= right + 0.5, "a card ends at \(card.maxX) past \(right)") }
        for (i, a) in cards.enumerated() {
            for b in cards.dropFirst(i + 1) { #expect(!a.insetBy(dx: 0.5, dy: 0.5).intersects(b), "\(a) overlaps \(b)") }
        }
        // ThumbnailGrid's adaptive columns center each cell and pad the grid by
        // 12 pt, and HomeGrid sizes cards by thumbnailStep, not HomeLayout.cardWidth.
        withKnownIssue("cards off the 4 pt grid and the tiles' left edge (gap #1609)", isIntermittent: true) {
            let firstColumn = cards.map(\.minX).min() ?? left
            #expect(abs(firstColumn - left) <= 0.5, "first card column at \(firstColumn), tiles at \(left)")
            for card in cards {
                #expect(onGrid(card.minX) && onGrid(card.minY), "card origin \(card.origin) is off the 4 pt grid")
            }
        }
    }

    /// #1752: the tiles under the top margin, the running strip above the
    /// bottom, the recents between them, at every width and at 800x640.
    @Test(arguments: AfterGlowHomeLayoutTests.widths.map { CGSize(width: $0, height: AfterGlowHomeLayoutTests.height) }
          + [CGSize(width: 800, height: 640)])
    func homeFitsTheWindow(size: CGSize) async {
        let (model, services) = await model()
        let (frames, _) = measure(home(model, services, width: size.width, height: size.height), size: size)
        guard let sidebar = frames["sidebar"], let content = frames["content"], let tiles = frames["tiles"],
              let recents = frames["recents"], let running = frames["running"] else {
            Issue.record("missing frames at \(size): \(frames.keys.sorted())")
            return
        }
        let top = content.minY + CGFloat(HomeLayout.margin)
        #expect(abs(sidebar.minY) <= 0.5, "sidebar starts at \(sidebar.minY)")
        for app in SuiteApp.apps {
            let tile = frames["tile.\(app.rawValue)"]
            #expect((tile?.minY ?? -1) >= top - 0.5, "tile.\(app.rawValue) at \(String(describing: tile)) above \(top)")
        }
        #expect(running.maxY <= size.height + 0.5, "running ends at \(running.maxY) past \(size.height)")
        #expect(recents.minY >= tiles.maxY - 0.5 && recents.maxY <= running.minY + 0.5,
                "recents \(recents) not between tiles \(tiles) and running \(running)")
    }

    /// #1757: with no recents the empty state fills and centers in the recents.
    @Test func emptyStateFillsTheRecents() async {
        let (model, services) = await model(empty: true)
        let size = CGSize(width: 800, height: 640)
        let (frames, _) = measure(home(model, services, width: size.width, height: size.height), size: size)
        guard let empty = frames["empty"], let recents = frames["recents"] else {
            Issue.record("missing frames: \(frames.keys.sorted())")
            return
        }
        #expect(abs(empty.midX - recents.midX) <= 1, "empty at \(empty.midX), recents at \(recents.midX)")
        #expect(empty.width >= recents.width - 1, "empty \(empty.width) wide in \(recents.width)")
    }

    @Test func homeAtEachWidth() async {
        let (model, services) = await model()
        for width in Self.widths {
            for appearance in SnapshotAppearance.allCases {
                assertGolden(home(model, services, width: width), size: CGSize(width: width, height: Self.height),
                             name: "afterglow-home-\(Int(width))", area: "afterglow", appearance: appearance)
            }
        }
    }

    /// The named frames and the cards' frames, in the view's own top-left space.
    private func measure(_ view: some View, size: CGSize) -> ([String: CGRect], [CGRect]) {
        let seen = MeasuredHome()
        let measured = view
            .environment(\.suiteSnapshotRendering, true)
            .overlayPreferenceValue(HomeLayoutAnchors.self) { anchors in
                GeometryReader { proxy in
                    Color.clear.preference(key: ResolvedHomeFramesKey.self, value: anchors.mapValues { proxy[$0] })
                }
            }
            .onPreferenceChange(ResolvedHomeFramesKey.self) { frames in
                MainActor.assumeIsolated { seen.frames = frames }
            }
        let app = NSApplication.shared
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let host = NSHostingView(rootView: measured)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        host.layoutSubtreeIfNeeded()
        let cards = axNodes(in: host).compactMap { node -> CGRect? in
            guard ((node.accessibilityIdentifier?() ?? nil) ?? "").hasPrefix("afterglow.home.card."),
                  let screen = node.accessibilityFrame?() else { return nil }
            return host.convert(window.convertFromScreen(screen), from: nil)
        }
        return (seen.frames, cards)
    }
}

@MainActor private final class MeasuredHome {
    var frames: [String: CGRect] = [:]
}

/// HomeLayoutAnchors resolved in the measuring host's space.
private struct ResolvedHomeFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, next in next }
    }
}

/// Whether `value` sits on the 4 pt grid, within float noise.
private func onGrid(_ value: CGFloat) -> Bool { abs(value - (value / 4).rounded() * 4) <= 0.01 }

/// Every node under `element` in the accessibility tree, in tree order.
@MainActor private func axNodes(in element: Any) -> [AnyObject] {
    let node = element as AnyObject
    return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { axNodes(in: $0) }
}
