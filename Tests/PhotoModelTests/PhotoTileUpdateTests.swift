// PhotoTileUpdateTests.swift: the live canvas's tile updates against the CPU
// reference. Laid where they belong, update after update through a stroke,
// the tiles equal a full render premultiplied, and each event brings only its
// dirty tiles, never a whole-canvas buffer. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoTileUpdateTests {
    /// A canvas-sized premultiplied picture that `update`s are laid onto, as the
    /// canvas view lays its tile layers.
    struct Shown {
        var width = 0, height = 0, revision: Int?
        var rgba8: [UInt8] = []

        mutating func apply(_ update: PhotoTileUpdate) {
            if update.isComplete || update.width != width || update.height != height {
                (width, height) = (update.width, update.height)
                rgba8 = [UInt8](repeating: 0, count: width * height * 4)
            }
            for tile in update.tiles {
                let r = tile.rect
                for row in 0..<r.height {
                    let to = ((r.y + row) * width + r.x) * 4
                    rgba8.replaceSubrange(to..<(to + r.width * 4), with: tile.rgba8[(row * r.width * 4)...].prefix(r.width * 4))
                }
            }
            revision = update.revision
        }
    }

    @Test func aStrokeEventByEventMatchesTheReferenceWithOnlyItsTiles() async throws {
        // An erased patch makes partial alpha; a moved layer's tiles straddle the canvas tiles.
        var workspace = try whiteImage(600, 520)
        stroke(&workspace, .eraser, from: point(300, 300), to: point(420, 330))
        addFilledLayer(&workspace, red: 30, green: 90, blue: 200)
        workspace.setOpacity(try #require(workspace.selectedLayerID), percent: 40)
        stroke(&workspace, .move, from: point(0, 0), to: point(37, 23))
        var shown = Shown()
        let first = try await PhotoRenderer.update(workspace, since: nil)
        #expect(first.isComplete && first.tiles.count == 9)
        shown.apply(first)
        workspace.selectTool(.brush)
        for x in stride(from: 200.0, through: 500, by: 12) {
            let since = try #require(shown.revision)
            workspace.drag(from: point(x, x), to: point(x + 12, x + 3))
            let update = try await PhotoRenderer.update(workspace, since: since)
            let dirty = PhotoRenderer.tiles(of: try #require(workspace.canvas), in: workspace.damage(since: since))
            #expect(!update.isComplete && update.revision == workspace.revision)
            #expect(Set(update.tiles.map(\.rect)) == Set(dirty))
            #expect(update.tiles.allSatisfy { $0.rgba8.count == $0.rect.width * $0.rect.height * 4 })
            shown.apply(update)
        }
        workspace.endDrag()
        let reference = try await PhotoRenderer.render(workspace)
        #expect(shown.rgba8 == PhotoRenderer.premultiplied(reference.rgba8))
        workspace.undo()
        shown.apply(try await PhotoRenderer.update(workspace, since: shown.revision))
        #expect(shown.rgba8 == PhotoRenderer.premultiplied(try workspace.composite().rgba8()))
    }

    @Test func aCompleteUpdateMadeInPlaceIsTheParallelOne() async throws {
        var workspace = try whiteImage(300, 270)
        addFilledLayer(&workspace, red: 10, green: 200, blue: 90)
        let complete = try PhotoRenderer.completeUpdate(workspace)
        let parallel = try await PhotoRenderer.update(workspace, since: nil)
        #expect(complete.isComplete && complete.revision == workspace.revision)
        #expect(Set(complete.tiles.map(\.rect)) == Set(parallel.tiles.map(\.rect)))
        for tile in complete.tiles { #expect(parallel.tiles.contains(tile)) }
        #expect(throws: RasterError.self) { try PhotoRenderer.completeUpdate(PhotoWorkspace()) }
    }

    @Test func nothingChangedBringsNoTiles() async throws {
        let workspace = try whiteImage(300, 300)
        let update = try await PhotoRenderer.update(workspace, since: workspace.revision)
        #expect(update.tiles.isEmpty && !update.isComplete)
    }

    @Test func premultiplyingRoundsToTheNearestAndKeepsOpaquePixels() {
        #expect(PhotoRenderer.premultiplied([200, 100, 1, 255, 200, 100, 1, 128, 9, 9, 9, 0]) == [
            200, 100, 1, 255, 100, 50, 1, 128, 0, 0, 0, 0,
        ])
        #expect(PhotoRenderer.premultiplied([]) == [])
    }

    @Test func noImageThrows() async {
        await #expect(throws: RasterError.self) { try await PhotoRenderer.update(PhotoWorkspace(), since: nil) }
    }
}
