// HaloRenameRefusalTests.swift: a refused composition rename is kept, with
// the user's name and the reason, until it is retried or dismissed (#129).
// Runs on Linux and macOS.
import HaloModel
import Testing

@Test func renamingToATakenNameKeepsTheEditAndSaysWhy() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    #expect(project.renameProblem("comp-2", to: " Comp 1 ") == "“Comp 1” is already used by another composition. Choose a different name.")
    #expect(project.renameComposition("comp-2", to: " Comp 1 ") == false)
    #expect(project.refusedRename == RefusedRename(id: "comp-2", name: " Comp 1 ",
        problem: "“Comp 1” is already used by another composition. Choose a different name."))
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 2"])
}

@Test func retryingWithAFreeNameRenamesAndClearsTheRefusal() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    project.renameComposition("comp-2", to: "Comp 1")
    #expect(project.renameProblem("comp-2", to: "Outro") == nil)
    #expect(project.renameComposition("comp-2", to: "Outro") == true)
    #expect(project.refusedRename == nil)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Outro"])
}

@Test func dismissingClearsTheRefusalAndAnEmptyNameSaysWhy() {
    var project = HaloProject()
    project.newComposition()
    #expect(project.renameComposition("comp-1", to: "  ") == false)
    #expect(project.refusedRename?.problem == "Enter a name for the composition.")
    project.dismissRefusedRename()
    #expect(project.refusedRename == nil)
    #expect(project.renameComposition("comp-9", to: "Other") == false)
    #expect(project.refusedRename == nil)
    #expect(project.renameProblem("comp-9", to: "Other") == "The composition no longer exists.")
}
