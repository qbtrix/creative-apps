// MachineLayout.swift: where the Interactions editor draws each state of a
// FlareCore state machine (docs/blueprints/flare.md, section 2, task LM-15).
// FlareCore's MachineState has no position, so the layout comes from the
// machine alone: a state's column is its breadth-first distance from the
// initial state, its row is its order in `states` within that column, and
// states the initial state can't reach share one column after the rest.
// The same machine always gives the same layout.
import FlareCore

/// The graph layout of one state machine, in points from the top-left corner.
public struct MachineLayout: Equatable, Sendable {
    /// One state's box.
    public struct Node: Equatable, Sendable {
        public let stateID: String
        public let column: Int
        public let row: Int
        /// True when no chain of transitions leads here from the initial state.
        public let isUnreachable: Bool

        public var x: Double { Double(column) * (MachineLayout.nodeWidth + MachineLayout.columnGap) }
        public var y: Double { Double(row) * (MachineLayout.nodeHeight + MachineLayout.rowGap) }
    }

    public static let nodeWidth = 160.0
    public static let nodeHeight = 56.0
    public static let columnGap = 80.0
    public static let rowGap = 32.0

    /// One node per state, in the machine's state order.
    public let nodes: [Node]

    public init(_ machine: StateMachine) {
        let distance = Self.distances(machine)
        // Unreachable states go one column past the farthest reachable one,
        // or into column 0 when nothing is reachable.
        let trailing = distance.values.max().map { $0 + 1 } ?? 0
        var rowsUsed: [Int: Int] = [:]
        nodes = machine.states.map { state in
            let column = distance[state.id] ?? trailing
            let row = rowsUsed[column, default: 0]
            rowsUsed[column] = row + 1
            return Node(stateID: state.id, column: column, row: row,
                        isUnreachable: distance[state.id] == nil)
        }
    }

    /// The node for a state, or nil if the machine has no such state.
    public func node(for stateID: String) -> Node? {
        nodes.first { $0.stateID == stateID }
    }

    /// The width and height the whole graph needs; zero for an empty machine.
    public var width: Double {
        guard let last = nodes.map(\.column).max() else { return 0 }
        return Double(last + 1) * Self.nodeWidth + Double(last) * Self.columnGap
    }

    public var height: Double {
        guard let last = nodes.map(\.row).max() else { return 0 }
        return Double(last + 1) * Self.nodeHeight + Double(last) * Self.rowGap
    }

    /// Breadth-first distance from the initial state to each reachable state.
    /// Transitions naming a state the machine doesn't have are skipped.
    private static func distances(_ machine: StateMachine) -> [String: Int] {
        let known = Set(machine.states.map(\.id))
        guard known.contains(machine.initialState) else { return [:] }
        var targets: [String: [String]] = [:]
        for transition in machine.transitions where known.contains(transition.to) {
            targets[transition.from, default: []].append(transition.to)
        }
        var distance = [machine.initialState: 0]
        var queue = [machine.initialState]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            let next = distance[current, default: 0] + 1
            for target in targets[current, default: []] where distance[target] == nil {
                distance[target] = next
                queue.append(target)
            }
        }
        return distance
    }
}
