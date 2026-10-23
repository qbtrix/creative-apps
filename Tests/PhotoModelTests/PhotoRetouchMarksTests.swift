// PhotoRetouchMarksTests.swift: fill-heal FH-4. A Remove drag keeps its
// points a quarter of the brush apart for the overlay, shows only that
// outline until release (the window keeps its samples off the panels), and
// spot heal and remove show the brush ring. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoRetouchMarksTests {
    @Test func aRemoveDragKeepsItsPointsAQuarterBrushApart() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.setToolOption(.size(40))
        model.selectTool(.remove)
        #expect(model.removeStroke == nil)
        var from = Mask.Point(x: 100, y: 100)
        for i in 1...30 {
            let to = Mask.Point(x: 100 + Double(i) * 4, y: 100)
            model.drag(from: from, to: to, modifiers: [])
            from = to
        }
        let path = try #require(model.removeStroke)
        #expect(path.first == Mask.Point(x: 100, y: 100))
        // 120 px at a 10 px step: every third 4 px sample.
        #expect(path.count == 11)
        for (a, b) in zip(path, path.dropFirst()) { #expect(b.x - a.x >= 10) }
        #expect(model.dragShowsLineOnly && !model.dragPaintsOnly)
        model.endDrag()
        #expect(model.removeStroke == nil && !model.dragShowsLineOnly)
    }

    @Test func aRemoveClickHasNoOutline() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.remove)
        model.drag(from: Mask.Point(x: 50, y: 50), to: Mask.Point(x: 51, y: 50), modifiers: [])
        #expect(model.removeStroke == nil)
    }

    @Test func otherToolsHaveNoRemoveOutline() throws {
        for tool in PhotoTool.allCases where tool != .remove {
            var model = try PhotoWorkspace.fixture(.sample)
            model.selectTool(tool)
            model.drag(from: Mask.Point(x: 100, y: 100), to: Mask.Point(x: 200, y: 160), modifiers: [])
            #expect(model.removeStroke == nil, "\(tool)")
            #expect(model.dragShowsLineOnly == (tool == .gradient), "\(tool)")
        }
    }

    @Test func spotHealAndRemoveShowTheBrushRing() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.setToolOption(.size(24))
        for tool in [PhotoTool.spotHeal, .remove] {
            model.selectTool(tool)
            #expect(model.brushCursorDiameter == 24, "\(tool)")
        }
        model.selectTool(.bucket)
        #expect(model.brushCursorDiameter == nil)
    }
}
