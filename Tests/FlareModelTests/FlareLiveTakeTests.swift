// FlareLiveTakeTests.swift (editor-menus EM-5): a live command run on a copy of the window's workspace lands in
// the window through `takeLive`, with its edit and its undo step.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareLiveTakeTests {
    @Test func theWindowBecomesTheWorkspaceTheCommandRanOn() throws {
        let window = try FlareHeadlessTests.keyed().workspace
        var ran = FlareHeadless(workspace: window)
        let step = SetKeyframe(owner: .scene("scene-1"), layerID: "layer-1", property: "x",
                               keyframe: FlareCore.Keyframe(frame: 5, value: 40))
        _ = try FlareHeadless.catalog.run(FlareWorkspace.catalogID(SetKeyframe.id), params: JSONValue(encoding: step), on: &ran)
        #expect(ran.workspace != window)

        var taken = window
        taken.takeLive(ran)
        #expect(taken == ran.workspace)
        #expect(taken.document == ran.workspace.document)
        #expect(taken.undoActionName == ran.workspace.undoActionName)
    }
}
