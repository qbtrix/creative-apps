// LibraryCollectionsTests.swift: the collections you make (FC-9, slice FC-c).
// New Collection holds the cull targets, takes the next free name and id
// (max n + 1) and is selected; Add refuses smart and built-in targets and a
// collection that holds them all; Remove works only in one you made; Delete
// never touches `items`; Rename trims and refuses empty names and built-ins.
// Each command is one named step undo reverts exactly. Written before its
// code (lead.md, contract rule 13, FC-8); FC-9 removes the `.disabled`.
import Testing
@testable import LibraryModel

@Suite struct LibraryCollectionsTests {
    /// The shoot's `IMG_<n>` id.
    private func id(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

    /// The shoot by name, with `made` as your collections.
    private func shoot(_ made: [UserCollection] = []) -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        catalog.userCollections = made
        catalog.recount()
        return catalog
    }
    /// The shoot with Keepers (user-1: IMG_0001…0003) and a smart collection.
    private func withKeepers() -> LibraryCatalog {
        shoot([UserCollection(id: "user-1", name: "Keepers", contents: .photos([id(1), id(2), id(3)])),
               UserCollection(id: "smart-1", name: "Four Stars", contents: .rules(LibraryFilter(rating: .atLeast(4))))])
    }
    /// What a collections step changes, to compare before and after undo.
    private func state(_ c: LibraryCatalog) -> [String] {
        [c.userCollections.map { "\($0.id)=\($0.name):\($0.contents)" }.joined(separator: ","),
         c.collections.map { "\($0.id)=\($0.name):\($0.count)" }.joined(separator: ","),
         c.selectedCollectionID, c.order.joined(separator: ",")]
    }
    private func count(_ id: String, _ c: LibraryCatalog) -> Int? { c.collections.first { $0.id == id }?.count }

    @Test(.disabled("waits on FC-9")) func newCollectionHoldsTheSelectionAndIsOneStep() {
        var catalog = shoot()
        catalog.select([id(1), id(2), id(3)])
        let before = state(catalog)
        let steps = catalog.history.undo.count
        let made = catalog.newCollection()
        #expect(made == "user-1" && catalog.selectedCollectionID == made)
        #expect(catalog.collections.last == LibraryCollection(id: made, name: "Untitled Collection", count: 3))
        #expect(catalog.selectedUserCollection?.contents == .photos([id(1), id(2), id(3)]))
        #expect(catalog.order == [id(1), id(2), id(3)])
        #expect(catalog.history.undo.count == steps + 1 && catalog.undoTitle == "Undo New Collection")
        catalog.undo()
        #expect(state(catalog) == before)
        catalog.redo()
        catalog.selectCollection("all")
        catalog.select([id(4)])
        catalog.newCollection()
        #expect(catalog.selectedUserCollection?.name == "Untitled Collection 2")
    }

    @Test(.disabled("waits on FC-9")) func newCollectionWithNoneSelectedIsEmpty() {
        var catalog = shoot()
        catalog.select([])
        let made = catalog.newCollection()
        #expect(catalog.selectedCollectionID == made)
        #expect(catalog.selectedUserCollection?.contents == .photos([]))
        #expect(count(made, catalog) == 0 && catalog.order.isEmpty && catalog.isSelectedCollectionEmpty)
    }

    @Test(.disabled("waits on FC-9")) func idsAreNeverReusedWhileOneExists() {
        var catalog = shoot([UserCollection(id: "user-1", name: "A", contents: .photos([])),
                             UserCollection(id: "user-3", name: "B", contents: .photos([]))])
        #expect(catalog.newCollection() == "user-4")  // max n + 1, not count + 1
        catalog.deleteCollection("user-1")
        #expect(catalog.newCollection() == "user-5")
    }

    @Test(.disabled("waits on FC-9")) func addRefusesSmartAndBuiltInTargets() {
        var catalog = withKeepers()
        catalog.select([id(10)])
        let before = state(catalog)
        for target in ["smart-1", "all", "favorites", "recent"] {
            #expect(catalog.addToCollectionHelp(target) != nil, "\(target) takes photos")
            catalog.addToCollection(target)
            #expect(state(catalog) == before, "\(target) changed")
        }
        #expect(catalog.addToCollectionHelp("user-1") == nil)
    }

    @Test(.disabled("waits on FC-9")) func addIsOneStepAndRefusesWhenAllAreIn() {
        var catalog = withKeepers()
        catalog.select([id(10)])
        let before = state(catalog)
        catalog.addToCollection("user-1")
        #expect(count("user-1", catalog) == 4 && catalog.undoTitle == "Undo Add to Collection")
        #expect(catalog.addToCollectionHelp("user-1") == "Every selected photo is already in Keepers.")
        let steps = catalog.history.undo.count
        catalog.addToCollection("user-1")
        #expect(catalog.history.undo.count == steps)
        catalog.undo()
        #expect(state(catalog) == before)
    }

    @Test(.disabled("waits on FC-9")) func removeWorksOnlyInACollectionYouMade() {
        var catalog = withKeepers()
        catalog.select([id(2)])
        let outside = "Open a collection you made to remove photos from it."
        #expect(catalog.removeFromCollectionHelp == outside)
        catalog.selectCollection("smart-1")
        #expect(catalog.removeFromCollectionHelp == outside)
        catalog.selectCollection("user-1")
        catalog.select([id(2)])
        let before = state(catalog)
        #expect(catalog.removeFromCollectionHelp == nil)
        catalog.removeFromCollection()
        #expect(catalog.order == [id(1), id(3)] && count("user-1", catalog) == 2 && count("all", catalog) == 24)
        #expect(catalog.undoTitle == "Undo Remove from Collection")
        catalog.undo()
        #expect(state(catalog) == before)
    }

    @Test(.disabled("waits on FC-9")) func deleteNeverChangesItems() {
        var catalog = withKeepers()
        catalog.selectCollection("user-1")
        let items = catalog.items
        let before = state(catalog)
        catalog.deleteCollection("user-1")
        #expect(catalog.items == items && count("user-1", catalog) == nil)
        #expect(catalog.selectedCollectionID == "all" && count("all", catalog) == 24)
        #expect(catalog.undoTitle == "Undo Delete Collection")
        catalog.undo()
        #expect(state(catalog) == before && catalog.items == items)
    }

    @Test(.disabled("waits on FC-9")) func renameTrimsAndRefusesEmptyAndBuiltIns() {
        var catalog = withKeepers()
        catalog.renameCollection("user-1", to: "  Selects \n")
        #expect(catalog.collections.first { $0.id == "user-1" }?.name == "Selects")
        #expect(catalog.undoTitle == "Undo Rename Collection")
        let steps = catalog.history.undo.count
        let before = state(catalog)
        for (target, name) in [("user-1", "   "), ("all", "Everything"), ("favorites", "Best")] {
            catalog.renameCollection(target, to: name)
        }
        #expect(state(catalog) == before && catalog.history.undo.count == steps)
        catalog.undo()
        #expect(catalog.userCollections.first?.name == "Keepers")
    }
}
