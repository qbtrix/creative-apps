// HomeBuilderTests.swift: HM-1a, the live home builder. Its cards are
// FakeHome's (items, order, Missing) with ages by the locale and calendar:
// Today, Yesterday, the weekday name within 6 days, else the medium date.
import Foundation
import SuiteModel
import Testing

@Suite struct HomeBuilderTests {
    /// Wednesday 14 October 2026, 12:00 UTC.
    static let now = Date(timeIntervalSince1970: 1_791_979_200)
    static let utc = TimeZone(secondsFromGMT: 0) ?? .gmt

    static func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c
    }

    static func builder(_ locale: String) -> HomeBuilder {
        HomeBuilder(creating: FakeCreating(), locale: Locale(identifier: locale), calendar: calendar())
    }

    func ref(_ name: String) -> SuiteDocumentRef {
        let path = "/tmp/Documents/" + name
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design, type: .designDocument, displayName: name)
    }

    /// The age `locale` gives one card used `daysAgo` days before now.
    func age(_ locale: String, daysAgo: Double) -> String? {
        let item = RecentItem(ref: ref("Logo.design"), lastUsed: Self.now - daysAgo * 86_400)
        return Self.builder(locale).home(recents: RecentsList(revision: 1, items: [item]), running: [], query: "", filter: nil,
                                         order: SuiteApp.apps, missingApps: [], missingFiles: [], now: Self.now).cards.first?.age
    }

    @Test func weekOfWorkCardsMatchTheFakeButTheAges() throws {
        let store = try #require(SuiteFixtures.store("weekOfWork", documents: "/tmp/Documents", now: Self.now))
        let missing: Set<String> = [store.recents.items[1].ref.fileID, store.recents.items[4].ref.fileID]
        for (query, filter) in [("", nil), ("logo", nil), ("", SuiteApp.flare), ("nothing", nil)] as [(String, SuiteApp?)] {
            func build(_ b: any HomeBuilding) -> HomeState {
                b.home(recents: store.recents, running: [.launcher, .design], query: query, filter: filter,
                       order: SuiteApp.apps, missingApps: [.halo], missingFiles: missing, now: Self.now)
            }
            let live = build(Self.builder("en_US")), fake = build(FakeHome())
            #expect(live.cards.map(\.item) == fake.cards.map(\.item))
            #expect(live.cards.map(\.isMissing) == fake.cards.map(\.isMissing))
            #expect(live.tiles == fake.tiles)
            #expect(live.running == fake.running)
            #expect(live.emptyMessage == fake.emptyMessage)
        }
        let all = Self.builder("en_US").home(recents: store.recents, running: [], query: "", filter: nil, order: SuiteApp.apps,
                                             missingApps: [], missingFiles: [], now: Self.now)
        #expect(all.cards.map(\.age) != FakeHome().home(recents: store.recents, running: [], query: "", filter: nil, order: SuiteApp.apps,
                                                         missingApps: [], missingFiles: [], now: Self.now).cards.map(\.age))
    }

    @Test func agesFollowTheCalendarDayInEnglish() {
        #expect(age("en_US", daysAgo: 0) == "Today")
        #expect(age("en_US", daysAgo: 0.4) == "Today")          // 02:24 the same day
        #expect(age("en_US", daysAgo: 0.6) == "Yesterday")      // 21:36 the day before: under a day, still yesterday
        #expect(age("en_US", daysAgo: 1) == "Yesterday")
        #expect(age("en_US", daysAgo: 3) == "Sunday")
        #expect(age("en_US", daysAgo: 6) == "Thursday")
        #expect(age("en_US", daysAgo: 10) == "Oct 4, 2026")
        #expect(age("en_US", daysAgo: -1) == "Today")           // a clock skewed into the future
    }

    @Test func germanGivesGermanWeekdays() {
        #expect(age("de_DE", daysAgo: 3) == "Sonntag")
        #expect(age("de_DE", daysAgo: 5) == "Freitag")
        #expect(age("de_DE", daysAgo: 10) != "Oct 4, 2026")
    }

    @Test func tilesKeepTheChosenOrder() {
        let order: [SuiteApp] = [.halo, .photo, .flare, .library, .design]
        let home = Self.builder("en_US").home(recents: RecentsList(), running: [], query: "", filter: nil, order: order,
                                              missingApps: [], missingFiles: [], now: Self.now)
        #expect(home.tiles.map(\.app) == order)
        #expect(home.emptyMessage == FakeHome().home(recents: RecentsList(), running: [], query: "", filter: nil, order: order,
                                                     missingApps: [], missingFiles: [], now: Self.now).emptyMessage)
    }
}
