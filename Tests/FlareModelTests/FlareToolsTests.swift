// FlareToolsTests.swift: no dead tools (QB-F1). Each FlareTool has `toolHelp` saying why it is disabled, or its
// gesture changes the workspace and the stage drags it. Select tools start on `bounce`'s Ball; grow the fixture
// when a tool needs more under the pointer, never weaken the check. Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

private func opened(_ tool: FlareTool, services: FlareServices = .fake()) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: services)
    workspace.load([.select, .directSelect].contains(tool) ? FlareFixtures.bounce : FlareFixtures.empty)
    workspace.selectTool(tool)
    return workspace
}

/// Ball's centre at frame 0, then 40 points right and down.
private func gesture(_ workspace: inout FlareWorkspace) {
    workspace.dragChanged(from: Point(x: 80, y: 100), to: Point(x: 120, y: 140))
    workspace.endDrag()
}

@Test(arguments: FlareTool.allCases)
func flareToolActsOrIsDisabled(_ tool: FlareTool) {
    let before = opened(tool)
    if let help = before.toolHelp(tool) {
        #expect(!help.isEmpty, "\(tool) is disabled with no help saying why")
        return
    }
    var after = before
    gesture(&after)
    #expect(after != before, "\(tool) is shown enabled, but a drag on the stage changes nothing")
}

/// Every tool's Model gesture works on the fakes, so wiring the stage is all that keeps it disabled.
@Test(arguments: FlareTool.allCases)
func flareToolGestureChangesTheWorkspaceOnTheFakes(_ tool: FlareTool) {
    let before = opened(tool)
    var after = before
    gesture(&after)
    #expect(after != before, "\(tool)'s gesture does nothing, so enabling it would leave a dead control")
}

@Test(arguments: FlareTool.allCases)
func aToolWhoseServiceIsOffSaysTheServiceReason(_ tool: FlareTool) {
    #expect(opened(tool, services: .live).toolHelp(tool) == "Not connected yet (IN-1).")
}

/// The tools whose stage gesture reaches `drag` in FlareApp. A Model drag
/// that works is not enough: until the stage sends it, the button is dead.
/// The change that wires a tool's stage gesture adds the tool here and sets
/// its `unavailableHelp` to nil.
private let toolsTheStageDrags: Set<FlareTool> = []

@Test(arguments: FlareTool.allCases)
func flareToolIsEnabledOnlyWithAStagePath(_ tool: FlareTool) {
    #expect(
        opened(tool).toolHelp(tool) != nil || toolsTheStageDrags.contains(tool),
        "\(tool) is shown enabled, but the stage never sends it a drag"
    )
}
