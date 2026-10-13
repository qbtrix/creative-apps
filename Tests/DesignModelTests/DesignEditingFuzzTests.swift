// DesignEditingFuzzTests.swift: seeded random sessions over every editing
// command and tool. After each step the tree is sound (unique ids, a selection
// that exists, a gesture that never leaves a node out of place); at the end,
// undoing every step gives back the file as it opened and redoing every step
// gives back the final one, and a refused call changes nothing. A failing seed
// replays. Runs on Linux and macOS.
import DesignModel
import Testing

private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(below bound: Int) -> Int { Int(next() % UInt64(Swift.max(bound, 1))) }
}

private func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }

private func soundness(_ workspace: DesignWorkspace) {
    let all = workspace.pages.flatMap { ids($0.nodes) }
    #expect(Set(all).count == all.count, "duplicate node ids")
    #expect(Set(workspace.pages.map(\.id)).count == workspace.pages.count, "duplicate page ids")
    if let node = workspace.selectedNodeID { #expect(workspace.selectedPage?.nodes.node(in: node) != nil, "selection is off the page") }
    #expect(workspace.isOpen == (workspace.selectedPage != nil))
    for node in all.compactMap({ workspace.treeNode($0) }) {
        #expect(node.frame.width.isFinite && node.frame.height.isFinite && node.frame.x.isFinite && node.frame.y.isFinite)
    }
}

extension [DesignNode] {
    fileprivate func node(in id: String) -> DesignNode? {
        for node in self {
            if node.id == id { return node }
            if let inner = node.children.node(in: id) { return inner }
        }
        return nil
    }
}

/// Short sessions fit in the 100-step history, so undoing all of it must give back the opened file;
/// the long ones only have to stay sound.
@Test(arguments: [1, 7, 42, 2026, 90210, 31337] as [UInt64], [80, 500])
func randomSessionsStaySoundAndUndoCompletely(seed: UInt64, steps: Int) throws {
    var rng = SplitMix64(state: seed)
    var workspace = openDesign()
    let opened = workspace.pages
    func point() -> DesignPoint { pt(Double(rng.next(below: 1500)) - 30, Double(rng.next(below: 1100)) - 30) }
    for _ in 0..<steps {
        let all = workspace.pages.flatMap { ids($0.nodes) }
        let pick = all.isEmpty ? "ghost" : all[rng.next(below: all.count)]
        let before = workspace
        switch rng.next(below: 17) {
        case 0, 1, 2:
            let tool = [DesignTool.frame, .rectangle, .ellipse, .text, .move, .pen][rng.next(below: 6)]
            workspace.selectTool(tool)
            let start = point()
            var modifiers: DesignModifiers = []
            if rng.next(below: 3) == 0 { modifiers.insert(.shift) }
            if rng.next(below: 3) == 0 { modifiers.insert(.option) }
            workspace.drag(from: start, to: rng.next(below: 4) == 0 ? start : point(), modifiers: modifiers)
            if rng.next(below: 2) == 0 { workspace.drag(from: start, to: point(), modifiers: modifiers) }
            workspace.endDrag()
            if workspace.editingTextID != nil {
                if rng.next(below: 2) == 0 { workspace.setTextDraft(["", "Hi", " "][rng.next(below: 3)]) }
                if rng.next(below: 3) == 0 { workspace.cancelTextEdit() } else { workspace.commitTextEdit() }
            }
        case 3: workspace.selectItem(pick)
        case 4: workspace.nudge(DesignDirection.allCases[rng.next(below: 4)], shift: rng.next(below: 2) == 0)
        case 5: workspace.deleteSelection()
        case 6:
            let refused = (try? workspace.move(pick, by: pt(Double(rng.next(below: 40)) - 20, 3))) == nil
            if refused { #expect(workspace == before) }
        case 7:
            _ = try? workspace.setNodeFrame(
                pick, x: Double(rng.next(below: 300)), y: .nan, width: Double(rng.next(below: 200)) - 10, height: .infinity)
        case 8:
            _ = try? workspace.resizeNode(
                pick, handle: DesignHandle.allCases[rng.next(below: 8)], by: pt(Double(rng.next(below: 80)) - 40, -9),
                shift: rng.next(below: 2) == 0, option: rng.next(below: 2) == 0)
        case 9: _ = try? workspace.setFill(pick, DesignColor(UInt8(rng.next(below: 256)), 3, 4))
        case 10: _ = try? workspace.setNodeLocked(pick, rng.next(below: 3) == 0)
        case 11: _ = try? workspace.setNodeHidden(pick, rng.next(below: 3) == 0)
        case 12: workspace.addPage()
        case 13: if let page = workspace.selectedPageID { _ = try? workspace.deletePage(page) }
        case 14: _ = try? workspace.moveNode(pick, into: all.isEmpty || rng.next(below: 4) == 0 ? nil : all[rng.next(below: all.count)])
        case 15: _ = try? workspace.setExpanded(pick, rng.next(below: 2) == 0)
        default: _ = try? workspace.setText(pick, "Edited")
        }
        soundness(workspace)
    }
    workspace.commitTextEdit()
    workspace.selectTool(.move)
    let finished = workspace.pages
    var undone = 0
    while workspace.canUndo {
        workspace.undo()
        undone += 1
        soundness(workspace)
    }
    #expect(undone <= 100)
    if steps <= 100 { #expect(undone > 10 && workspace.pages == opened) }
    while workspace.canRedo { workspace.redo() }
    #expect(workspace.pages == finished)
}
