// DesignTextFitTests.swift: a text box fits its text (canvas-basics CB-5, packet
// docs/blueprints/design/features/canvas-basics.md, the CB-5 acceptance row).
// `commitTextEdit(extent:)` fits the box in the commit's own step: auto width
// takes both sides, fixed width only the height, rounded up. `setTextStyle`
// refits by the size's ratio in the "Change Text Style" step and keeps each
// layer's own `fixedWidth`. On `cards` with the live services. Runs on Linux
// and macOS.
@testable import DesignModel
import Testing

// cards: Title node-5 is an auto-width text, 200 × 32 at size 16.
private let title = "node-5"

@Suite struct DesignTextFitTests {
    /// `cards` on `.live` after a Text gesture from `start` to `end`, the edit still open.
    private func place(_ start: DesignPoint, _ end: DesignPoint) throws -> (DesignWorkspace, String) {
        var workspace = DesignFixtures.cards
        #expect(workspace.services == .live)
        workspace.gesture(.text, start, end)
        let node = try #require(workspace.selectedNode)
        return (workspace, node.id)
    }

    private func frame(_ workspace: DesignWorkspace, _ id: String) -> DesignRect? { workspace.treeNode(id)?.frame }
    private func steps(_ workspace: DesignWorkspace) -> [String] { workspace.history.undo.map(\.name) }

    /// `workspace` with `ids` selected, the text size set to `size` keeping the rest of `id`'s style.
    private func setSize(_ size: Double, _ ids: [String], in workspace: inout DesignWorkspace) throws {
        for (index, id) in ids.enumerated() {
            if index == 0 { workspace.selectItem(id) } else { workspace.toggleSelection(id) }
        }
        var style = try #require(workspace.treeNode(ids[0])?.textStyle)
        style.size = size
        try workspace.setStyle(.textStyle(style))
    }

    @Test func aPlacedTextFitsItsExtentInTheAddTextStep() throws {
        var (workspace, id) = try place(pt(200, 300), pt(200, 300))
        workspace.setTextDraft("Hello there")
        workspace.commitTextEdit(extent: DesignTextExtent(width: 150.2, height: 19.1))
        #expect(frame(workspace, id) == rc(200, 300, 151, 20))
        #expect(steps(workspace) == ["Add Text"])
        workspace.undo()
        #expect(workspace.treeNode(id) == nil && !workspace.canUndo)
    }

    @Test func aFixedWidthBoxKeepsItsWidthAndFitsItsHeight() throws {
        var (workspace, id) = try place(pt(200, 300), pt(500, 310))
        #expect(frame(workspace, id) == rc(200, 300, 300, 24))
        workspace.setTextDraft("Two lines of wrapped text")
        workspace.commitTextEdit(extent: DesignTextExtent(width: 280, height: 41.5))
        #expect(frame(workspace, id) == rc(200, 300, 300, 42))
        #expect(steps(workspace) == ["Add Text"])
    }

    @Test func aNilOrNonFiniteExtentKeepsTheFrame() throws {
        for extent in [nil, DesignTextExtent(width: .infinity, height: 20), DesignTextExtent(width: 50, height: .nan)] {
            var (workspace, id) = try place(pt(200, 300), pt(200, 300))
            workspace.setTextDraft("Hello")
            workspace.commitTextEdit(extent: extent)
            #expect(frame(workspace, id) == rc(200, 300, 120, 24))
            #expect(steps(workspace) == ["Add Text"])
        }
    }

    @Test func aTinyExtentGivesAtLeastOnePoint() throws {
        var (workspace, id) = try place(pt(200, 300), pt(200, 300))
        workspace.setTextDraft("i")
        workspace.commitTextEdit(extent: DesignTextExtent(width: 0, height: -3))
        #expect(frame(workspace, id) == rc(200, 300, 1, 1))
    }

    @Test func anExistingTextRefitsInOneEditTextStep() throws {
        var workspace = DesignFixtures.cards
        try workspace.beginTextEdit(title)
        workspace.setTextDraft("Title")
        workspace.commitTextEdit(extent: DesignTextExtent(width: 40.3, height: 19.6))
        #expect(frame(workspace, title) == rc(100, 40, 41, 20))
        #expect(steps(workspace) == ["Edit Text"])
        try workspace.beginTextEdit(title)
        workspace.commitTextEdit(extent: DesignTextExtent(width: 41, height: 20))
        #expect(steps(workspace) == ["Edit Text"])
    }

    @Test func aCancelLeavesTheFrame() throws {
        var workspace = DesignFixtures.cards
        try workspace.beginTextEdit(title)
        workspace.setTextDraft("A much longer title")
        workspace.cancelTextEdit()
        #expect(frame(workspace, title) == rc(100, 40, 200, 32))
        #expect(!workspace.canUndo)
    }

    @Test func aSizeChangeScalesAnAutoWidthBoxInTheStyleStep() throws {
        var workspace = DesignFixtures.cards
        try setSize(32, [title], in: &workspace)
        #expect(frame(workspace, title) == rc(100, 40, 400, 64))
        #expect(workspace.treeNode(title)?.textStyle.size == 32)
        #expect(steps(workspace) == ["Change Text Style"])
        workspace.undo()
        #expect(frame(workspace, title) == rc(100, 40, 200, 32))
    }

    @Test func aSizeChangeKeepsAFixedWidthAndScalesTheHeight() throws {
        var (workspace, id) = try place(pt(200, 300), pt(500, 310))
        workspace.commitTextEdit()
        try setSize(32, [id], in: &workspace)
        #expect(frame(workspace, id) == rc(200, 300, 300, 48))
        #expect(steps(workspace) == ["Add Text", "Change Text Style"])
    }

    @Test func aStyleChangeWithTheSameSizeKeepsTheFrame() throws {
        var workspace = DesignFixtures.cards
        workspace.selectItem(title)
        try workspace.setStyle(.textStyle(DesignTextStyle(family: "Serif", size: 16, weight: 700, alignment: .center)))
        #expect(frame(workspace, title) == rc(100, 40, 200, 32))
    }

    @Test func eachLayerKeepsItsOwnFixedWidthFlag() throws {
        var (workspace, fixed) = try place(pt(200, 300), pt(500, 310))
        workspace.commitTextEdit()
        for ids in [[fixed, title], [title, fixed]] {
            var styled = workspace
            try setSize(24, ids, in: &styled)
            #expect(styled.treeNode(fixed)?.textStyle.fixedWidth == true)
            #expect(styled.treeNode(title)?.textStyle.fixedWidth == nil)
            #expect(frame(styled, fixed) == rc(200, 300, 300, 36) && frame(styled, title) == rc(100, 40, 300, 48))
        }
        var forced = workspace
        forced.selectItem(title)
        try forced.setStyle(.textStyle(DesignTextStyle(family: "System", size: 16, weight: 700, alignment: .leading, fixedWidth: true)))
        #expect(forced.treeNode(title)?.textStyle.fixedWidth == nil)
    }
}
