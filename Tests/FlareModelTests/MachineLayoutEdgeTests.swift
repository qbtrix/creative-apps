// MachineLayoutEdgeTests.swift: adversarial cases for MachineLayout. Transition
// order, self loops, repeated edges and edges out of unreachable states must not
// move a node; worst-case 50-state shapes never overlap and stay inside the
// graph's size. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func graph(_ count: Int, _ edges: [(Int, Int)], initial: Int = 0) -> StateMachine {
    StateMachine(
        id: "edge", name: "Edge",
        states: (0..<count).map { MachineState(id: "n\($0)", name: "n\($0)", sceneID: "scene-1",
                                               startFrame: 0, endFrame: 1) },
        transitions: edges.map { FlareTransition(from: "n\($0.0)", to: "n\($0.1)", trigger: "go") },
        initialState: "n\(initial)")
}

private func columns(_ layout: MachineLayout) -> [Int] { layout.nodes.map(\.column) }

/// Every pair of boxes is apart, and every box fits in width x height.
private func isClean(_ layout: MachineLayout) -> Bool {
    let w = MachineLayout.nodeWidth, h = MachineLayout.nodeHeight
    let boxes = layout.nodes
    for (i, p) in boxes.enumerated() {
        guard p.x >= 0, p.y >= 0, p.x + w <= layout.width, p.y + h <= layout.height else { return false }
        for q in boxes[(i + 1)...] {
            if !(p.x + w <= q.x || q.x + w <= p.x || p.y + h <= q.y || q.y + h <= p.y) { return false }
        }
    }
    return true
}

/// A small deterministic generator, so the fuzz cases are the same every run.
private struct Lcg {
    var seed: UInt64
    mutating func next(_ bound: Int) -> Int {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((seed >> 33) % UInt64(bound))
    }
}

@Test func transitionOrderNeverMovesANode() {
    var rng = Lcg(seed: 7)
    let edges = (0..<60).map { _ in (rng.next(30), rng.next(30)) }
    let base = MachineLayout(graph(30, edges))
    for _ in 0..<10 {
        var shuffled = edges
        for i in shuffled.indices.reversed() { shuffled.swapAt(i, rng.next(i + 1)) }
        #expect(MachineLayout(graph(30, shuffled)) == base)
    }
}

@Test func selfLoopsAndRepeatedEdgesChangeNothing() {
    let plain = MachineLayout(graph(3, [(0, 1), (1, 2)]))
    let noisy = MachineLayout(graph(3, [(0, 0), (0, 1), (0, 1), (1, 1), (1, 2), (2, 2), (1, 2)]))
    #expect(noisy == plain)
    #expect(columns(plain) == [0, 1, 2])
}

@Test func edgesOutOfUnreachableStatesDoNotPullReachableOnesBack() {
    // n3 is unreachable but points at n2 and n1; their columns stay by distance from n0.
    let layout = MachineLayout(graph(4, [(0, 1), (1, 2), (3, 1), (3, 2)]))
    #expect(columns(layout) == [0, 1, 2, 3])
    #expect(layout.nodes.map(\.isUnreachable) == [false, false, false, true])
}

@Test func anInitialStateLaterInTheListStillGetsColumnZero() {
    let layout = MachineLayout(graph(3, [(2, 0), (0, 1)], initial: 2))
    #expect(columns(layout) == [1, 2, 0])
    #expect(layout.node(for: "n2")?.row == 0)
}

@Test func onlyTheInitialStateReachableSendsTheRestToColumnOne() {
    let layout = MachineLayout(graph(5, []))
    #expect(columns(layout) == [0, 1, 1, 1, 1])
    #expect(layout.nodes.map(\.row) == [0, 0, 1, 2, 3])
    #expect(layout.width == 2 * MachineLayout.nodeWidth + MachineLayout.columnGap)
}

@Test func worstCaseFiftyStateShapesStayCleanAndSized() {
    let chain = (1..<50).map { ($0 - 1, $0) }
    let star = (1..<50).map { (0, $0) }
    let shapes: [MachineLayout] = [
        MachineLayout(graph(50, chain)),
        MachineLayout(graph(50, star)),
        MachineLayout(graph(50, chain, initial: 49)),
        MachineLayout(graph(50, chain.map { ($0.1, $0.0) }, initial: 49)),
    ]
    for layout in shapes {
        #expect(layout.nodes.count == 50)
        #expect(isClean(layout))
        let lastColumn = layout.nodes.map(\.column).max() ?? 0
        let lastRow = layout.nodes.map(\.row).max() ?? 0
        #expect(layout.width == Double(lastColumn + 1) * MachineLayout.nodeWidth
            + Double(lastColumn) * MachineLayout.columnGap)
        #expect(layout.height == Double(lastRow + 1) * MachineLayout.nodeHeight
            + Double(lastRow) * MachineLayout.rowGap)
    }
    #expect(columns(shapes[0]) == Array(0..<50))
    #expect(shapes[2].nodes.filter(\.isUnreachable).count == 49)
    #expect(columns(shapes[3]) == (0..<50).map { 49 - $0 })
}

@Test func fuzzedMachinesAreCleanWithShortestColumns() {
    var rng = Lcg(seed: 42)
    for _ in 0..<200 {
        let count = 1 + rng.next(50)
        let edges = (0..<rng.next(120)).map { _ in (rng.next(count), rng.next(count)) }
        let layout = MachineLayout(graph(count, edges, initial: rng.next(count)))
        #expect(isClean(layout))
        let ids = Set(layout.nodes.map(\.stateID))
        #expect(ids.count == count)
        // A transition between reachable states never skips more than one column forward.
        for (from, to) in edges {
            guard let a = layout.node(for: "n\(from)"), let b = layout.node(for: "n\(to)"),
                  !a.isUnreachable else { continue }
            #expect(!b.isUnreachable && b.column <= a.column + 1)
        }
        // Rows within a column are 0, 1, 2, ... in state order.
        for column in Set(layout.nodes.map(\.column)) {
            #expect(layout.nodes.filter { $0.column == column }.map(\.row)
                == Array(0..<layout.nodes.filter { $0.column == column }.count))
        }
    }
}

@Test func aLongChainLaysOutWithoutBlowingUp() {
    let count = 5_000
    let layout = MachineLayout(graph(count, (1..<count).map { ($0 - 1, $0) }))
    #expect(layout.nodes.last?.column == count - 1)
    #expect(layout.height == MachineLayout.nodeHeight)
}
