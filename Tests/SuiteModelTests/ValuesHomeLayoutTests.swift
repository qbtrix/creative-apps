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
        Row(width: 1280, columns: 5, card: 192, tile: 192, chips: false),
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
        #expect(HomeLayout.tileChipsMin == 3 * HomeLayout.chipLabelMin + 2 * HomeLayout.chipSpacing)
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

    /// #1753: a chip shows only where every title fits untruncated; a third of a
    /// 192 pt tile is under the shortest label's width, so 1280 gets the menu.
    @Test func chipsOnlyWhereTheyFit() {
        let third = (HomeLayout.tileWidth(windowWidth: 1280) - 2 * HomeLayout.chipSpacing) / 3
        #expect(third < HomeLayout.chipLabelMin)
        #expect(!HomeLayout.tileShowsChips(windowWidth: 1280))
        for w in stride(from: 880.0, through: 2560, by: 8) {
            let chip = HomeLayout.chipWidth(windowWidth: w)
            #expect(HomeLayout.tileShowsChips(windowWidth: w) == (chip >= HomeLayout.chipLabelMin), "at \(w)")
        }
        let flare = SuiteCreating.presets[.flare] ?? []
        #expect(flare.count == 3)
        // "Vertical 9:16" needs more than a third of the widest tile.
        #expect(!HomeLayout.tileShowsChips(windowWidth: 1728, presets: flare))
        #expect(!HomeLayout.tileShowsChips(windowWidth: 2560, presets: flare))
        let short = [NewDocumentPreset(id: "a", app: .flare, title: "Square", detail: "1080 × 1080"),
                     NewDocumentPreset(id: "b", app: .flare, title: "HD", detail: "1920 × 1080")]
        #expect(HomeLayout.tileShowsChips(windowWidth: 1728, presets: short))
        #expect(!HomeLayout.tileShowsChips(windowWidth: 1280, presets: short))
        #expect(!HomeLayout.tileShowsChips(windowWidth: 1728, presets: Array(short.prefix(1))))
        #expect(HomeLayout.chipLabelWidth("Vertical 9:16") > HomeLayout.chipWidth(windowWidth: 1728))
        #expect(HomeLayout.chipLabelWidth("Square") <= HomeLayout.chipLabelMin)
    }

    /// #1753: a single preset is the tile's own click, so no preset row repeats it.
    @Test func singlePresetRowHides() {
        for tile in SuiteCreating().tiles(missing: []) {
            #expect(HomeLayout.showsPresets(tile) == (tile.presets.count > 1), "\(tile.app)")
        }
        #expect(HomeLayout.showsPresets(NewTile(app: .flare, title: "New Animation", presets: SuiteCreating.presets[.flare] ?? [])))
        #expect(!HomeLayout.showsPresets(NewTile(app: .design, title: "New Design", presets: SuiteCreating.presets[.design] ?? [])))
        #expect(!HomeLayout.showsPresets(NewTile(app: .photo, title: "New Image", presets: [])))
    }

    /// #1753: every preset control carries the preset's detail.
    @Test func presetHelpCarriesDetail() {
        for preset in SuiteCreating.presets.values.flatMap({ $0 }) {
            #expect(HomeLayout.presetHelp(preset) == "\(preset.title): \(preset.detail)")
        }
        let flare = SuiteCreating.presets[.flare] ?? []
        let joined = HomeLayout.presetsHelp(flare)
        for preset in flare { #expect(joined.contains(preset.detail) && joined.contains(preset.title)) }
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
