// PhotoToolsTests.swift: the no-dead-tools check for Photo's palette (QB-F1).
// On the `.fake` services every PhotoTool's drag on the `sample` fixture
// changes the workspace; on `.live` each tool's drag on an open canvas either
// changes the workspace or the tool has help (`toolHelp`) saying why it can't
// yet. When a tool needs more under the pointer to show its effect, grow the
// fixture, never weaken the check. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Test(arguments: PhotoTool.allCases)
func photoToolActsOnFakeServices(_ tool: PhotoTool) throws {
    var before = try PhotoWorkspace.fixture(.sample)
    before.selectTool(tool)
    #expect(before.toolHelp(tool) == nil, "\(tool) has help on .fake, where every service works")
    var after = before
    after.drag(from: Mask.Point(x: 520, y: 180), to: Mask.Point(x: 600, y: 260))
    let changed = after != before
    #expect(changed, "\(tool)'s drag on the sample changes nothing on .fake")
}

@Test(arguments: PhotoTool.allCases)
func photoToolActsOrHasHelpOnLiveServices(_ tool: PhotoTool) throws {
    var before = PhotoWorkspace()
    try before.newCanvas(width: 64, height: 64)
    before.selectTool(tool)
    var after = before
    after.drag(from: Mask.Point(x: 8, y: 8), to: Mask.Point(x: 40, y: 40))
    let changed = after != before
    #expect(changed || before.toolHelp(tool)?.isEmpty == false, "\(tool) is dead on .live with no help saying why")
}
