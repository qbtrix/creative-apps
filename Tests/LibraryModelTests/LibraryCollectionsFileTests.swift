// LibraryCollectionsFileTests.swift: the collections file (filters-collections
// FC-14 check row; slice FC-e). Written before its code (FC-13): FC-14 drops
// the `.disabled` traits. FC-14's planned mutations and what catches them:
// ids unsorted (golden, set order); `canSave` guard dropped (newer catalog);
// `selected` not encoded (golden, decode back); `version > 1` accepted (newer).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import Testing

#if DEBUG
private let scale = 1.0
#else
private let scale = 0.1
#endif

@Suite struct LibraryCollectionsFileTests {
    /// Sorted keys, pretty, unescaped slashes, a trailing newline, sets sorted,
    /// collections in sidebar order. From JSONEncoder's Linux output.
    private static let golden = """
        {
          "collections" : [
            {
              "id" : "smart-1",
              "name" : "At least 4 stars",
              "rules" : {
                "flags" : [

                ],
                "hidesRejected" : false,
                "labels" : [

                ],
                "rating" : "atLeast",
                "stars" : 4
              }
            },
            {
              "id" : "user-1",
              "name" : "Keepers",
              "photos" : [
                "/fixture/shoot/IMG_0001.jpg",
                "/fixture/shoot/IMG_0002.jpg",
                "/fixture/shoot/IMG_0003.jpg"
              ]
            }
          ],
          "filter" : {
            "flags" : [
              "Pick"
            ],
            "hidesRejected" : true,
            "labels" : [

            ],
            "rating" : "any",
            "stars" : 0
          },
          "selected" : "user-1",
          "version" : 1
        }

        """

    private func id(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }
    private func shoot() -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        return catalog
    }
    /// Shoot with the golden's state, one change past the saved revision.
    private func goldenCatalog() -> LibraryCatalog {
        var catalog = shoot()
        var rules = LibraryFilter()
        rules.rating = .atLeast(4)
        catalog.userCollections = [
            UserCollection(id: "smart-1", name: "At least 4 stars", contents: .rules(rules)),
            UserCollection(id: "user-1", name: "Keepers", contents: .photos([id(3), id(1), id(2)])),
        ]
        catalog.filter.flags = [.pick]
        catalog.filter.hidesRejected = true
        catalog.recount()
        catalog.selectCollection("user-1")
        catalog.collectionsRevision += 1
        return catalog
    }

    @Test(.disabled("waits on FC-14")) func encodesToTheGoldenAndDecodesBackEqual() throws {
        let catalog = goldenCatalog()
        let request = try #require(catalog.collectionsSaveRequest())
        #expect(request.revision == catalog.collectionsRevision)
        #expect(String(decoding: request.data, as: UTF8.self) == Self.golden)
        var back = shoot()
        try back.restoreCollections(request.data)
        #expect(back.userCollections == catalog.userCollections)
        #expect(back.filter == catalog.filter)
        #expect(back.selectedCollectionID == "user-1")
        #expect(back.collections.map(\.id) == ["all", "favorites", "recent", "smart-1", "user-1"])
        #expect(back.collectionsFileValue == "saved")
        #expect(back.collectionsSaveRequest() == nil)
    }

    @Test(.disabled("waits on FC-14")) func equalStateEncodesEqualWhateverTheSetOrder() throws {
        func encoded(_ photos: Set<String>, _ labels: Set<PhotoLabel>, _ flags: Set<PhotoFlag>) throws -> Data {
            var catalog = shoot()
            catalog.userCollections = [UserCollection(id: "user-1", name: "All", contents: .photos(photos))]
            catalog.filter.labels = labels
            catalog.filter.flags = flags
            catalog.recount()
            catalog.collectionsRevision += 1
            return try #require(catalog.collectionsSaveRequest()).data
        }
        var backward = Set<String>(minimumCapacity: 512)
        for n in (1...24).reversed() { backward.insert(id(n)) }
        var labels = Set<PhotoLabel>(minimumCapacity: 64)
        for label in PhotoLabel.allCases.reversed() { labels.insert(label) }
        let first = try encoded(Set((1...24).map(id)), Set(PhotoLabel.allCases), [.pick, .none])
        let second = try encoded(backward, labels, [.none, .pick])
        #expect(first == second)
    }

    @Test(.disabled("waits on FC-14")) func aDamagedOrNewerFileThrowsAndChangesNothing() throws {
        var catalog = goldenCatalog()
        let before = catalog
        for text in ["not json", "{}"] {
            let error = #expect(throws: LibraryError.self) { try catalog.restoreCollections(Data(text.utf8)) }
            if case .damagedCatalog = error {} else { Issue.record("\(text) threw \(String(describing: error))") }
        }
        let newer = Self.golden.replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 2")
        for text in [#"{"version": 2}"#, newer] {
            #expect(throws: LibraryError.newerCatalog(version: 2)) { try catalog.restoreCollections(Data(text.utf8)) }
        }
        #expect(catalog == before)
        try catalog.restoreCollections(nil)
        #expect(catalog == before)
    }

    @Test(.disabled("waits on FC-14")) func saveRequestsFollowTheRevisionsAndCanSave() throws {
        var catalog = shoot()
        #expect(catalog.collectionsSaveRequest() == nil)
        #expect(catalog.collectionsFileValue == "saved")
        catalog.collectionsRevision += 1
        let first = try #require(catalog.collectionsSaveRequest())
        #expect(catalog.collectionsFileValue == "dirty")
        catalog.collectionsRevision += 1  // a newer change while the first write runs
        catalog.didSaveCollections(revision: first.revision)
        #expect(catalog.collectionsFileValue == "dirty")
        let second = try #require(catalog.collectionsSaveRequest())
        #expect(second.revision == catalog.collectionsRevision)
        catalog.didSaveCollections(revision: second.revision)
        #expect(catalog.collectionsSaveRequest() == nil)
        #expect(catalog.collectionsFileValue == "saved")
        var newer = goldenCatalog()  // nothing is saved over a newer or loading catalog
        newer.catalogState = .newer(version: 2)
        #expect(newer.collectionsSaveRequest() == nil)
        newer.catalogState = .loading
        #expect(newer.collectionsSaveRequest() == nil)
        newer.catalogState = .ready
        #expect(newer.collectionsSaveRequest() != nil)
    }

    @Test(.disabled("waits on FC-14")) func anUnknownSelectedIDSelectsAllPhotos() throws {
        let text = Self.golden.replacingOccurrences(of: "\"selected\" : \"user-1\"", with: "\"selected\" : \"user-9\"")
        var catalog = shoot()
        catalog.selectCollection("favorites")
        try catalog.restoreCollections(Data(text.utf8))
        #expect(catalog.userCollections.map(\.id) == ["smart-1", "user-1"])
        #expect(catalog.selectedCollectionID == "all")
        #expect(catalog.filter.hidesRejected)
    }

    @Test(.disabled("waits on FC-14")) func aSetAsideFileSetsTheNotice() {
        var catalog = shoot()
        catalog.failRestoreCollections(setAsideAs: "collections.json.bad")
        #expect(catalog.collectionsNotice
            == "Library couldn't read your collections. The file was set aside as collections.json.bad.")
        #expect(catalog.userCollections.isEmpty)
        #expect(catalog.selectedCollectionID == "all")
    }

    /// 20 collections over 10,000 ids encode and decode within 200 ms debug.
    @Test(.disabled("waits on FC-14")) func twentyCollectionsOverTenThousandIDsWithinBudget() throws {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "large"))
        let ids = catalog.items.map(\.id)
        try #require(ids.count == 10_000)
        catalog.userCollections = (0..<20).map { k in
            let members = Set(ids.indices.filter { $0 % 20 == k }.map { ids[$0] })
            return UserCollection(id: "user-\(k + 1)", name: "Set \(k + 1)", contents: .photos(members))
        }
        catalog.recount()
        catalog.collectionsRevision += 1
        var restored = 0
        let cost = Budget.measure("collections file-20x10000", runs: 5) {
            var back = LibraryCatalog()
            try? back.restoreCollections(catalog.collectionsSaveRequest()?.data)
            restored = back.userCollections.count
        }
        #expect(restored == 20)
        #expect(cost.median <= 200 * scale)
    }
}
