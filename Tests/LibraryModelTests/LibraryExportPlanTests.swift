// LibraryExportPlanTests.swift: EX-2, the live exporter's plan. Written by
// EX-1, disabled until EX-2 replaces the spine's stub.
import Foundation
import Testing

@testable import LibraryModel

@Suite struct LibraryExportPlanTests {
    func sizes(longEdge: Int?) -> [PixelSize] {
        let photos = LibraryFixtures.photos(named: "shoot")  // IMG_0003 is 4000 × 6000
        let exporter = LiveExporter(decoder: FakeDecoder(photos: []), develop: FakeDevelop())
        return exporter.plan([photos[0], photos[2]], options: ExportOptions(longEdge: longEdge, folder: "/out"),
                             existingNames: []).items.map(\.size)
    }

    @Test(.disabled("waits on EX-2")) func planFitsTheLongEdgeAndNeverEnlarges() {
        #expect(sizes(longEdge: 1024) == [PixelSize(width: 1024, height: 683), PixelSize(width: 683, height: 1024)])
        let full = [PixelSize(width: 6000, height: 4000), PixelSize(width: 4000, height: 6000)]
        #expect(sizes(longEdge: 8192) == full)
        #expect(sizes(longEdge: nil) == full)
        #expect(LiveExporter.unavailable == nil)
    }
}
