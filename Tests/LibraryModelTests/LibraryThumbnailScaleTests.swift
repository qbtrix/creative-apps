// LibraryThumbnailScaleTests.swift: thumbnails TH-6f. The grid reports its
// cell size with a whole display scale ≥ 1, and the bucket grows as
// View > Larger Thumbnails steps the cell from 80 to 320.
@testable import LibraryModel
import Testing

@Test func displayScaleRoundsToAWholeScaleOfAtLeastOne() {
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: 2) == 2)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: 1) == 1)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: 1.6) == 2)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: 3) == 3)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: 0) == 1)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: 0.4) == 1)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: -2) == 1)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: .nan) == 1)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: .infinity) == 1)
    #expect(LibraryCatalog.thumbnailScale(forDisplayScale: 1e300) == 8)
}

@Test func largerThumbnailsGrowTheBucketAcrossTheMenuSteps() {
    var catalog = LibraryCatalog()
    catalog.stepCellSize(by: -10)
    #expect(catalog.cellSize == 80)
    var sides: [Int] = []
    while true {
        sides.append(catalog.thumbnailLongSide(forCell: catalog.cellSize, scale: 2))
        guard catalog.canShowLargerThumbnails else { break }
        catalog.stepCellSize(by: 1)
    }
    #expect(sides.count == 7)  // 80, 120, ... 320
    #expect(zip(sides, sides.dropFirst()).allSatisfy { $0 <= $1 })
    #expect(sides.allSatisfy { $0 > 0 })
    let first = sides.first ?? 0, last = sides.last ?? 0
    #expect(last > first)
    #expect(catalog.thumbnailLongSide == last)
    // Each bucket covers the cell at the scale.
    for (step, side) in sides.enumerated() { #expect(side >= (80 + step * 40) * 2) }
}
