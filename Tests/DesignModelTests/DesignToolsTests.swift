// DesignToolsTests.swift: the no-dead-tools check for Design's palette. Each
// DesignTool is either disabled with help saying why, or its drag on an open
// page changes the workspace. The fixture is a new file (one page with its
// Desktop frame); when a tool needs more under the pointer to show its effect,
// grow the fixture, never weaken the check. Runs on Linux and macOS.
import DesignModel
import Testing

@Test(arguments: DesignTool.allCases)
func designToolActsOrIsDisabled(_ tool: DesignTool) {
    var before = DesignWorkspace()
    before.newFile()
    before.selectTool(tool)
    guard tool.isEnabled else {
        #expect(tool.unavailableHelp?.isEmpty == false, "\(tool) is disabled with no help saying why")
        return
    }
    var after = before
    after.drag(from: DesignPoint(x: 40, y: 40), to: DesignPoint(x: 200, y: 160))
    let changed = after != before
    #expect(changed, "\(tool) is shown enabled, but a drag on the page changes nothing")
}
