// FlareEditHelpsTests.swift: `editHelps`, the Edit reasons as one value (#2618). The menu bar keeps an
// item's disabled state until its focused value changes, so the reasons the menu holds must change with
// the selection: on `-FlareSample bounce` Copy says "Select a layer first." until Ball is picked in LAYERS.
import FlareModel
import Testing

@Test func editHelpsChangeWhenALayerIsPickedOnTheSample() {
    var workspace = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareSample", "bounce"]))
    let before = workspace.editHelps
    #expect(before[.copy] == "Select a layer first.")
    #expect(before[.cut] == "Select a layer first.")
    #expect(before[.duplicate] == "Select a layer first.")
    workspace.selectItem("ball")
    let after = workspace.editHelps
    #expect(after[.copy] == nil)
    #expect(after[.cut] == nil)
    #expect(after[.duplicate] == nil)
    #expect(after[.delete] == nil)
    #expect(after != before)
}

@Test func editHelpsHoldEachActsReasonButPaste() {
    var workspace = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
    for pick in [nil, "ball", "background"] as [String?] {
        if let pick { workspace.selectItem(pick) }
        let helps = workspace.editHelps
        #expect(helps[.paste] == nil)
        for action in FlareEditAction.allCases where action != .paste {
            #expect(helps[action] == workspace.editHelp(action), "\(action) after picking \(pick ?? "nothing")")
        }
    }
}
