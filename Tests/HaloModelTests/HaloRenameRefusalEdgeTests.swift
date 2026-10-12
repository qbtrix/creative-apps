// HaloRenameRefusalEdgeTests.swift: adversarial and seeded-fuzz tests for a
// refused composition rename (#129): the refusal follows the composition it
// names, a retry re-checks the current names, and random command sequences
// never leave a refusal pointing at a missing composition or a name that is
// free. Runs on Linux and macOS.
import HaloModel
import Testing

private func twoComps() -> HaloProject {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    return project
}

@Test func renamingToItsOwnNameIsNeverRefused() {
    var project = twoComps()
    #expect(project.renameProblem("comp-2", to: "Comp 2") == nil)
    #expect(project.renameComposition("comp-2", to: "\tComp 2 ") == true)
    #expect(project.refusedRename == nil)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 2"])
}

@Test(arguments: ["", " ", "\n", "\t \n", "\u{3000}", "\u{00A0}"])
func aBlankNameIsRefusedWithItsOwnReason(name: String) {
    var project = twoComps()
    #expect(project.renameComposition("comp-1", to: name) == false)
    #expect(project.refusedRename == RefusedRename(id: "comp-1", name: name, problem: "Enter a name for the composition."))
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 2"])
}

@Test func aSecondRefusalReplacesTheFirst() {
    var project = twoComps()
    project.newComposition()
    project.renameComposition("comp-3", to: "Comp 1")
    project.renameComposition("comp-2", to: " ")
    #expect(project.refusedRename == RefusedRename(id: "comp-2", name: " ", problem: "Enter a name for the composition."))
}

@Test func aRefusalSurvivesUnrelatedCommands() {
    var project = twoComps()
    project.renameComposition("comp-2", to: "Comp 1")
    let refusal = project.refusedRename
    project.newComposition()
    project.duplicateComposition("comp-1")
    project.selectComposition("comp-1")
    project.newLayer(.text)
    project.deleteComposition("comp-3")
    #expect(project.renameComposition("comp-9", to: "Free") == false)
    #expect(project.refusedRename == refusal)
}

@Test func deletingTheOtherCompositionKeepsTheRefusalButFreesTheName() {
    var project = twoComps()
    project.renameComposition("comp-2", to: "Comp 1")
    #expect(project.deleteComposition("comp-1") == true)
    #expect(project.refusedRename?.id == "comp-2")
    #expect(project.renameProblem("comp-2", to: "Comp 1") == nil)
    #expect(project.renameComposition("comp-2", to: "Comp 1") == true)
    #expect(project.refusedRename == nil)
    #expect(project.compositions.map(\.name) == ["Comp 1"])
}

@Test func deletingTheRefusedCompositionClearsTheRefusal() {
    var project = twoComps()
    project.renameComposition("comp-1", to: "Comp 2")
    #expect(project.deleteComposition("comp-1") == true)
    #expect(project.refusedRename == nil)
    #expect(project.renameProblem("comp-1", to: "Anything") == "The composition no longer exists.")
}

@Test func theLastCompositionCannotBeDeletedSoItsRefusalStays() {
    var project = HaloProject()
    project.newComposition()
    project.renameComposition("comp-1", to: "")
    #expect(project.deleteComposition("comp-1") == false)
    #expect(project.refusedRename?.id == "comp-1")
}

@Test func theReasonQuotesTheTrimmedNameAndKeepsOddCharacters() {
    var project = twoComps()
    project.renameComposition("comp-1", to: "Intro “Final”")
    #expect(project.renameProblem("comp-2", to: "  Intro “Final”\n")
        == "“Intro “Final”” is already used by another composition. Choose a different name.")
    let long = String(repeating: "x", count: 10_000)
    #expect(project.renameComposition("comp-1", to: long) == true)
    #expect(project.renameComposition("comp-2", to: long) == false)
    #expect(project.refusedRename?.name == long)
}

@Test func dismissingWithNothingRefusedIsHarmless() {
    var project = twoComps()
    let before = project
    project.dismissRefusedRename()
    project.dismissRefusedRename()
    #expect(project == before)
}

@Test func aRefusedThenDismissedRenameLeavesTheProjectAsItWas() {
    var project = twoComps()
    let before = project
    project.renameComposition("comp-2", to: "Comp 1")
    #expect(project != before)
    project.dismissRefusedRename()
    #expect(project == before)
}

/// A small deterministic generator (SplitMix64) so a failing fuzz run repeats.
private struct Mix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Test(arguments: [3, 11, 129, 4096, 77_777] as [UInt64])
func randomRenamesKeepTheRefusalConsistent(seed: UInt64) {
    var rng = Mix(state: seed)
    var project = HaloProject()
    project.newComposition()
    let names = ["Comp 1", "Comp 2", " Comp 1 ", "", "\t", "Intro", "Comp 1 copy", "Outro"]
    for _ in 0..<500 {
        let ids = project.compositions.map(\.id) + ["comp-404"]
        let target = ids.randomElement(using: &rng) ?? "comp-404"
        let name = names.randomElement(using: &rng) ?? ""
        let before = project
        switch Int.random(in: 0..<6, using: &rng) {
        case 0: project.newComposition()
        case 1: project.duplicateComposition(target)
        case 2, 3:
            let problem = project.renameProblem(target, to: name)
            let renamed = project.renameComposition(target, to: name)
            #expect(renamed == (problem == nil))
            if renamed {
                #expect(project.refusedRename == nil)
            } else if before.compositions.contains(where: { $0.id == target }), let problem {
                #expect(project.refusedRename == RefusedRename(id: target, name: name, problem: problem))
                #expect(project.compositions == before.compositions)
            } else {
                #expect(project.refusedRename == before.refusedRename)
            }
        case 4: project.deleteComposition(target)
        default: project.dismissRefusedRename()
        }
        if let refusal = project.refusedRename {
            #expect(project.compositions.contains { $0.id == refusal.id })
        }
        let comps = project.compositions
        #expect(Set(comps.map(\.name)).count == comps.count)
    }
}
