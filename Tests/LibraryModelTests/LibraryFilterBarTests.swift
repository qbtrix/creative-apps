// LibraryFilterBarTests.swift: the filter bar's behavior (filters-collections
// FC-7), written by FC-6 and disabled until FC-7 builds it, on the `shoot`
// fixture in name order with J13 step 1's culls (IMG_0001 5★, IMG_0002 3★,
// IMG_0003 Picked, IMG_0004 Rejected, IMG_0005 3★, IMG_0006 Picked).
import Testing
@testable import LibraryModel

@Suite struct LibraryFilterBarTests {
    private func id(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

    private func culled(_ services: LibraryServices = .fake()) -> LibraryCatalog {
        var catalog = LibraryCatalog(services: services)
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        for (n, stars) in [(1, 5), (2, 3), (5, 3)] {
            catalog.select([id(n)])
            catalog.setRating(stars)
        }
        for (n, flag) in [(3, PhotoFlag.pick), (4, .reject), (6, .pick)] {
            catalog.select([id(n)])
            catalog.setFlag(flag)
        }
        catalog.select([])
        return catalog
    }

    private func ids(_ numbers: [Int]) -> [String] { numbers.map(id) }

    @Test(.disabled("waits on FC-7")) func eachToggleChangesTheOrderAsJ13Says() {
        var catalog = culled()
        #expect(catalog.filterValue == "All photos; 24 of 24")

        catalog.toggleHideRejected()  // step 2
        #expect(catalog.filterValue == "Rejects hidden; 23 of 24")
        #expect(!catalog.order.contains(id(4)))
        #expect(catalog.collections.first?.count == 24)

        catalog.setRatingRule(.atLeast(3))  // step 3
        #expect(catalog.filterValue == "At least 3 stars, Rejects hidden; 3 of 24")
        #expect(catalog.order == ids([1, 2, 5]))

        catalog.setRatingRule(.exactly(3))  // step 4
        #expect(catalog.order == ids([2, 5]))

        catalog.setRatingRule(.any)  // step 5
        catalog.toggleFilterFlag(.pick)
        #expect(catalog.filterValue == "Picked, Rejects hidden; 2 of 24")
        #expect(catalog.order == ids([3, 6]))

        catalog.selectCollection("favorites")  // step 7
        #expect(catalog.filterValue == "Picked, Rejects hidden; 2 of 2")
        #expect(catalog.order == ids([3, 6]))

        catalog.clearFilter()  // step 8
        catalog.selectCollection("all")
        #expect(catalog.filterValue == "All photos; 24 of 24")
        catalog.toggleHideRejected()
        #expect(catalog.filterValue == "Rejects hidden; 23 of 24")
    }

    @Test(.disabled("waits on FC-7")) func rejectedAndHideRejectedExcludeEachOther() {
        var catalog = culled()
        catalog.toggleHideRejected()
        catalog.toggleFilterFlag(.reject)
        #expect(catalog.activeFilter.flags == [.reject] && !catalog.activeFilter.hidesRejected)
        #expect(catalog.order == ids([4]))
        #expect(catalog.filterValue == "Rejected; 1 of 24")

        catalog.toggleHideRejected()
        #expect(catalog.activeFilter.hidesRejected && !catalog.activeFilter.flags.contains(.reject))
        #expect(catalog.order.count == 23)

        catalog.setRatingRule(.atLeast(0))  // stored as Any
        #expect(catalog.activeFilter.rating == .any)
    }

    @Test(.disabled("waits on FC-7")) func aFilterKeepsWhatItStillShows() {
        var catalog = culled()
        catalog.select([id(1), id(4), id(7)])
        catalog.setRatingRule(.atLeast(3))
        #expect(catalog.selection == [id(1)])
        catalog.clearFilter()

        catalog.open(id(4))
        #expect(catalog.mode == .loupe)
        catalog.toggleHideRejected()
        #expect(catalog.mode == .grid && catalog.focusedItemID == nil)

        catalog.open(id(1))
        catalog.setRatingRule(.atLeast(3))
        #expect(catalog.mode == .loupe && catalog.focusedItemID == id(1))
    }

    @Test(.disabled("waits on FC-7")) func unflaggingUnderPickedAdvancesThenReturnsToTheGrid() {
        var services = LibraryServices.fake()
        services.culling = LiveCulling()
        var catalog = culled(services)
        catalog.toggleHideRejected()
        catalog.toggleFilterFlag(.pick)
        catalog.open(id(3))

        catalog.cull(.flag(.none))  // step 6: IMG_0006 takes IMG_0003's place
        #expect(catalog.mode == .loupe && catalog.focusedItemID == id(6))
        #expect(catalog.loupePosition == "1 of 1")

        catalog.cull(.flag(.none))  // the last pick goes
        #expect(catalog.mode == .grid && catalog.isHiddenByFilter)
        #expect(catalog.undoTitle == "Undo Clear Flag")

        catalog.undo()
        catalog.undo()
        #expect(catalog.order == ids([3, 6]) && !catalog.isHiddenByFilter)
    }

    @Test(.disabled("waits on FC-7")) func aFilterChangeRecordsNoUndoStepAndBumpsTheRevision() {
        var catalog = culled()
        let title = catalog.undoTitle
        var revision = catalog.collectionsRevision
        let changes: [(inout LibraryCatalog) -> Void] = [
            { $0.toggleHideRejected() }, { $0.setRatingRule(.atLeast(3)) }, { $0.toggleFilterFlag(.pick) },
            { $0.toggleFilterLabel(.red) }, { $0.setFilter(LibraryFilter(hidesRejected: true)) }, { $0.clearFilter() },
        ]
        for change in changes {
            change(&catalog)
            revision += 1
            #expect(catalog.collectionsRevision == revision)
            #expect(catalog.undoTitle == title)
        }
        catalog.undo()  // undoes IMG_0006's pick, not a filter change
        #expect(!catalog.activeFilter.isActive)
        #expect(catalog.items.first { $0.id == id(6) }?.flag == PhotoFlag.none)
    }

    @Test(.disabled("waits on FC-7")) func eachControlSaysWhyUntilItCanAct() {
        var empty = LibraryCatalog()
        let help = "Import or load photos to filter them."
        #expect(empty.filterHelp == help && empty.clearFilterHelp == help)
        empty.toggleHideRejected()
        #expect(empty.collectionsRevision == 0 && !empty.activeFilter.isActive)

        var catalog = culled()
        #expect(catalog.filterHelp == nil)
        #expect(catalog.clearFilterHelp == "No filter is on.")
        catalog.toggleHideRejected()
        #expect(catalog.clearFilterHelp == nil)
    }
}
