// LibraryThumbnailSnapshots.swift: the grid's thumbnail states (feature
// thumbnails, TH-5) on the 24-photo shoot, portrait and landscape: every cell
// ready with its gradient (a portrait aspect-fit inside its landscape cell, a
// reject dimmed), every cell loading, and two files unreadable. Light and
// Dark. Writes library-grid-thumbnails-, library-grid-loading- and
// library-grid-unreadable-{light,dark}.png. macOS only.
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

extension LibraryCatalog {
    /// The catalog after one request pass over every shown photo at scale 1,
    /// each answered with the photo's sample gradient (what the fakes draw)
    /// or failed with `failing[id]`, through the model's own result methods.
    func answeringThumbnails(failing: [String: LibraryError] = [:]) -> LibraryCatalog {
        var catalog = self
        _ = catalog.thumbnailLongSide(forCell: catalog.cellSize, scale: 1)
        let photos = Dictionary(catalog.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for request in catalog.requestThumbnails(visible: catalog.sortedItems.map(\.id)) {
            if let error = failing[request.id] {
                catalog.failThumbnail(request, error)
            } else if let photo = photos[request.id],
                      let image = SampleImage.image(for: photo, longSide: request.longSide) {
                catalog.setThumbnail(image, for: request)
            }
        }
        return catalog
    }
}

@MainActor
@Suite struct LibraryThumbnailSnapshots {
    /// The shoot, with IMG_0024 (first by capture date, landscape) and
    /// IMG_0021 (portrait) rejected, and some stars and a label.
    private static func shoot() -> LibraryCatalog {
        let photos = LibraryFixtures.photos(named: "shoot").map { photo in
            let n = Int(photo.name.suffix(2)) ?? 0
            return PhotoItem(
                id: photo.id, name: photo.name, captureDate: photo.captureDate, color: photo.color,
                rating: n % 6, label: n % 5 == 0 ? .red : nil, flag: n == 24 || n == 21 ? .reject : nil,
                path: photo.path, pixelSize: photo.pixelSize)
        }
        var catalog = LibraryCatalog()
        catalog.load(photos)
        return catalog
    }

    private static func id(_ name: String) -> String { "/fixture/shoot/\(name).jpg" }

    @Test func thumbnails() throws {
        let loading = Self.shoot()
        let ready = loading.answeringThumbnails()
        let unreadable = loading.answeringThumbnails(failing: [
            Self.id("IMG_0003"): .missingFile(Self.id("IMG_0003")),
            Self.id("IMG_0010"): .notAnImage(Self.id("IMG_0010")),
        ])

        // A portrait comes back taller than wide and is drawn, not cropped (the grid aspect-fits it).
        let portrait = Self.id("IMG_0021")
        let held = try #require(ready.thumbnails[portrait])
        #expect(held.size.height == 256 && held.size.width < held.size.height)
        #expect(ready.cellValue(for: portrait).hasPrefix("ready \(held.size.width)×256"))
        let rejected = try #require(ready.sortedItems.first { $0.id == portrait })
        let readyCell = ThumbnailItem<String>(
            photo: rejected, thumbnail: held, value: ready.cellValue(for: portrait))
        #expect(readyCell.image != nil && readyCell.badges.dimmed && !readyCell.isUnreadable)
        #expect(readyCell.accessibilityValue?.hasPrefix("ready ") == true)

        // Loading: no image, the placeholder fill, valued `loading`.
        let first = try #require(loading.sortedItems.first)
        #expect(first.name == "IMG_0024")
        let loadingCell = ThumbnailItem<String>(photo: first, value: loading.cellValue(for: first.id))
        #expect(loadingCell.image == nil && loadingCell.accessibilityValue?.hasPrefix("loading") == true)

        // Unreadable: the warning mark, the reason as help, valued `unreadable`.
        let missing = try #require(unreadable.sortedItems.first { $0.id == Self.id("IMG_0003") })
        let missingCell = ThumbnailItem<String>(photo: missing, value: unreadable.cellValue(for: missing.id))
        #expect(missingCell.isUnreadable && missingCell.help == "The file is missing.")
        #expect(missingCell.help == unreadable.cellHelp(for: missing.id))
        #expect(missingCell.accessibilityValue?.hasPrefix("unreadable") == true)
        #expect(unreadable.thumbnails[missing.id] == nil)

        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(grid(ready), name: "library-grid-thumbnails-\(suffix)", scheme: scheme)
            try snapshot(grid(loading), name: "library-grid-loading-\(suffix)", scheme: scheme)
            try snapshot(grid(unreadable), name: "library-grid-unreadable-\(suffix)", scheme: scheme)
        }
    }

    /// The browser pinned to the top, where the real ScrollView starts
    /// (ImageRenderer drops it, so the full grid is taller than the frame).
    private func grid(_ catalog: LibraryCatalog) -> some View {
        LibraryBrowser(model: catalog).frame(width: 1440, height: 900, alignment: .top)
    }
}
