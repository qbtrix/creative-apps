// HaloCompositionEdgeTests.swift: adversarial and seeded-fuzz tests for
// composition settings and HaloProject's duplicate, rename and delete: extreme
// settings, repeated copies, names that collide, and random command sequences
// that must keep the project's invariants. Runs on Linux and macOS.
import HaloModel
import Testing

@Test(arguments: [
    (Int.min, 1080, 30, 10.0), (Int.max, 1080, 30, 10), (1920, Int.max, 30, 10), (1920, 1080, 0, 10),
    (1920, 1080, -24, 10), (1920, 1080, Int.max, 10), (1920, 1080, 30, .infinity), (1920, 1080, 30, -.infinity),
    (1920, 1080, 30, 86_400.001), (1920, 1080, 30, -0.0), (1920, 1080, 30, .greatestFiniteMagnitude),
] as [(Int, Int, Int, Double)])
func extremeSettingsAreInvalidAndAddNothing(width: Int, height: Int, fps: Int, seconds: Double) {
    let settings = CompositionSettings(name: "Edge", width: width, height: height, framesPerSecond: fps, durationSeconds: seconds)
    #expect(!settings.isValid)
    #expect(settings.durationFrames == nil)
    var project = HaloProject()
    #expect(project.newComposition(settings) == false)
    #expect(project.compositions.isEmpty)
    #expect(project.selectedCompositionID == nil)
}

@Test func everyProblemIsListedInFormOrder() {
    let settings = CompositionSettings(name: "\n\t ", width: 0, height: 9000, framesPerSecond: 29, durationSeconds: 0)
    #expect(settings.problems.count == 5)
    #expect(settings.problems.first == "Enter a name.")
    #expect(settings.problems.last == "Duration must be more than 0 seconds and at most 24 hours.")
}

@Test(arguments: [
    (0.000_1, 24, 1), (0.5 / 30, 30, 1), (1.0 / 60, 60, 1), (86_400, 60, 5_184_000), (10, 25, 250), (1.02, 24, 24),
] as [(Double, Int, Int)])
func durationRoundsToWholeFramesAtLeastOne(seconds: Double, fps: Int, frames: Int) {
    let settings = CompositionSettings(name: "Edge", framesPerSecond: fps, durationSeconds: seconds)
    #expect(settings.durationFrames == frames)
}

@Test func copiesOfCopiesStayUnique() {
    var project = HaloProject()
    project.newComposition()
    for _ in 0..<5 { project.duplicateComposition("comp-1") }
    if let copyID = project.compositions.first(where: { $0.name == "Comp 1 copy" })?.id {
        #expect(project.duplicateComposition(copyID) == true)
    }
    let names = project.compositions.map(\.name)
    #expect(Set(names).count == names.count)
    #expect(names.contains("Comp 1 copy 5"))
    #expect(names.contains("Comp 1 copy copy"))
}

@Test func aTakenNameGetsANumberOnCreateButIsRefusedOnRename() {
    var project = HaloProject()
    #expect(project.newComposition(CompositionSettings(name: "Intro")) == true)
    #expect(project.newComposition(CompositionSettings(name: " Intro ")) == true)
    #expect(project.compositions.map(\.name) == ["Intro", "Intro 2"])
    #expect(project.renameComposition("comp-2", to: "Intro") == false)
    #expect(project.renameComposition("comp-2", to: "Intro 2") == true)
    #expect(project.renameComposition("comp-1", to: " Intro\n") == true)
    #expect(project.compositions.map(\.name) == ["Intro", "Intro 2"])
}

@Test func deletingAnUnselectedCompositionKeepsTheSelection() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    project.newLayer(.text)
    #expect(project.deleteComposition("comp-1") == true)
    #expect(project.selectedCompositionID == "comp-2")
    #expect(project.selectedLayerID == "comp-2-layer-1")
    #expect(project.deleteComposition("comp-9") == false)
}

@Test func deletingTheSelectedCompositionClearsItsLayerSelection() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    project.newLayer(.solid)
    #expect(project.deleteComposition("comp-2") == true)
    #expect(project.selectedCompositionID == "comp-1")
    #expect(project.selectedLayerID == nil)
    #expect(project.selectedLayer == nil)
}

@Test func emptyProjectRefusesEveryCompositionCommand() {
    var project = HaloProject()
    #expect(!project.canDeleteComposition)
    #expect(project.duplicateComposition("comp-1") == false)
    #expect(project.renameComposition("comp-1", to: "X") == false)
    #expect(project.deleteComposition("comp-1") == false)
    #expect(project == HaloProject())
}

/// A small deterministic generator (SplitMix64) so a failing fuzz run repeats.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Test(arguments: [1, 7, 42, 2026, 31_337] as [UInt64])
func randomCommandSequencesKeepTheInvariants(seed: UInt64) {
    var rng = SplitMix64(state: seed)
    var project = HaloProject()
    project.newComposition()
    var everSeenIDs: Set<String> = []
    let names = ["Intro", "Comp 1", "Comp 1 copy", "  ", "Outro", "intro"]
    for _ in 0..<400 {
        let ids = project.compositions.map(\.id) + ["comp-999"]
        let target = ids.randomElement(using: &rng) ?? "comp-999"
        switch Int.random(in: 0..<7, using: &rng) {
        case 0: project.newComposition()
        case 1: project.duplicateComposition(target)
        case 2: project.renameComposition(target, to: names.randomElement(using: &rng) ?? "")
        case 3, 4: project.deleteComposition(target)
        case 5: project.selectComposition(target)
        default: project.newLayer(HaloLayerKind.allCases.randomElement(using: &rng) ?? .solid)
        }
        let comps = project.compositions
        #expect(!comps.isEmpty)
        #expect(Set(comps.map(\.id)).count == comps.count)
        #expect(Set(comps.map(\.name)).count == comps.count)
        #expect(comps.allSatisfy { !$0.name.isEmpty && $0.name.first?.isWhitespace != true })
        let layerIDs = comps.flatMap { $0.layers.map(\.id) }
        #expect(Set(layerIDs).count == layerIDs.count)
        #expect(project.selectedComposition != nil)
        if project.selectedLayerID != nil { #expect(project.selectedLayer != nil) }
        #expect(project.canDeleteComposition == (comps.count > 1))
        let newIDs = Set(comps.map(\.id)).subtracting(everSeenIDs)
        everSeenIDs.formUnion(newIDs)
    }
    // Ids only ever grow: a deleted id never comes back.
    project.newComposition()
    if let last = project.compositions.last?.id { #expect(!everSeenIDs.contains(last)) }
}
