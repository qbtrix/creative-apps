// HaloUniqueNameFuzzTests.swift: adversarial checks that New Composition,
// Duplicate and Rename keep composition names unique under the look-alike
// key, whatever order they run in (#150). Runs on Linux and macOS.
import HaloModel
import Testing

/// Every name is free under renameProblem's comparison: renaming any
/// composition to its own name is never refused as taken.
private func namesAreLookalikeUnique(_ project: HaloProject) -> Bool {
    project.compositions.allSatisfy { project.renameProblem($0.id, to: $0.name) == nil }
        && project.compositions.allSatisfy { comp in
            project.compositions.allSatisfy { other in
                other.id == comp.id || project.renameProblem(other.id, to: comp.name) != nil
            }
        }
}

@Test func theIssueReprosGetTheNextFreeNumber() {
    var p = HaloProject()
    p.newComposition()
    p.newComposition()
    p.renameComposition("comp-2", to: "comp 3")
    p.newComposition()
    #expect(p.compositions.map(\.name) == ["Comp 1", "comp 3", "Comp 3 2"])

    var q = HaloProject()
    q.newComposition()
    q.newComposition(CompositionSettings(name: "COMP 1"))
    #expect(q.compositions.map(\.name) == ["Comp 1", "COMP 1 2"])

    var r = HaloProject()
    r.newComposition()
    r.newComposition()
    r.renameComposition("comp-2", to: "comp 1 COPY")
    r.duplicateComposition("comp-1")
    #expect(r.compositions.map(\.name) == ["Comp 1", "Comp 1 copy 2", "comp 1 COPY"])
}

@Test func duplicatingADuplicateRepeatedlyStaysUnique() {
    var p = HaloProject()
    p.newComposition()
    p.renameComposition("comp-1", to: "Title")
    for _ in 0..<5 { p.duplicateComposition("comp-1") }
    let renamed = p.renameComposition("comp-3", to: "TITLE COPY 6")
    #expect(renamed)
    p.duplicateComposition("comp-1")
    #expect(namesAreLookalikeUnique(p))
    #expect(p.selectedComposition?.name == "Title copy 2")
    p.duplicateComposition("comp-1")
    #expect(p.selectedComposition?.name == "Title copy 7")
}

@Test func randomNewDuplicateAndRenameNeverMakeALookalikePair() {
    let names = [
        "Comp 1", "comp 1", "COMP 1 2", "Comp 1 copy", "comp 1 COPY 2", " Comp 2 ", "Caf\u{E9}",
        "CAFE\u{301}", "caf\u{E9} 2", "Title", "title copy", "TITLE COPY COPY", "Comp 3", "comp 4",
    ]
    var seed: UInt64 = 0x150
    func next(_ bound: Int) -> Int {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((seed >> 33) % UInt64(max(bound, 1)))
    }
    for _ in 0..<10 {
        var p = HaloProject()
        p.newComposition()
        for _ in 0..<30 {
            let ids = p.compositions.map(\.id)
            let id = ids.isEmpty ? "comp-1" : ids[next(ids.count)]
            switch next(4) {
            case 0: p.newComposition()
            case 1: p.newComposition(CompositionSettings(name: names[next(names.count)]))
            case 2: p.duplicateComposition(id)
            default: p.renameComposition(id, to: names[next(names.count)])
            }
            #expect(namesAreLookalikeUnique(p))
        }
    }
}
