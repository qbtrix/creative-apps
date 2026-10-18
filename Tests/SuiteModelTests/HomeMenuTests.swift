// HomeMenuTests.swift: what the launcher's File, Edit and View menus show
// (HomeMenu, HM-2c; blueprint suite.md 6.2): each item's title, whether it
// acts and the sentence that says why not.
import Foundation
import SuiteModel
import Testing

@Suite struct HomeMenuTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    func crowd() throws -> RecentsList {
        try #require(SuiteFixtures.store("crowd", documents: "/tmp/Documents", now: Self.now)).recents
    }

    func menu(_ recents: RecentsList = RecentsList(), selection: String? = nil, step: Int = 1,
              page: HomePage = .home, window: Bool = true, canUndo: Bool = false) -> HomeMenu {
        HomeMenu.make(recents: recents, selection: selection, thumbnailStep: step, page: page, hasWindow: window,
                      canUndoRemove: canUndo)
    }

    @Test func removeFromRecentsNeedsASelection() throws {
        let recents = try crowd()
        let none = menu(recents)
        #expect(none.delete == HomeMenu.Item("Remove from Recents", reason: "Select a recent item first."))
        let id = try #require(recents.items.first?.ref.fileID)
        #expect(menu(recents, selection: id).delete == HomeMenu.Item("Remove from Recents"))
        #expect(menu(recents, selection: "gone").delete.reason == "Select a recent item first.")
    }

    @Test func deleteRoutesByPage() throws {
        let recents = try crowd()
        let id = try #require(recents.items.first?.ref.fileID)
        let assets = menu(recents, selection: id, page: .assets).delete
        #expect(assets.title == "Remove Asset")
        #expect(assets.reason == SuiteIdentity.notConnected("shared-assets"))
    }

    @Test func openRecentListsTheTwentyNewest() throws {
        let recents = try crowd()
        let items = menu(recents).recents
        #expect(items.map(\.fileID) == recents.items.prefix(20).map(\.ref.fileID))
        #expect(items.map(\.item.title) == (0..<20).map { "Doc \($0).flare" })
        #expect(items.allSatisfy { $0.item.isEnabled })
        #expect(menu().recents.isEmpty)
    }

    @Test func clearMenuSaysWhyItWaits() throws {
        // RecentWork clears one app at a time and HomeModel has no clear yet.
        let clear = try menu(crowd()).clearMenu
        #expect(clear == HomeMenu.Item("Clear Menu", reason: SuiteIdentity.notConnected("recents-open-in")))
    }

    @Test func thumbnailSizesStopAtTheirEnds() {
        #expect(menu(step: 3).larger == HomeMenu.Item("Larger Thumbnails", reason: "Thumbnails are at their largest."))
        #expect(menu(step: 3).smaller.isEnabled)
        #expect(menu(step: 0).smaller == HomeMenu.Item("Smaller Thumbnails", reason: "Thumbnails are at their smallest."))
        #expect(menu(step: 0).larger.isEnabled)
        #expect(menu(step: 1).larger.isEnabled && menu(step: 1).smaller.isEnabled)
    }

    @Test func undoActsOnlyAfterARemove() {
        #expect(menu(canUndo: true).undo == HomeMenu.Item("Undo Remove from Recents"))
        #expect(menu().undo.reason == "Nothing to undo yet.")
    }

    @Test func newItemsCarryTheirPresets() {
        let new = menu().new
        #expect(new.map(\.item.title) == ["New Animation", "New Design", "New Image", "Import Photos…", "New Composition"])
        #expect(new.allSatisfy { $0.item.isEnabled && $0.preset?.app == $0.app })
        let tiles = SuiteCreating().tiles(missing: [.halo])
        let halo = HomeMenu.make(recents: RecentsList(), selection: nil, thumbnailStep: 1, page: .home, hasWindow: true,
                                 tiles: tiles).new.first { $0.app == .halo }
        #expect(halo?.item.reason == SuiteError.appMissing(.halo).message)
    }

    /// #1874: a tile with no presets gives the page's sentence in File > New, not a false "isn't available".
    @Test func emptyPresetNewItemSaysNoPresets() {
        let tile = NewTile(app: .design, title: "New Design", presets: [])
        let new = HomeMenu.make(recents: RecentsList(), selection: nil, thumbnailStep: 1, page: .home, hasWindow: true,
                                tiles: [tile]).new
        #expect(new.first?.item.reason == "No presets for New Design.")
        #expect(HomeMenu.newReason(tile) == "No presets for New Design.")
        let missing = NewTile(app: .design, title: "New Design", presets: [], disabledReason: "Gone.")
        #expect(HomeMenu.newReason(missing) == "Gone.")
        #expect(SuiteCreating().tiles(missing: []).allSatisfy { HomeMenu.newReason($0) == nil })
    }

    /// #1868: the presets menu names its tile's kind, not a bare "Presets".
    @Test func presetsTitleNamesTheTile() {
        let tiles = SuiteCreating().tiles(missing: [])
        #expect(tiles.first { $0.app == .flare }.map(HomeMenu.presetsTitle) == "Animation Presets")
        #expect(HomeMenu.presetsTitle(NewTile(app: .library, title: "Import Photos…", presets: [])) == "Import Photos Presets")
        #expect(tiles.allSatisfy { HomeMenu.presetsTitle($0) != "Presets" })
    }

    /// The menu's label: the kind's title where the tile holds it (1000 pt and up), a plain
    /// "Presets" in an 880 pt window's 112 pt tile, where the full title truncated to "Animation Pre…".
    @Test func presetsLabelFitsTheTile() throws {
        let flare = try #require(SuiteCreating().tiles(missing: []).first { $0.app == .flare })
        #expect(HomeMenu.presetsLabel(flare, windowWidth: 880) == "Presets")
        #expect(HomeMenu.presetsLabel(flare, windowWidth: 800) == "Presets")
        for width in [1000.0, 1280, 1728] {
            #expect(HomeMenu.presetsLabel(flare, windowWidth: width) == "Animation Presets", "at \(width)")
        }
    }

    @Test func openWaitsForRouting() {
        #expect(menu().open == HomeMenu.Item("Open…", reason: HomeMenu.openWaits))
        #expect(menu(window: false).open == HomeMenu.Item("Open…"))
    }

    /// #1754: Open…'s reason names opening a file, never "Opening recent work".
    @Test func openReasonNamesOpeningAFile() {
        let live = ["routing": SuiteIdentity.notConnected("recents-open-in"),
                    "sending": SuiteIdentity.notConnected("switching")]
        for pending in [[:], live, ["sending": SuiteIdentity.notConnected("switching")]] {
            #expect(HomeMenu.openReason(pending: pending) == "Opening files from AfterGlow isn't available yet.")
            #expect(HomeMenu.openReason(pending: pending) != SuiteIdentity.notConnected("recents-open-in"))
        }
        let open = HomeMenu.make(recents: RecentsList(), selection: nil, thumbnailStep: 1, page: .home,
                                 hasWindow: true, pending: live).open
        #expect(open.reason == HomeMenu.openWaits)
    }

    @Test func noWindowDisablesAllButNewAndOpen() throws {
        let recents = try crowd()
        let id = try #require(recents.items.first?.ref.fileID)
        let m = menu(recents, selection: id, window: false, canUndo: true)
        #expect(m.new.allSatisfy { $0.item.isEnabled })
        #expect(m.open.isEnabled)
        let rest = [m.clearMenu, m.undo, m.delete, m.showSidebar, m.showInspector, m.larger, m.smaller]
            + m.recents.map(\.item)
        #expect(rest.count == 27)
        for item in rest { #expect(item.reason == "Open the AfterGlow window first.", "\(item.title)") }
    }

    @Test func everyDisabledItemSaysWhy() throws {
        let m = try menu(crowd(), step: 3)
        let all = m.new.map(\.item) + [m.open, m.clearMenu, m.undo, m.delete, m.showSidebar, m.showInspector,
                                       m.larger, m.smaller] + m.recents.map(\.item)
        for item in all where !item.isEnabled { #expect(item.reason?.isEmpty == false, "\(item.title)") }
        #expect(!all.contains { $0.reason?.contains("Not connected yet") == true })
    }
}
