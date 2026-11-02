// PhotoGradientLineTests.swift: `gradientDrag`, the line the canvas overlay
// draws while the Gradient tool drags (gradient-fill PG-6): from the press to
// where the pointer is now, gone once the drag ends, and nil for any other
// tool or a press that hasn't moved. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

struct PhotoGradientLineTests {
    @Test func followsTheDragFromThePress() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.gradient)
        workspace.drag(from: point(4, 5), to: point(4, 5))
        #expect(workspace.gradientDrag == nil, "a press that hasn't moved draws no line")
        workspace.drag(from: point(4, 5), to: point(20, 30))
        #expect(workspace.gradientDrag?.from == point(4, 5))
        #expect(workspace.gradientDrag?.to == point(20, 30))
        workspace.drag(from: point(20, 30), to: point(40, 12))
        #expect(workspace.gradientDrag?.from == point(4, 5), "the line keeps its press")
        #expect(workspace.gradientDrag?.to == point(40, 12))
        workspace.endDrag()
        #expect(workspace.gradientDrag == nil, "the line goes when the drag ends")
    }

    @Test func onlyAGradientDragShowsLineOnly() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.gradient)
        #expect(!workspace.dragShowsLineOnly, "no drag is under way before the press")
        workspace.drag(from: point(4, 5), to: point(4, 5))
        #expect(workspace.dragShowsLineOnly, "the press begins a line-only drag")
        workspace.endDrag()
        #expect(!workspace.dragShowsLineOnly, "the release ends it")
    }

    @Test func aCopysLineComesBackWithIt() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.gradient)
        workspace.drag(from: point(4, 5), to: point(4, 5))
        let revision = workspace.revision
        var live = workspace
        live.drags([(from: point(4, 5), to: point(20, 30), pressure: 1, modifiers: [])])
        #expect(live.revision == revision, "the line moves no revision")
        workspace.adoptLiveStroke(live)
        #expect(workspace.gradientDrag?.to == point(20, 30), "the adopted copy's line is the workspace's")
    }

    @Test func otherToolsDrawNoLine() throws {
        var workspace = try whiteImage()
        for tool in [PhotoTool.marquee, .crop, .brush, .select] {
            workspace.selectTool(tool)
            workspace.drag(from: point(4, 5), to: point(4, 5))
            workspace.drag(from: point(4, 5), to: point(20, 30))
            #expect(workspace.gradientDrag == nil, "\(tool) drew a gradient line")
            // The marquee's selection and the crop box are overlay marks too, so those drags share the line's copy;
            // Select pressed on the white layer moves it.
            #expect(workspace.dragShowsLineOnly == [.marquee, .crop].contains(tool), "\(tool)'s drag isn't line-only")
            workspace.endDrag()
        }
    }

    @Test func noImageNoLine() {
        var workspace = PhotoWorkspace()
        workspace.selectTool(.gradient)
        workspace.drag(from: point(4, 5), to: point(20, 30))
        #expect(workspace.gradientDrag == nil)
    }
}
