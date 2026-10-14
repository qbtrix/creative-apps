// PhotoDragBatchTests.swift: a display frame's pointer moves applied together
// (`drags`) paint exactly what the same moves paint one by one, and move the
// revision once, with damage covering them all. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoDragBatchTests {
    typealias Move = (from: Mask.Point, to: Mask.Point, pressure: Double, sampling: Bool)

    /// A zigzag stroke's moves with rising pressure, as the canvas sends them.
    static let moves: [Move] = (0..<12).map { i -> Move in
        let x = 20 + 14 * Double(i), up = i % 2 == 0
        return (point(x, up ? 60 : 78), point(x + 14, up ? 78 : 60), 0.5 + Double(i) / 24, false)
    }

    @Test func aBatchPaintsWhatItsMovesPaintOneByOneInOneRevision() throws {
        var single = try whiteImage(256, 160)
        single.selectTool(.brush)
        var batched = single
        let start = batched.revision
        for move in Self.moves { single.drag(from: move.from, to: move.to, pressure: move.pressure) }
        batched.drags(Array(Self.moves.prefix(5)))
        #expect(batched.revision == start + 1 && batched.isDragging)
        batched.drags(Array(Self.moves.dropFirst(5)))
        #expect(batched.revision == start + 2)
        #expect(batched.pixels == single.pixels)
        #expect(batched.damage(since: start) == single.damage(since: start))
        #expect(batched.damage(since: start + 1) != .none)
        single.endDrag()
        batched.endDrag()
        #expect(batched.pixels == single.pixels && !batched.isDragging)
        #expect(batched.undoActionName == "Undo Paint")
    }

    @Test func aBatchLongerThanTheDamageLogRedrawsEverything() throws {
        var workspace = try whiteImage(256, 160)
        workspace.selectTool(.brush)
        let start = workspace.revision
        let moves = (0..<80).map { i -> Move in (point(Double(3 * i), 40), point(Double(3 * i + 3), 40), 1, false) }
        workspace.drags(moves)
        #expect(workspace.revision == start + 1)
        #expect(workspace.damage(since: start) == .all)
    }

    @Test func aBatchKeepsEachMovesOptionKeyForTheClonePress() throws {
        var workspace = try whiteImage(256, 160)
        workspace.selectTool(.clone)
        workspace.drags([(point(40, 40), point(40, 40), 1, true), (point(40, 40), point(60, 40), 1, false)])
        workspace.endDrag()
        let sampled = try #require(workspace.cloneSource)
        workspace.drags([(point(120, 90), point(120, 90), 1, false)])
        workspace.endDrag()
        #expect(workspace.cloneSource?.point == sampled.point, "a press without Option clones from the source it has")
        workspace.drags([(point(150, 90), point(150, 90), 1, true)])
        workspace.endDrag()
        #expect(workspace.cloneSource?.point == point(150, 90))
    }

    @Test func anEmptyBatchChangesNothing() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.brush)
        let before = workspace
        workspace.drags([])
        #expect(workspace == before && !workspace.isDragging)
    }
}
