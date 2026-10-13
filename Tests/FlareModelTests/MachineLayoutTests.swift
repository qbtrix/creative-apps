// MachineLayoutTests.swift: MachineLayout places states in columns by
// breadth-first distance from the initial state, rows by state order, and
// unreachable states in a last column. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func state(_ id: String) -> MachineState {
    MachineState(id: id, name: id, sceneID: "scene-1", startFrame: 0, endFrame: 10)
}

private func machine(_ ids: [String], _ edges: [(String, String)], initial: String = "a") -> StateMachine {
    StateMachine(id: "m", name: "M", states: ids.map(state),
                 transitions: edges.map { FlareTransition(from: $0.0, to: $0.1, trigger: "tap") },
                 initialState: initial)
}

private func places(_ layout: MachineLayout) -> [String: [Int]] {
    Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.stateID, [$0.column, $0.row]) })
}

@Test func columnsAreTheShortestDistanceFromTheInitialState() {
    // a -> b -> c -> d, plus a shortcut a -> d and a cycle back d -> a.
    let layout = MachineLayout(machine(["a", "b", "c", "d"],
                                       [("a", "b"), ("b", "c"), ("c", "d"), ("a", "d"), ("d", "a")]))
    #expect(places(layout) == ["a": [0, 0], "b": [1, 0], "d": [1, 1], "c": [2, 0]])
    #expect(layout.nodes.allSatisfy { !$0.isUnreachable })
}

@Test func rowsFollowStateOrderNotTransitionOrder() {
    let layout = MachineLayout(machine(["a", "x", "y", "z"], [("a", "z"), ("a", "y"), ("a", "x")]))
    #expect(places(layout) == ["a": [0, 0], "x": [1, 0], "y": [1, 1], "z": [1, 2]])
}

@Test func unreachableStatesShareTheColumnAfterTheFarthest() {
    // "lost" is only a source; "ghost" is reached only from "lost".
    let layout = MachineLayout(machine(["lost", "a", "b", "ghost"],
                                       [("a", "b"), ("lost", "ghost"), ("lost", "a")]))
    #expect(places(layout) == ["lost": [2, 0], "a": [0, 0], "b": [1, 0], "ghost": [2, 1]])
    #expect(layout.node(for: "ghost")?.isUnreachable == true)
    #expect(layout.node(for: "b")?.isUnreachable == false)
}

@Test func aMissingInitialStatePutsEveryStateInColumnZero() {
    let layout = MachineLayout(machine(["a", "b"], [("a", "b")], initial: "gone"))
    #expect(places(layout) == ["a": [0, 0], "b": [0, 1]])
    #expect(layout.nodes.allSatisfy { $0.isUnreachable })
}

@Test func transitionsToUnknownStatesAreSkipped() {
    let layout = MachineLayout(machine(["a", "b"], [("a", "nowhere"), ("nowhere", "b")]))
    #expect(places(layout) == ["a": [0, 0], "b": [1, 0]])
    #expect(layout.node(for: "b")?.isUnreachable == true)
    #expect(layout.node(for: "nowhere") == nil)
}

@Test func anEmptyMachineHasNoNodesAndNoSize() {
    let layout = MachineLayout(machine([], []))
    #expect(layout.nodes.isEmpty)
    #expect(layout.width == 0)
    #expect(layout.height == 0)
}

@Test func goldenPositionsAndSize() {
    let layout = MachineLayout(machine(["a", "b", "c"], [("a", "b"), ("a", "c")]))
    let frames = layout.nodes.map { [$0.x, $0.y] }
    #expect(frames == [[0, 0], [240, 0], [240, 88]])
    #expect(layout.width == 400)
    #expect(layout.height == 144)
}

@Test func theSameMachineAlwaysGivesTheSameLayout() {
    let ids = (0..<20).map { "s\($0)" }
    let edges = (0..<40).map { ("s\(($0 * 7) % 20)", "s\(($0 * 3 + 1) % 20)") }
    let first = MachineLayout(machine(ids, edges, initial: "s0"))
    for _ in 0..<5 {
        #expect(MachineLayout(machine(ids, edges, initial: "s0")) == first)
    }
}

@Test func fiftyStatesNeverOverlap() {
    // A wide fan, a chain and unreachable states, 50 in all.
    let ids = (0..<50).map { "s\($0)" }
    let fan = (1..<20).map { ("s0", "s\($0)") }
    let chain = (20..<40).map { ("s\($0 - 1)", "s\($0)") }
    let layout = MachineLayout(machine(ids, fan + chain, initial: "s0"))
    #expect(layout.nodes.count == 50)
    let w = MachineLayout.nodeWidth, h = MachineLayout.nodeHeight
    for (i, p) in layout.nodes.enumerated() {
        #expect(p.x + w <= layout.width && p.y + h <= layout.height)
        for q in layout.nodes[(i + 1)...] {
            let apart = p.x + w <= q.x || q.x + w <= p.x || p.y + h <= q.y || q.y + h <= p.y
            #expect(apart, "\(p.stateID) overlaps \(q.stateID)")
        }
    }
}
