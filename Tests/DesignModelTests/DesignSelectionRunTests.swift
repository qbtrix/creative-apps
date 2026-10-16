// DesignSelectionRunTests.swift: every selection change (select, Shift-click,
// deselect, a page switch) ends the edit run (design-contracts D0-1), so a
// coalescing run never spans two selections. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) holding rectangles A (node-2) and B (node-3).
private func twoRectangles() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 20, 20), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(60, 10, 20, 20), in: "node-1")
    workspace.endEditRun()
    return workspace
}

/// How many steps Undo takes back before it reaches "Add Rectangle".
private func stepsAfterAdding(_ workspace: DesignWorkspace) -> Int {
    var workspace = workspace
    var steps = 0
    while workspace.canUndo, workspace.undoActionName != "Undo Add Rectangle" {
        workspace.undo()
        steps += 1
    }
    return steps
}

@Test func nudgingASelectingBAndNudgingItIsTwoSteps() throws {
    var workspace = try twoRectangles()
    workspace.selectItem("node-2")
    workspace.nudge(.right, shift: false)
    workspace.selectItem("node-3")
    workspace.nudge(.right, shift: false)
    #expect(stepsAfterAdding(workspace) == 2)
}

@Test func nudgingATwiceIsOneStep() throws {
    var workspace = try twoRectangles()
    workspace.selectItem("node-2")
    workspace.nudge(.right, shift: false)
    workspace.nudge(.down, shift: true)
    #expect(stepsAfterAdding(workspace) == 1)
    #expect(workspace.frame("node-2") == rc(11, 20, 20, 20))
}

@Test func reselectingTheSameLayerStartsANewRun() throws {
    var workspace = try twoRectangles()
    workspace.selectItem("node-2")
    workspace.nudge(.right, shift: false)
    workspace.selectItem("node-3")
    workspace.selectItem("node-2")
    workspace.nudge(.right, shift: false)
    #expect(stepsAfterAdding(workspace) == 2)
}

/// Each selection change alone splits a run of fill edits on A, which do not depend on the selection.
@Test func everySelectionChangeEndsTheRun() throws {
    let changes: [(String, (inout DesignWorkspace) -> Void)] = [
        ("select", { $0.selectItem("node-3") }),
        ("toggle on", { $0.toggleSelection("node-3") }),
        ("toggle off", { $0.toggleSelection("node-2") }),
        ("deselect", { $0.deselect() }),
        ("page", { $0.selectPage("page-1") }),
    ]
    for (label, change) in changes {
        var workspace = try twoRectangles()
        workspace.selectItem("node-2")
        try workspace.setFill("node-2", DesignColor(1, 1, 1))
        change(&workspace)
        try workspace.setFill("node-2", DesignColor(2, 2, 2))
        #expect(stepsAfterAdding(workspace) == 2, "\(label)")
    }
}

@Test func aShiftClickThatAddsNothingKeepsTheRun() throws {
    var workspace = try twoRectangles()
    try workspace.setNodeLocked("node-3", true)
    workspace.selectItem("node-2")
    try workspace.setFill("node-2", DesignColor(1, 1, 1))
    let before = workspace
    workspace.toggleSelection("node-3")
    #expect(workspace == before)
}
