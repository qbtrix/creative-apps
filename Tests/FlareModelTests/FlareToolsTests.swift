// FlareToolsTests.swift: the no-dead-tools check for Flare's palette. Each
// FlareTool is either disabled with help saying why, or its drag on an open
// stage changes the workspace. The fixture is a new animation; when a tool
// needs more under the pointer to show its effect, grow the fixture, never
// weaken the check. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

@Test(arguments: FlareTool.allCases)
func flareToolActsOrIsDisabled(_ tool: FlareTool) {
    var before = FlareWorkspace()
    before.newDocument()
    before.selectTool(tool)
    guard tool.isEnabled else {
        #expect(tool.unavailableHelp?.isEmpty == false, "\(tool) is disabled with no help saying why")
        return
    }
    var after = before
    after.drag(from: Point(x: 40, y: 40), to: Point(x: 200, y: 160))
    let changed = after != before
    #expect(changed, "\(tool) is shown enabled, but a drag on the stage changes nothing")
}
