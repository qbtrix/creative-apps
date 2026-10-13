// PhotoToolsTests.swift: the no-dead-tools check for Photo's palette. Each
// PhotoTool is either disabled with help saying why, or its drag on an open
// canvas changes the workspace. The fixture is the smallest open image; when a
// tool needs more under the pointer to show its effect, grow the fixture,
// never weaken the check. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Test(arguments: PhotoTool.allCases)
func photoToolActsOrIsDisabled(_ tool: PhotoTool) throws {
    var before = PhotoWorkspace()
    try before.newCanvas(width: 64, height: 64)
    before.selectTool(tool)
    guard tool.isEnabled else {
        #expect(tool.unavailableHelp?.isEmpty == false, "\(tool) is disabled with no help saying why")
        return
    }
    var after = before
    after.drag(from: Mask.Point(x: 8, y: 8), to: Mask.Point(x: 40, y: 40))
    let changed = after != before
    #expect(changed, "\(tool) is shown enabled, but a drag on the canvas changes nothing")
}
