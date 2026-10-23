// DesignSnapWalkTests.swift: journey MJ11 `walkSnapping` on `cards`: each gesture snapped and
// under `.noSnap`, one undo step each (SN-4 moves, SN-5 resizes and draws). Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignSnapWalkTests {
    static let (a, b) = ("node-2", "node-3")

    /// One gesture on a fresh `cards` with `ids` selected, checked to be one undo step named `step`.
    func walk(_ tool: DesignTool, _ ids: [String], _ start: DesignPoint, _ end: DesignPoint,
              _ modifiers: DesignModifiers = [], step: String = "Move", at: SourceLocation = #_sourceLocation
    ) -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        for (index, id) in ids.enumerated() {
            if index == 0 { workspace.selectItem(id) } else { workspace.toggleSelection(id) }
        }
        let steps = workspace.history.undo.count
        workspace.selectTool(tool)
        workspace.drag(from: start, to: end, modifiers: modifiers)
        workspace.endDrag()
        if tool == .text { workspace.commitTextEdit() }  // A Text box's step lands when its edit ends.
        #expect(workspace.history.undo.count == steps + 1 && workspace.undoActionName == "Undo \(step)", sourceLocation: at)
        #expect(workspace.snapGuides == nil, sourceLocation: at)
        return workspace
    }

    @Test func walkSnapping() throws {
        let (a, ab, press, right, down) = (Self.a, [Self.a, Self.b], pt(150, 140), pt(347.4, 140.4), pt(150, 417.6))
        // A move onto B's left edge (297 under ⌘); several and a copy onto Pair's bottom at y 500.
        #expect(walk(.move, [a], press, right).frame(a) == rc(300, 100, 100, 80))
        #expect(walk(.move, [a], press, right, .noSnap).frame(a) == rc(297, 100, 100, 80))
        #expect(walk(.move, ab, press, down).frame(Self.b) == rc(300, 420, 200, 80))
        #expect(walk(.move, ab, press, down, .noSnap).frame(a) == rc(100, 378, 100, 80))
        let copied = walk(.move, ab, press, down, .option, step: "Duplicate")
        let copies = try #require(copied.selectedPage?.nodes.first?.children).filter { $0.name == "A" }
        #expect(copies.map(\.frame) == [rc(100, 100, 100, 80), rc(100, 380, 100, 80)])

        // A resize from A's bottom-right: W 200 (198 under ⌘); Shift keeps the aspect, Option the centre.
        let (corner, to) = (pt(200, 180), pt(297.6, 180.4))
        #expect(walk(.move, [a], corner, to, step: "Resize").frame(a) == rc(100, 100, 200, 80))
        #expect(walk(.move, [a], corner, to, .noSnap, step: "Resize").frame(a) == rc(100, 100, 198, 80))
        #expect(walk(.move, [a], corner, to, .shift, step: "Resize").frame(a) == rc(100, 100, 200, 160))
        #expect(walk(.move, [a], corner, to, .option, step: "Resize").frame(a) == rc(0, 100, 300, 80))

        // A rectangle draw and a Text click-drag snap their start and end.
        let (from, end) = (pt(497.5, 137.6), pt(697.2, 222.3))
        #expect(walk(.rectangle, [], from, end, step: "Add Rectangle").selectedNode?.frame == rc(500, 140, 200, 80))
        #expect(walk(.rectangle, [], from, end, .noSnap, step: "Add Rectangle").selectedNode?.frame == rc(498, 138, 199, 84))
        let text = walk(.text, [], from, pt(697.2, 160), step: "Add Text").selectedNode?.frame
        #expect(text?.x == 500 && text?.width == 200)
    }
}
