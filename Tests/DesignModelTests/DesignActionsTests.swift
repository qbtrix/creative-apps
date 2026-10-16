// DesignActionsTests.swift: the workspace actions of DesignActions.swift on
// DesignFixtures.cards (every layer inside Desktop). On `.fake` each command is
// one named step and a refusal records none; the help law holds through the
// workspace; on `.live` one-layer delete, nudge and align keep today's methods;
// on an all-NotBuilt set several layers are refused with the slot's "isn't built yet."; minted
// ids never repeat; Zoom to Selection and Select All. Runs on Linux and macOS.
@testable import DesignModel
import Testing

// cards: Desktop node-1 holds A node-2, B node-3, C node-4, Title node-5, Pair node-6 (E1 node-7,
// E2 node-8), Locked node-9 and Hidden node-10.
private let (desktop, a, b, c, title, pair, locked, hidden) =
    ("node-1", "node-2", "node-3", "node-4", "node-5", "node-6", "node-9", "node-10")

/// `cards` on `services` with `ids` selected (the first replaces the selection, the rest are added).
private func cards(_ services: DesignServices, _ ids: [String]) -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.useServices(services)
    if let first = ids.first { workspace.selectItem(first) }
    for id in ids.dropFirst() { workspace.toggleSelection(id) }
    return workspace
}

private let commands: [DesignCommand] =
    [.duplicate, .group, .ungroup, .delete]
    + DesignDirection.allCases.flatMap { [DesignCommand.nudge($0, large: false), .nudge($0, large: true)] }
    + DesignAlignEdge.allCases.map { .align($0) } + DesignDistributeAxis.allCases.map { .distribute($0) }
    + DesignArrangeStep.allCases.map { .arrange($0) }

private let selections: [[String]] = [[], [a], [a, b], [a, b, c], [locked], [hidden], [pair]]

/// The undo name `.fake` gives `command`.
private func fakeName(_ command: DesignCommand) -> String {
    switch command {
    case .duplicate: "Duplicate"
    case .group: "Group"
    case .ungroup: "Ungroup"
    case .delete: "Delete"
    case .nudge: "Nudge"
    case .align(let edge): edge.title
    case .distribute(let axis): axis.title
    case .arrange(let step): step.title
    }
}

/// What `run` threw; nil when it returned.
private func refusal(_ workspace: inout DesignWorkspace, _ command: DesignCommand) -> DesignRefusal? {
    do { try workspace.run(command) } catch { return error }
    return nil
}

private func allIDs(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + allIDs($0.children) } }

@Suite struct DesignActionsTests {
    @Test func everyFakeCommandRecordsOneNamedStep() throws {
        for command in commands {
            // Pair for Ungroup, B alone for the arrange steps (it can move both ways), else A, B and Pair.
            let ids: [String] = switch command {
            case .ungroup: [pair]
            case .arrange: [b]
            default: [a, b, pair]
            }
            var workspace = cards(.fake, ids)
            #expect(refusal(&workspace, command) == nil, "\(command)")
            #expect(workspace.history.undo.count == 1, "\(command)")
            #expect(workspace.undoActionName == "Undo \(fakeName(command))", "\(command)")
        }
    }

    @Test func aRefusalRecordsNothing() {
        let cases: [([String], DesignCommand, DesignRefusal)] = [
            ([a, b], .distribute(.horizontal), .tooFewToDistribute),
            ([a, "node-7"], .group, .notSameParent),
            ([a], .ungroup, .notAGroup(a)),
            ([], .duplicate, .nothingSelected),
        ]
        for (ids, command, expected) in cases {
            var workspace = cards(.fake, ids)
            let before = workspace
            #expect(refusal(&workspace, command) == expected, "\(command)")
            #expect(workspace == before && workspace.history.undo.isEmpty, "\(command)")
        }
    }

    @Test func theHelpLawHoldsThroughTheWorkspace() {
        for services in [DesignServices.fake, .live] {
            for ids in selections {
                for command in commands {
                    var workspace = cards(services, ids)
                    let help = workspace.help(command)
                    let thrown = refusal(&workspace, command)
                    let label = "\(services.name) \(ids) \(command)"
                    if help == nil {
                        #expect(thrown == nil || thrown == .unchanged, "\(label)")
                    } else {
                        #expect(thrown != nil, "\(label)")
                        // Through a service the refusal is the one the help names.
                        if ids.count > 1, let thrown, thrown != .unchanged { #expect(thrown.help == help, "\(label)") }
                    }
                }
            }
        }
    }

    @Test func nothingSelectedSaysSelectALayerFirst() {
        let workspace = cards(.live, [])
        for command in commands { #expect(workspace.help(command) == "Select a layer first.", "\(command)") }
        #expect(workspace.zoomToSelectionRect == nil)
        #expect(workspace.zoomToSelectionHelp == "Select a layer first.")
        #expect(workspace.transformHelp == "Select a layer first.")
    }

    @Test func oneLayerKeepsTodaysMethodsOnLive() throws {
        var workspace = cards(.live, [a])
        #expect(workspace.help(.delete) == nil)
        try workspace.run(.delete)
        #expect(workspace.undoActionName == "Undo Delete Rectangle" && workspace.selectedNodeIDs.isEmpty)
        #expect(workspace.selectedPage?.nodes.node(a) == nil)
        for direction in DesignDirection.allCases {
            for large in [false, true] {
                var nudged = cards(.live, [a])
                #expect(nudged.help(.nudge(direction, large: large)) == nil)
                try nudged.run(.nudge(direction, large: large))
                let frame = nudged.selectedPage?.nodes.node(a)?.frame
                let step = large ? 10.0 : 1.0
                let expected: DesignRect = switch direction {
                case .up: rc(100, 100 - step, 100, 80)
                case .down: rc(100, 100 + step, 100, 80)
                case .left: rc(100 - step, 100, 100, 80)
                case .right: rc(100 + step, 100, 100, 80)
                }
                #expect(frame == expected && nudged.undoActionName == "Undo Nudge" && nudged.history.undo.count == 1)
            }
        }
        for edge in DesignAlignEdge.allCases {
            var aligned = cards(.live, [a])
            #expect(aligned.help(.align(edge)) == nil)
            try aligned.run(.align(edge))
            #expect(aligned.undoActionName == "Undo \(edge.title)" && aligned.history.undo.count == 1)
        }
        // Today's one-layer helps: a locked layer, and a layer already at the edge.
        var stuck = cards(.live, [locked])
        #expect(stuck.help(.delete) == "Unlock the layer to edit it.")
        #expect(refusal(&stuck, .nudge(.left, large: false)) == .locked("Locked") && stuck.history.undo.isEmpty)
        var lined = cards(.live, [a])
        try lined.run(.align(.left))
        #expect(lined.help(.align(.left)) == "The layer is already at the left edge.")
        #expect(refusal(&lined, .align(.left)) == .unchanged && lined.history.undo.count == 1)
    }

    @Test func severalLayersOnNotBuiltAreRefused() {
        let notBuilt = DesignNotBuiltTests.notBuilt
        let several: [(DesignCommand, String)] =
            [(.delete, "Editing several layers")]
            + DesignDirection.allCases.map { (.nudge($0, large: false), "Editing several layers") }
            + DesignAlignEdge.allCases.map { (.align($0), "Aligning several layers") }
        for (command, feature) in several {
            var workspace = cards(notBuilt, [a, b])
            let before = workspace
            #expect(workspace.help(command) == "\(feature) isn't built yet.", "\(command)")
            #expect(refusal(&workspace, command) == .notBuilt(feature), "\(command)")
            #expect(workspace == before && workspace.history.undo.isEmpty, "\(command)")
        }
        #expect(cards(notBuilt, [a, b]).transformHelp == "Editing several layers isn't built yet.")
        #expect(cards(notBuilt, [a]).transformHelp == nil)
    }

    @Test func mintNeverHandsOutAHeldID() throws {
        var workspace = cards(.fake, [a, b])
        try workspace.run(.duplicate)
        let held = Set(allIDs(workspace.pages.flatMap(\.nodes)) + workspace.pages.map(\.id))
        #expect(held.count == 13 && workspace.held.ids == held)
        workspace.undo()
        var mint = workspace.mint()
        for _ in 0..<20 {
            let id = mint.nextNodeID()
            #expect(!held.contains(id), "\(id)")
        }
        // A file whose ids skip numbers: the mint skips every id the file holds.
        var gappy = DesignWorkspace()
        gappy.load([DesignPage(id: "page-1", name: "Page 1", frameWidth: 10, frameHeight: 10, nodes: [
            DesignNode(id: "node-3", name: "R", kind: .rectangle, frame: rc(0, 0, 1, 1)),
            DesignNode(id: "node-1000000001", name: "Far", kind: .rectangle, frame: rc(0, 0, 1, 1)),
        ])])
        gappy.nodeCount = 0
        var gappyMint = gappy.mint()
        let minted = (0..<4).map { _ in gappyMint.nextNodeID() }
        #expect(minted == ["node-1", "node-2", "node-4", "node-5"])
    }

    @Test func applyRecordsOneStepAndTakesTheMint() throws {
        var workspace = cards(.fake, [a])
        try workspace.run(.duplicate)
        try workspace.run(.duplicate)
        #expect(workspace.history.undo.count == 2 && workspace.selectedNodeIDs == ["node-12"])
        // A coalescing edit merges into the run with its key.
        var nudged = cards(.fake, [a, b])
        try nudged.run(.nudge(.left, large: false))
        try nudged.run(.nudge(.left, large: true))
        #expect(nudged.history.undo.count == 1 && nudged.selectedPage?.nodes.node(a)?.frame.x == 89)
    }

    @Test func zoomToSelectionFollowsTheFraming() {
        let workspace = cards(.fake, [a, b])
        #expect(workspace.zoomToSelectionRect == rc(100, 100, 400, 120) && workspace.zoomToSelectionHelp == nil)
        #expect(cards(DesignNotBuiltTests.notBuilt, [a]).zoomToSelectionHelp == "Zoom to Selection isn't built yet.")
        #expect(cards(DesignNotBuiltTests.notBuilt, [a]).zoomToSelectionRect == nil)
        #expect(cards(.live, [a]).zoomToSelectionRect == rc(100, 100, 100, 80))
    }

    @Test func selectAllSelectsTheVisibleUnlockedLayersAtTheSelectionsLevel() {
        var top = cards(.live, [])
        top.selectAll()
        #expect(top.selectedNodeIDs == [desktop])
        var inner = cards(.live, [a])
        inner.selectAll()
        #expect(inner.selectedNodeIDs == [a, b, c, title, pair])
        #expect(inner.history.undo.isEmpty)
    }
}
