// LibraryCollectionsSeamTests.swift: MJ1, the seams filters-collections adds
// to the catalog (FC-2). With no filter and no collection of yours the
// catalog behaves as before; the stored filter and your collections reach
// `order`, the counts, `==` and the sidebar rows; every stub answers its
// `unavailable` text. Filters are set through @testable until FC-7.
import Testing
@testable import LibraryModel

@Suite struct LibraryCollectionsSeamTests {
    /// The shoot's `IMG_<n>` id.
    private func id(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

    private func catalog(_ fixture: String, sort: LibrarySort = .name) -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: fixture))
        catalog.setSort(sort)
        return catalog
    }

    private func keepers(_ ids: Set<String>) -> UserCollection {
        UserCollection(id: "user-1", name: "Keepers", contents: .photos(ids))
    }

    @Test func testSeamsWalk() {
        var shoot = catalog("shoot")
        #expect(shoot.order == shoot.items.sorted { LibrarySort.name.orders($0, before: $1) }.map(\.id))
        #expect(shoot.collections.map(\.count) == [24, 0, 20])
        #expect(shoot == catalog("shoot"))

        shoot.filter.hidesRejected = true
        shoot.refreshShown()
        shoot.select([id(4)])
        shoot.setFlag(.reject)
        #expect(!shoot.order.contains(id(4)))
        #expect(shoot.order.count == 23)
        #expect(shoot.collections.first?.count == 24)

        shoot.userCollections = [keepers([id(1), id(2), id(3)])]
        shoot.recount()
        #expect(shoot.collections.last == LibraryCollection(id: "user-1", name: "Keepers", count: 3))
        shoot.selectCollection("user-1")
        #expect(shoot.order == [id(1), id(2), id(3)])
        #expect(shoot.selectedUserCollection?.name == "Keepers")

        shoot.userCollections = []
        shoot.recount()
        #expect(shoot.selectedCollectionID == "all")
        #expect(shoot.collections.map(\.id) == ["all", "favorites", "recent"])
        #expect(shoot.order.count == 23)
    }

    @Test func samplesAreAsBeforeWithNoFilter() {
        let samples = catalog("samples", sort: .captureDate)
        let flagged = samples.items.filter(\.isFlagged).count
        #expect(samples.order == samples.items.sorted { LibrarySort.captureDate.orders($0, before: $1) }.map(\.id))
        #expect(samples.collections.map(\.count) == [samples.items.count, flagged, 20])
        #expect(samples.filterValue == "All photos; 60 of 60")
    }

    @Test func theFilterAndYourCollectionsTakePartInEquality() {
        let plain = catalog("shoot")
        var filtered = plain
        filtered.filter.hidesRejected = true
        var collected = plain
        collected.userCollections = [keepers([])]
        #expect(plain == catalog("shoot"))
        #expect(plain != filtered)
        #expect(plain != collected)
    }

    @Test func aFilterAppliesInEveryBuiltInCollection() {
        var shoot = catalog("shoot")
        shoot.select([id(1), id(2), id(3)])
        shoot.setFlag(.pick)
        shoot.select([id(2)])
        shoot.setRating(4)
        shoot.filter.rating = .atLeast(4)
        for collection in ["all", "favorites", "recent"] {
            shoot.selectCollection(collection)
            #expect(shoot.order == [id(2)], "in \(collection)")
        }
        #expect(shoot.collections.map(\.count) == [24, 3, 20])
        #expect(shoot.filterValue == "At least 4 stars; 1 of 20")
    }

    @Test func aFilterThatHidesTheLoupePhotoReturnsToTheGrid() {
        var shoot = catalog("shoot")
        shoot.select([id(4)])
        shoot.setFlag(.reject)
        shoot.open(id(4))
        shoot.filter.hidesRejected = true
        shoot.refreshShown()
        #expect(shoot.mode == .grid)
        #expect(shoot.focusedItemID == nil)
        shoot.filter.flags = [.pick]
        shoot.refreshShown()
        #expect(shoot.isHiddenByFilter)
        #expect(shoot.filterEmptyMessage == "No photos in All Photos match Picked, Rejects hidden.")
    }

    @Test func aSmartCollectionShowsAndCountsWhatItsRulesAdmit() {
        var shoot = catalog("shoot")
        shoot.select([id(1), id(2)])
        shoot.setRating(4)
        var rules = LibraryFilter.all
        rules.rating = .atLeast(4)
        shoot.userCollections = [UserCollection(id: "smart-1", name: "Fours", contents: .rules(rules))]
        shoot.recount()
        shoot.selectCollection("smart-1")
        #expect(shoot.activeFilter == rules)
        #expect(shoot.filterCaption == "Rules of Fours")
        #expect(shoot.order == [id(1), id(2)])
        shoot.select([id(1)])
        shoot.setRating(1)
        #expect(shoot.order == [id(2)])
        #expect(shoot.collections.last?.count == 1)
        shoot.selectCollection("all")
        shoot.select([id(3)])
        shoot.setRating(5)
        #expect(shoot.collections.last?.count == 2)
        #expect(shoot.filterCaption == nil)
    }

    @Test func yourCollectionsSayHowToFillThem() {
        let user = LibraryCollection(id: "user-1", name: "Keepers", count: 0)
        let smart = LibraryCollection(id: "smart-1", name: "Fours", count: 0)
        #expect(user.emptyMessage == "Select photos in All Photos, then choose Photo > Add to Collection or drag them here.")
        #expect(smart.emptyMessage == "Photos that match this collection's rules appear here. Change the rules in the filter bar.")
        #expect(smart.emptyActionTitle == "Show All Photos")
    }

    /// Your collections' edits are built (FC-9, LibraryCollectionsTests).
    @Test func everyStubAnswersItsUnavailableText() throws {
        var shoot = catalog("shoot")
        shoot.userCollections = [keepers([id(1)])]
        shoot.recount()
        let before = shoot
        #expect(shoot.newSmartCollectionHelp == UserCollection.smartUnavailable)
        #expect(shoot.collectionsSaveRequest() == nil)
        #expect(shoot.collectionsFileValue == "saved")
        #expect(shoot.newSmartCollection() == nil)
        shoot.didSaveCollections(revision: 1)
        shoot.failRestoreCollections(setAsideAs: "collections.json.bad")
        try shoot.restoreCollections(nil)
        #expect(shoot == before)
    }

    @Test func theBarHidesRejectsThroughItsToggle() {
        var shoot = catalog("shoot")
        shoot.select([id(4)])
        shoot.setFlag(.reject)
        shoot.toggleHideRejected()
        #expect(!shoot.order.contains(id(4)))
        #expect(shoot.filterValue == "Rejects hidden; 23 of 24")
        #expect(shoot.collectionsRevision == 1)
    }
}
