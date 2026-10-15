// PhotoToolsTests.swift: the no-dead-tools check for Photo's palette (QB-F1).
// On the `.fake` services every PhotoTool's drag on the `sample` fixture
// changes what that tool shows; on `.live` each tool's drag on an open canvas
// either changes it or the tool has help (`toolHelp`) saying why it can't yet.
// Each drag ends (`endDrag()`, the mouse-up) before the check, and the check
// reads only what the tool visibly changes (`shows`), never the whole
// workspace: an unfinished drag or a sampled clone source alone would make
// any two workspaces differ. Clone and heal sample their source with an
// Option press first, as a person does, then drag somewhere else. When a tool
// needs more under the pointer to show its effect, grow the fixture, never
// weaken the check. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

/// Whether `tool` visibly changed from `a` to `b`: the pixels for the
/// painting tools, the selection for marquee, the pending crop for crop, the
/// layers' offsets for move and the brush color for the eyedropper.
private func shows(_ tool: PhotoTool, changeFrom a: PhotoWorkspace, to b: PhotoWorkspace) -> Bool {
    switch tool {
    case .brush, .eraser, .clone, .heal:
        a.pixels != b.pixels
    case .marquee:
        a.selection != b.selection || a.selectionMask != b.selectionMask
    case .crop:
        a.pendingCrop != b.pendingCrop
    case .move:
        a.layers.map { [$0.offsetX, $0.offsetY] } != b.layers.map { [$0.offsetX, $0.offsetY] }
    case .eyedropper:
        a.brushOptions != b.brushOptions
    }
}

/// Picks `tool` and, for clone and heal, samples the source with an Option
/// press at `source` and lifts the pointer, so the next drag stamps.
private func ready(_ workspace: inout PhotoWorkspace, _ tool: PhotoTool, source: Mask.Point) {
    workspace.selectTool(tool)
    guard tool == .clone || tool == .heal else { return }
    workspace.drag(from: source, to: source, modifiers: [.option])
    workspace.endDrag()
}

/// One whole drag: press at `start`, move to `end`, lift.
private func stroke(_ workspace: inout PhotoWorkspace, from start: Mask.Point, to end: Mask.Point) {
    workspace.drag(from: start, to: end, modifiers: [])
    workspace.endDrag()
}

@Test(arguments: PhotoTool.allCases)
func photoToolActsOnFakeServices(_ tool: PhotoTool) throws {
    var before = try PhotoWorkspace.fixture(.sample)
    // The source is in the sky, the drag over the sun, so a stamp shows.
    ready(&before, tool, source: Mask.Point(x: 300, y: 100))
    #expect(before.toolHelp(tool) == nil, "\(tool) has help on .fake, where every service works")
    var after = before
    stroke(&after, from: Mask.Point(x: 520, y: 180), to: Mask.Point(x: 600, y: 260))
    #expect(!after.isDragging, "\(tool)'s drag is still under way after endDrag")
    let changed = shows(tool, changeFrom: before, to: after)
    #expect(changed, "\(tool)'s drag on the sample changes nothing it shows on .fake")
}

@Test(arguments: PhotoTool.allCases)
func photoToolActsOrHasHelpOnLiveServices(_ tool: PhotoTool) throws {
    var before = PhotoWorkspace()
    try before.newCanvas(width: 64, height: 64)
    // A black line on the white canvas gives clone and heal a texture to copy.
    before.selectTool(.brush)
    stroke(&before, from: Mask.Point(x: 4, y: 12), to: Mask.Point(x: 28, y: 12))
    ready(&before, tool, source: Mask.Point(x: 16, y: 8))
    var after = before
    stroke(&after, from: Mask.Point(x: 30, y: 30), to: Mask.Point(x: 50, y: 50))
    let changed = shows(tool, changeFrom: before, to: after)
    #expect(changed || before.toolHelp(tool)?.isEmpty == false, "\(tool) is dead on .live with no help saying why")
}
