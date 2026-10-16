// LibraryGridCellTests.swift: a grid cell says what its cull badges mean
// (finding #1664). The flag glyph alone read "Flagged" while the menus say
// Pick and Reject, and the tooltip was only the file name. Now a cell's help
// is "<name>: <cullSummary>", a reject is dimmed under SuiteUI's "Rejected"
// badge, and an unreadable file's help says why. macOS only.
import Foundation
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

private extension PhotoItem {
    static var sample: PhotoItem {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        return catalog.items.first ?? PhotoItem(name: "none", captureDate: Date(), color: .init(0, 0, 0))
    }
}

@MainActor
@Suite struct LibraryGridCellTests {
    private let epoch = Date(timeIntervalSince1970: 0)
    /// A sample's color, so this file needn't import the engine's color type.
    private static let color = PhotoItem.sample.color

    @Test func aPickedCellsHelpSaysPicked() {
        let photo = PhotoItem(name: "IMG_0040", captureDate: epoch, color: Self.color, rating: 1, flag: .pick)
        let cell = ThumbnailItem<String>(photo: photo)
        #expect(cell.help == "IMG_0040: 1 star, Picked")
        #expect(cell.help?.contains("Flagged") == false)
        #expect(cell.badges.isFlagged && !cell.badges.dimmed)
    }

    @Test func aRejectedCellIsDimmedAndItsHelpSaysRejected() {
        let photo = PhotoItem(
            name: "IMG_0041", captureDate: epoch, color: Self.color, flag: .reject)
        let cell = ThumbnailItem<String>(photo: photo)
        #expect(cell.help == "IMG_0041: No stars, Rejected")
        #expect(cell.badges.dimmed && !cell.badges.isFlagged)
    }

    @Test func anUnflaggedCellSaysItsStarsAndLabel() {
        let photo = PhotoItem(name: "IMG_0042", captureDate: epoch, color: Self.color, rating: 3, label: .red)
        let cell = ThumbnailItem<String>(photo: photo)
        #expect(cell.help == "IMG_0042: 3 stars, Red")
        #expect(!cell.badges.dimmed && !cell.badges.isFlagged)
    }

    @Test func aMissingFilesHelpSaysWhy() {
        let photo = PhotoItem(
            name: "IMG_0043", captureDate: epoch, color: Self.color, flag: .pick, availability: .missing)
        #expect(ThumbnailItem<String>(photo: photo).help == "The file is missing.")
    }
}
