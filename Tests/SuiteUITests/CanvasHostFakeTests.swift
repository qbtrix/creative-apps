// CanvasHostFakeTests.swift: the CH-1 fakes keep the promises the contract
// makes. The twenty content tiles cover the 4096 x 2160 document with no
// overlap, and the fake preference round-trips a choice and reports device
// loss under Automatic only. macOS only.
import CoreGraphics
import SuiteUI
import Testing

@MainActor
@Suite struct CanvasHostFakeTests {
    @Test func contentTilesCoverTheDocumentWithoutOverlap() {
        let content = FakeCanvasContent()
        let tiles = content.tiles(dirtyOnly: false).map(\.rect)

        #expect(content.documentSize == CGSize(width: 4096, height: 2160))
        #expect(tiles.count == 20)
        #expect(tiles.reduce(0) { $0 + $1.width * $1.height } == 4096 * 2160)
        for (index, first) in tiles.enumerated() {
            for second in tiles.dropFirst(index + 1) {
                let overlapsX = first.x < second.x + second.width && second.x < first.x + first.width
                let overlapsY = first.y < second.y + second.height && second.y < first.y + first.height
                #expect(!(overlapsX && overlapsY))
            }
        }
    }

    @Test func choiceRoundTripsThroughTheFake() {
        let preference = FakeRenderingPreference(choice: .automatic)
        preference.set(.gpu)
        #expect(preference.choice == .gpu)
        preference.set(.cpu)
        #expect(preference.choice == .cpu)
    }

    @Test func deviceLossNotesAutomaticOnly() {
        let automatic = FakeRenderingPreference(choice: .automatic)
        #expect(automatic.status.note == nil)
        automatic.loseDevice()
        #expect(automatic.status.note != nil)
        #expect(automatic.status.active == "CPU")

        let gpu = FakeRenderingPreference(choice: .gpu)
        gpu.loseDevice()
        #expect(gpu.status.note == nil)
        #expect(gpu.status.active == "GPU")
    }
}
