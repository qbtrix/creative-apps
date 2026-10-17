// ValuesRecentsTests.swift: the one recents list keeps one entry per file,
// newest first, at most 200; filter and search; a merge keeps the newest
// entry per file; noting into a full list stays cheap (QB-SM1).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct ValuesRecentsTests {
    let day: Double = 86_400
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func ref(_ name: String, _ app: SuiteApp, _ type: SuiteTypeID) -> SuiteDocumentRef {
        let path = "/tmp/Documents/" + name
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app, type: type, displayName: name)
    }

    func logo(_ at: Date) -> RecentItem { RecentItem(ref: ref("Logo.design", .design, .designDocument), lastUsed: at) }
    func bounce(_ at: Date) -> RecentItem { RecentItem(ref: ref("Bounce.flare", .flare, .flareAnimation), lastUsed: at) }

    @Test func dedupesAndKeepsNewestFirst() {
        var list = RecentsList()
        list.note(logo(now - 2 * day))
        list.note(bounce(now - day))
        list.note(logo(now))
        #expect(list.items.map(\.ref.displayName) == ["Logo.design", "Bounce.flare"])
        #expect(list.items.first?.lastUsed == now)
    }

    @Test func anOlderNoteSortsBelowNewerOnes() {
        var list = RecentsList()
        list.note(bounce(now))
        list.note(logo(now - day))
        #expect(list.items.map(\.ref.displayName) == ["Bounce.flare", "Logo.design"])
        let built = RecentsList(revision: 3, items: [logo(now - day), bounce(now)])
        #expect(built.revision == 3)
        #expect(built.items.map(\.ref.displayName) == ["Bounce.flare", "Logo.design"])
    }

    @Test func capsAt200DroppingTheOldest() {
        var big = RecentsList()
        for i in 0..<250 {
            big.note(RecentItem(ref: ref("f\(i).flare", .flare, .flareAnimation), lastUsed: now + Double(i)))
        }
        #expect(RecentsList.cap == 200)
        #expect(big.items.count == 200)
        #expect(big.items.first?.ref.displayName == "f249.flare")
        #expect(big.items.last?.ref.displayName == "f50.flare")
    }

    @Test func filtersByAppAndSearchesAnyCase() {
        var list = RecentsList()
        list.note(logo(now - day))
        list.note(bounce(now))
        #expect(list.filtered(app: .flare, query: "").map(\.ref.displayName) == ["Bounce.flare"])
        #expect(list.filtered(app: nil, query: "LOGO").map(\.ref.displayName) == ["Logo.design"])
        #expect(list.filtered(app: .flare, query: "logo").isEmpty)
        #expect(list.filtered(app: nil, query: "").count == 2)
    }

    @Test func removeAndClearByApp() {
        var list = RecentsList()
        list.note(logo(now - day))
        list.note(bounce(now))
        list.remove(fileID: SuiteDocumentRef.fileID(forPath: "/tmp/Documents/Logo.design"))
        #expect(list.items.map(\.ref.displayName) == ["Bounce.flare"])
        list.clear(app: .flare)
        #expect(list.items.isEmpty)
    }

    @Test func mergingKeepsTheNewestPerFile() {
        var mine = RecentsList(revision: 4)
        mine.note(logo(now))
        mine.note(bounce(now - 2 * day))
        var theirs = RecentsList(revision: 5)
        theirs.note(bounce(now + day))
        theirs.note(logo(now - 3 * day))
        let merged = mine.merging(theirs)
        #expect(merged.revision == 5)
        #expect(merged.items.map(\.ref.displayName) == ["Bounce.flare", "Logo.design"])
        #expect(merged.items.map(\.lastUsed) == [now + day, now])
    }

    @Test func thumbnailIsKeptOnTheItem() {
        let item = RecentItem(ref: ref("Logo.design", .design, .designDocument), lastUsed: now,
                              thumbnail: "thumbnails/" + SuiteDocumentRef.fileKey("path:/tmp/Documents/Logo.design") + ".png")
        #expect(item.thumbnail?.hasPrefix("thumbnails/") == true)
        #expect(item.thumbnail?.contains("/tmp") == false)
        #expect(RecentEvent(rawValue: "saved") == .saved)
    }

    @Test func mergingKeepsMineOnATie() {
        var mine = RecentsList()
        mine.note(RecentItem(ref: ref("Logo.design", .design, .designDocument), lastUsed: now, thumbnail: "thumbnails/a.png"))
        var theirs = RecentsList()
        theirs.note(logo(now))
        let merged = mine.merging(theirs)
        #expect(merged.items.count == 1)
        #expect(merged.items.first?.thumbnail == "thumbnails/a.png")
    }

    /// QB-SM1: noting into a full list is <= 0.2 ms release, <= 2 ms debug,
    /// as a median. Even rounds re-note a file already listed; odd rounds
    /// note a new file, which evicts the oldest.
    @Test func noteIntoFullList() async {
        var list = RecentsList()
        for i in 0..<RecentsList.cap {
            list.note(RecentItem(ref: ref("f\(i).flare", .flare, .flareAnimation), lastUsed: now + Double(i)))
        }
        let runs = 50
        let items = (0..<runs).map { i in
            let name = i.isMultiple(of: 2) ? "f\(RecentsList.cap - 1 - i).flare" : "new\(i).flare"
            return RecentItem(ref: ref(name, .flare, .flareAnimation), lastUsed: now + 1_000 + Double(i))
        }
        let budget = suiteBudget(device: 0.2)
        let costs = await suiteMeasure("recents.note full", runs: runs, budget: budget) { i in
            list.note(items[i])
        }
        #expect(list.items.count == RecentsList.cap)
        #expect(list.items.first?.ref.displayName == "new49.flare")
        #expect(list.items.last?.ref.displayName == "f25.flare")
        #expect(suiteMedian(costs) <= budget)
    }
}
