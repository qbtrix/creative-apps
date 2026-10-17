// LibraryFilterTests.swift: the filter's rules admit the photos they name, and
// the summary and titles say what the bar shows (filters-collections FC-1).
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import Testing
@testable import LibraryModel

private func photo(
    _ name: String, rating: Int = 0, flag: PhotoFlag = .none, label: PhotoLabel? = nil
) -> PhotoItem {
    PhotoItem(
        name: name, captureDate: Date(timeIntervalSince1970: 0), color: Color3(0, 0, 0),
        rating: rating, label: label, flag: flag)
}

@Test func anyRatingAdmitsEveryStarCount() {
    #expect((0...5).allSatisfy { RatingRule.any.admits($0) })
}

@Test func atLeastAdmitsThatCountAndMore() {
    let rule = RatingRule.atLeast(3)
    #expect([0, 1, 2].allSatisfy { !rule.admits($0) })
    #expect([3, 4, 5].allSatisfy { rule.admits($0) })
}

@Test func exactlyAdmitsOnlyThatCount() {
    #expect(RatingRule.exactly(1).admits(1))
    #expect(!RatingRule.exactly(1).admits(0))
    #expect(!RatingRule.exactly(1).admits(2))
    #expect(RatingRule.exactly(0).admits(0))
    #expect(!RatingRule.exactly(0).admits(1))
}

@Test func ratingTitlesAreMenuTitles() {
    #expect(RatingRule.any.title == "Any Rating")
    #expect(RatingRule.atLeast(3).title == "At Least 3 Stars")
    #expect(RatingRule.exactly(1).title == "Exactly 1 Star")
    #expect(RatingRule.exactly(2).title == "Exactly 2 Stars")
    #expect(RatingRule.exactly(0).title == "Unrated")
}

@Test func allFilterShowsEveryPhotoAndIsNotActive() {
    #expect(!LibraryFilter.all.isActive)
    #expect(LibraryFilter.all.summary == "All photos")
    #expect(LibraryFilter.all.matches(photo("A", rating: 0, flag: .reject)))
}

@Test func flagRuleKeepsOnlyListedFlags() {
    var filter = LibraryFilter()
    filter.flags = [.pick]
    #expect(filter.matches(photo("P", flag: .pick)))
    #expect(!filter.matches(photo("N", flag: .none)))
    #expect(!filter.matches(photo("R", flag: .reject)))
}

@Test func ratingRuleKeepsOnlyAdmittedPhotos() {
    var filter = LibraryFilter()
    filter.rating = .atLeast(3)
    #expect(filter.matches(photo("Three", rating: 3)))
    #expect(!filter.matches(photo("Two", rating: 2)))
}

@Test func labelRuleDropsPhotosWithoutAListedLabel() {
    var filter = LibraryFilter()
    filter.labels = [.red]
    #expect(filter.matches(photo("Red", label: .red)))
    #expect(!filter.matches(photo("Blue", label: .blue)))
    #expect(!filter.matches(photo("None")))
}

@Test func hideRejectedDropsOnlyRejects() {
    var filter = LibraryFilter()
    filter.hidesRejected = true
    #expect(!filter.matches(photo("R", flag: .reject)))
    #expect(filter.matches(photo("P", flag: .pick)))
    #expect(filter.matches(photo("N", flag: .none)))
}

@Test func summaryNamesEachRuleThatIsOn() {
    var filter = LibraryFilter()
    filter.rating = .atLeast(3)
    filter.hidesRejected = true
    #expect(filter.isActive)
    #expect(filter.summary == "At least 3 stars, Rejects hidden")

    var exact = LibraryFilter()
    exact.rating = .exactly(1)
    #expect(exact.summary == "Exactly 1 star")
}

@Test func summaryListsFlagsAndLabelsAsOrLists() {
    var flags = LibraryFilter()
    flags.flags = [.none, .pick]
    #expect(flags.summary == "Picked or Unflagged")

    var labels = LibraryFilter()
    labels.labels = [.red, .blue]
    #expect(labels.summary == "Red or Blue")

    var three = LibraryFilter()
    three.labels = [.red, .blue, .green]
    #expect(three.summary == "Red, Green or Blue")
}

@Test func unratedRuleSummarizesAsUnrated() {
    var filter = LibraryFilter()
    filter.rating = .exactly(0)
    #expect(filter.summary == "Unrated")
}
