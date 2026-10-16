// FlareToolsTests.swift: the no-dead-tools check for Flare's palette. Each
// FlareTool is either disabled with `toolHelp` saying why, or its drag then
// `endDrag` on an open stage changes the document or the selection (the pen:
// its open path), on fake, live and built services, on `empty` and on
// `bounce` (selection tools drag from Ball). On `empty` a selection tool
// first gets a rectangle to pick: when a
// tool needs more under the pointer to show its effect, grow the fixture, never
// weaken the check. An enabled tool must be one the stage actually drags
// (FlareStage sends every tool's drag since DK-8). Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

private let fixtures: [(name: String, document: Document)] = [
    ("empty", FlareFixtures.empty), ("bounce", FlareFixtures.bounce),
]

@Test(arguments: FlareTool.allCases)
func flareToolActsOrIsDisabled(_ tool: FlareTool) {
    for services in [FlareServices.fake(), .live, .built] {
        for fixture in fixtures {
            var before = FlareWorkspace(services: services)
            before.load(fixture.document)
            if [.select, .directSelect].contains(tool), fixture.name == "empty" {
                before.selectTool(.rectangle)
                before.drag(from: Point(x: 60, y: 80), to: Point(x: 220, y: 180))
                before.setSelection([])
            }
            before.selectTool(tool)
            if let help = before.toolHelp(tool) {
                #expect(!help.isEmpty, "\(tool) is disabled with no help saying why")
                continue
            }
            var after = before
            after.dragChanged(from: Point(x: 80, y: 100), to: Point(x: 200, y: 160))
            after.endDrag()
            // The pen's drag places anchors on its open path until a click closes it.
            let changed = after.document != before.document || after.selection != before.selection
                || (tool == .pen && after.draft != before.draft)
            #expect(changed, "\(tool) is enabled, but a drag on \(fixture.name) changes neither document nor selection")
        }
    }
}

/// The tools whose stage gesture reaches `drag` in FlareApp: FlareStage sends
/// every palette tool's drag as `.stage(.dragChanged)`, then `.endDrag`.
private let toolsTheStageDrags = Set(FlareTool.allCases)

@Test(arguments: FlareTool.allCases)
func flareToolIsEnabledOnlyWithAStagePath(_ tool: FlareTool) {
    #expect(
        !tool.isEnabled || toolsTheStageDrags.contains(tool),
        "\(tool) is shown enabled, but the stage never sends it a drag"
    )
}

/// Every palette tool is enabled on the built services' open stage: none says "isn't built yet".
@Test(arguments: FlareTool.allCases)
func flareToolIsEnabledOnTheStage(_ tool: FlareTool) {
    #expect(tool.unavailableHelp == nil, "\(tool) still says \(tool.unavailableHelp ?? "")")
    var workspace = FlareWorkspace(services: .built)
    workspace.load(FlareFixtures.empty)
    #expect(workspace.toolHelp(tool) == nil)
}
