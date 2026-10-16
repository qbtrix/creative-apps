// ValuesHomeLayoutTests.swift: the home's column math matches blueprint
// section 7.3's table exactly, and every window width from 880 to 2560 keeps
// at least one column and cards of 168 to 240 pt on the 4 pt grid that fit.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct ValuesHomeLayoutTests {
    struct Row: Sendable { let width: Double, columns: Int, card: Double, tile: Double, chips: Bool }

    static let table: [Row] = [
        Row(width: 880, columns: 3, card: 200, tile: 112, chips: false),
        Row(width: 1000, columns: 4, card: 176, tile: 136, chips: false),
        Row(width: 1280, columns: 5, card: 192, tile: 192, chips: true),
        Row(width: 1728, columns: 8, card: 168, tile: 240, chips: true),
    ]

    @Test(arguments: table) func tableRow(_ row: Row) {
        #expect(HomeLayout.columns(windowWidth: row.width) == row.columns)
        #expect(HomeLayout.cardWidth(windowWidth: row.width) == row.card)
        #expect(HomeLayout.tileWidth(windowWidth: row.width) == row.tile)
        #expect(HomeLayout.tileShowsChips(windowWidth: row.width) == row.chips)
    }

    @Test func constants() {
        #expect(HomeLayout.sidebar == 200)
        #expect(HomeLayout.margin == 24)
        #expect(HomeLayout.gap == 16)
        #expect(HomeLayout.cardMin == 168)
        #expect(HomeLayout.cardMax == 240)
        #expect(HomeLayout.tileMax == 240)
        #expect(HomeLayout.tileChipsMin == 160)
    }

    @Test func sweepEveryWidthFits() {
        for w in stride(from: 880.0, through: 2560, by: 1) {
            let n = HomeLayout.columns(windowWidth: w)
            let card = HomeLayout.cardWidth(windowWidth: w)
            let content = w - HomeLayout.sidebar - 2 * HomeLayout.margin
            #expect(n >= 1, "columns at \(w)")
            #expect(card >= 168 && card <= 240, "card range at \(w)")
            #expect(card.truncatingRemainder(dividingBy: 4) == 0, "4 pt grid at \(w)")
            #expect(Double(n) * card + Double(n - 1) * HomeLayout.gap <= content, "row fits at \(w)")
            let tile = HomeLayout.tileWidth(windowWidth: w)
            #expect(tile.truncatingRemainder(dividingBy: 4) == 0 && tile <= 240, "tile at \(w)")
            #expect(5 * tile + 4 * HomeLayout.gap <= content, "tile row fits at \(w)")
        }
    }

    @Test func homeValuesHoldTheirParts() {
        let preset = NewDocumentPreset(id: "flare.vertical", app: .flare, title: "Vertical 9:16", detail: "1080 × 1920, 30 fps")
        let tile = NewTile(app: .flare, title: "New Animation", presets: [preset])
        #expect(tile.disabledReason == nil)
        let path = "/Users/me/Logo.design"
        let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                                   type: .designDocument, displayName: "Logo.design")
        let item = RecentItem(ref: ref, lastUsed: Date(timeIntervalSince1970: 0))
        let card = RecentCard(item: item, age: "Today", isMissing: false)
        let state = HomeState(tiles: [tile], cards: [card], running: [.design], emptyMessage: nil)
        #expect(state.cards.first?.age == "Today")
        #expect(state.cards.first?.item == item)
        #expect(state.tiles.first?.presets == [preset])
        #expect(state.running == [.design])
        #expect(state.emptyMessage == nil)
    }
}
