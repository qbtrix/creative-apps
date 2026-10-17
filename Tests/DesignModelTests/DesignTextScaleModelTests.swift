// DesignTextScaleModelTests.swift: the inline editor's scale follows the canvas
// zoom with no floor (#268), so the editor draws at the committed size and the
// text doesn't jump on commit. A zoom that isn't a positive finite number counts
// as 1. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func theTextEditorScaleIsTheZoomAtAnyZoom() {
    for zoom in [0.25, 0.5, 1, 2] {
        #expect(DesignWorkspace.textEditScale(zoom: zoom) == zoom)
    }
}

@Test func aZoomThatIsNotAPositiveFiniteNumberCountsAsOne() {
    for zoom in [0, -1, .nan, .infinity] as [Double] {
        #expect(DesignWorkspace.textEditScale(zoom: zoom) == 1)
    }
}

@Test func theEditorFrameEqualsTheCommittedFrameAtTheZoom() throws {
    var workspace = openDesign()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    workspace.setTextDraft("Hello")
    let editing = try #require(workspace.selectedNode)
    workspace.commitTextEdit()
    let committed = try #require(workspace.frame(editing.id))
    #expect(workspace.treeNode(editing.id)?.text == "Hello")
    // What the overlay draws: the node's frame times the editor scale.
    let scale = DesignWorkspace.textEditScale(zoom: 0.5)
    let drawn = rc(editing.frame.x * scale, editing.frame.y * scale, editing.frame.width * scale, editing.frame.height * scale)
    #expect(drawn == rc(committed.x * 0.5, committed.y * 0.5, committed.width * 0.5, committed.height * 0.5))
    #expect(drawn == rc(50, 50, 60, 12))
}
