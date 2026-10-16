// PhotoLiveStrokeTests.swift: the window's live stroke. Brush, eraser, clone
// and heal drags only change pixels (`dragPaintsOnly`), so the window draws
// them on a copy and adopts it at the end (`adoptLiveStroke`): that lands
// exactly what drawing on the workspace itself lands, and a copy of another
// image is never adopted. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoLiveStrokeTests {
    @Test func onlyThePaintToolsDrawLive() throws {
        var workspace = try whiteImage()
        for tool in PhotoTool.allCases {
            workspace.selectTool(tool)
            #expect(workspace.dragPaintsOnly == [.brush, .eraser, .clone, .heal].contains(tool), "\(tool)")
        }
    }

    @Test func anAdoptedStrokeIsTheStrokeDrawnInPlace() throws {
        var direct = try whiteImage(256, 160)
        direct.selectTool(.brush)
        let model = direct
        var live = model
        for x in stride(from: 20.0, to: 200, by: 12) {
            let move = (from: point(x, 60), to: point(x + 12, 80), pressure: 0.8, modifiers: DragModifiers())
            direct.drags([move])
            live.drags([move])
        }
        var adopted = model
        adopted.adoptLiveStroke(live)
        direct.endDrag()
        adopted.endDrag()
        #expect(adopted == direct)
        #expect(adopted.undoActionName == "Undo Paint" && adopted.isDirty)
    }

    @Test func aCopyOfAnotherImageIsNotAdopted() throws {
        var model = try whiteImage(256, 160)
        var other = try whiteImage(128, 128)
        other.selectTool(.brush)
        other.drags([(from: point(10, 10), to: point(40, 40), pressure: 1, modifiers: DragModifiers())])
        let before = model
        model.adoptLiveStroke(other)
        #expect(model == before)
        var added = model
        added.addLayer()
        added.adoptLiveStroke(model)
        #expect(added.layers.count == model.layers.count + 1, "another layer stack isn't adopted")
    }
}
