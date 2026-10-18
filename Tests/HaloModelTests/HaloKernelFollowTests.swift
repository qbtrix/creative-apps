// HaloKernelFollowTests.swift: AL-h2, Halo's own parent-chain walk gone.
// `HaloKeyRules.follows` and the parent choices are the kernel's follow
// link, and a damaged file's cycle check (a layer that is its own parent,
// or whose parent follows it) still refuses the file. Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

/// The `three-layers` fixture's composition with `change` applied.
private func composition(_ change: (inout HaloComposition) -> Void = { _ in }) throws -> HaloComposition {
    var c = try #require(HaloFixtures.project("three-layers")?.compositions.first)
    change(&c)
    return c
}

/// The damaged reason `check` gives for `three-layers` with `change`; nil when it passes.
private func damagedReason(_ change: (inout HaloComposition) -> Void) throws -> String? {
    var state = try #require(HaloFixtures.project("three-layers"))
    change(&state.compositions[0])
    do {
        try HaloFileValidation.check(state)
        return nil
    } catch HaloFileError.damaged(let reason) {
        return reason
    }
}

@Test func followsIsTheKernelsFollowsForEveryPair() throws {
    let c = try composition { comp in
        comp.layers[0].parentID = comp.layers[1].id
        comp.layers[1].parentID = comp.layers[3].id
    }
    let tree = c.layerTree
    for a in c.layers {
        #expect(!HaloKeyRules.follows(a.id, a.id, in: c))
        for b in c.layers {
            #expect(HaloKeyRules.follows(a.id, b.id, in: c) == tree.follows(a.id, b.id))
        }
    }
    #expect(HaloKeyRules.follows(c.layers[0].id, c.layers[3].id, in: c))
    #expect(!HaloKeyRules.follows(c.layers[3].id, c.layers[0].id, in: c))
}

@Test func parentChoicesSkipTheLayerAndItsFollowers() throws {
    let c = try composition { comp in
        comp.layers[0].parentID = comp.layers[1].id
        comp.layers[1].parentID = comp.layers[3].id
    }
    let tree = c.layerTree
    for layer in c.layers {
        let expected = c.layers.map(\.id).filter { $0 != layer.id && !tree.follows($0, layer.id) }
        #expect(HaloKeyRules.parentCandidates(for: layer.id, in: c) == expected)
    }
    #expect(HaloKeyRules.parentCandidates(for: c.layers[3].id, in: c) == [c.layers[2].id])
}

@Test func aLayerThatIsItsOwnParentIsDamaged() throws {
    let reason = try #require(try damagedReason { $0.layers[2].parentID = $0.layers[2].id })
    #expect(reason.contains("cycle"))
}

@Test func aThreeLayerCycleIsDamagedAndAChainIsNot() throws {
    let cycle = try damagedReason { comp in
        comp.layers[0].parentID = comp.layers[1].id
        comp.layers[1].parentID = comp.layers[2].id
        comp.layers[2].parentID = comp.layers[0].id
    }
    #expect(try #require(cycle).contains("cycle"))
    let chain = try damagedReason { comp in
        comp.layers[0].parentID = comp.layers[1].id
        comp.layers[1].parentID = comp.layers[2].id
    }
    #expect(chain == nil)
}
