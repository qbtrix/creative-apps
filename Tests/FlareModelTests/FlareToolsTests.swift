// FlareToolsTests.swift: the no-dead-tools check for Flare's palette. Each
// FlareTool is either disabled with `toolHelp` saying why, or its drag then
// `endDrag` on an open stage changes the workspace, on fake and live services,
// and an enabled tool must be one the stage actually drags. The fixture is
// `empty`, or `bounce` for the selection tools (dragged from Ball); when a tool
// needs more under the pointer to show its effect, grow the fixture, never
// weaken the check. Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

@Test(arguments: FlareTool.allCases)
func flareToolActsOrIsDisabled(_ tool: FlareTool) {
    for services in [FlareServices.fake(), .live] {
        var before = FlareWorkspace(services: services)
        before.load([.select, .directSelect].contains(tool) ? FlareFixtures.bounce : FlareFixtures.empty)
        before.selectTool(tool)
        if let help = before.toolHelp(tool) {
            #expect(!help.isEmpty, "\(tool) is disabled with no help saying why")
            continue
        }
        var after = before
        after.dragChanged(from: Point(x: 80, y: 100), to: Point(x: 200, y: 160))
        after.endDrag()
        #expect(after != before, "\(tool) is enabled, but a drag on the stage changes nothing")
    }
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
