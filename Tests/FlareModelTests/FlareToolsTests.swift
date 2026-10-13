// FlareToolsTests.swift: the no-dead-tools check for Flare's palette. Each
// FlareTool is either disabled with help saying why, or its drag on an open
// stage changes the workspace, and an enabled tool must be one the stage
// actually drags. The fixture is a new animation; when a tool
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

/// The tools whose stage gesture reaches `drag` in FlareApp. A Model drag
/// that works is not enough: until the stage sends it, the button is dead.
/// The change that wires a tool's stage gesture adds the tool here and sets
/// its `unavailableHelp` to nil.
private let toolsTheStageDrags: Set<FlareTool> = []

@Test(arguments: FlareTool.allCases)
func flareToolIsEnabledOnlyWithAStagePath(_ tool: FlareTool) {
    #expect(
        !tool.isEnabled || toolsTheStageDrags.contains(tool),
        "\(tool) is shown enabled, but the stage never sends it a drag"
    )
}
