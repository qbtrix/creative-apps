// HaloSidebarRenameRefusalTests.swift: the reason the sidebar row shows under
// its rename field when HaloProject refuses a composition rename (#139). It is
// the refusal of that composition only, the design.md wording, and gone once
// the rename succeeds. Runs on Linux and macOS.
import HaloModel
import Testing

private func twoComps() -> HaloProject {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    return project
}

@Test func aTakenNameGivesTheRowItsReason() {
    var project = twoComps()
    project.renameComposition("comp-2", to: "Comp 1")
    #expect(project.renameRefusal("comp-2") == "“Comp 1” is already used by another composition. Choose a different name.")
    #expect(project.renameRefusal("comp-1") == nil, "another row shows nothing")
}

@Test func anAcceptedRetryClearsTheRowsReason() {
    var project = twoComps()
    project.renameComposition("comp-2", to: "Comp 1")
    project.renameComposition("comp-2", to: "Intro")
    #expect(project.renameRefusal("comp-2") == nil)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Intro"])
}
