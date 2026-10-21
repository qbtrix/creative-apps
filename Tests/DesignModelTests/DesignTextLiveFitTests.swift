// DesignTextLiveFitTests.swift: canvas-basics CB-b findings. While a text edit
// is open, the size badge, its anchor, the inspector header and the frame rows
// read the box its commit will fit to the draft's measured extent (#3335);
// typing at a zoom where the text draws under 9 pt on screen asks for a zoom-in
// (#3336); a text style that differs from a layer's only in its width mode
// switches that mode as one "Change Text Style" step (#3337). On `cards` with
// the live services. Runs on Linux and macOS.
@testable import DesignModel
import Testing

// cards: Title node-5 is an auto-width text, 200 × 32 at size 16.
private let title = "node-5"

@Suite struct DesignTextLiveFitTests {
    /// `cards` after a Text gesture from `start` to `end`, the edit still open.
    private func place(_ start: DesignPoint, _ end: DesignPoint) throws -> (DesignWorkspace, DesignNode) {
        var workspace = DesignFixtures.cards
        workspace.gesture(.text, start, end)
        return (workspace, try #require(workspace.selectedNode))
    }

    private func steps(_ workspace: DesignWorkspace) -> [String] { workspace.history.undo.map(\.name) }

    @Test func theBadgeAndInspectorFollowTheDraftWhileTyping() throws {
        var (workspace, node) = try place(pt(72, 870), pt(72, 870))
        workspace.setTextDraft("A longer line of text")
        let extent = DesignTextExtent(width: 160.2, height: 19)
        #expect(workspace.selectionBadge == "120 × 24")
        #expect(workspace.selectionBadge(draft: extent) == "161 × 19")
        #expect(workspace.selectionBadgeAnchor(draft: extent) == pt(72 + 80.5, 889))
        #expect(workspace.liveFrame(of: node, draft: extent) == rc(72, 870, 161, 19))
        #expect(workspace.inspectorDetails(of: node, draft: extent).last == "161 × 19 pt")
        workspace.commitTextEdit(extent: extent)
        #expect(workspace.selectionBadge == "161 × 19")
        #expect(workspace.selectedNode?.inspectorDetails.last == "161 × 19 pt")
    }

    @Test func aFixedWidthDraftGrowsOnlyDown() throws {
        var (workspace, node) = try place(pt(200, 300), pt(500, 310))
        workspace.setTextDraft("Two lines of wrapped text")
        #expect(workspace.selectionBadge(draft: DesignTextExtent(width: 280, height: 41.5)) == "300 × 42")
        #expect(workspace.liveFrame(of: node, draft: DesignTextExtent(width: 280, height: 41.5)) == rc(200, 300, 300, 42))
    }

    @Test func withNoEditTheDraftChangesNothing() throws {
        var workspace = DesignFixtures.cards
        workspace.selectItem(title)
        let node = try #require(workspace.selectedNode)
        let extent = DesignTextExtent(width: 999, height: 99)
        #expect(workspace.liveFrame(of: node, draft: extent) == node.frame)
        #expect(workspace.selectionBadge(draft: extent) == "200 × 32")
        #expect(workspace.selectionBadgeAnchor(draft: extent) == workspace.selectionBadgeAnchor)
        #expect(workspace.inspectorDetails(of: node, draft: extent) == node.inspectorDetails)
    }

    @Test func aDraftTooSmallToReadAsksForAZoomIn() throws {
        var workspace = DesignFixtures.cards
        #expect(workspace.textLegibilityHint(zoom: 0.25) == nil)
        try workspace.beginTextEdit(title)
        #expect(workspace.textLegibilityHint(zoom: 0.25) == "Zoom in to read text")
        #expect(workspace.textLegibilityHint(zoom: 0.5) == "Zoom in to read text")
        #expect(workspace.textLegibilityHint(zoom: 0.5625) == nil)
        #expect(workspace.textLegibilityHint(zoom: 1) == nil)
        workspace.commitTextEdit()
        #expect(workspace.textLegibilityHint(zoom: 0.25) == nil)
    }

    @Test func aWidthModeOnlyStyleSwitchesTheModeInOneStep() throws {
        var (workspace, node) = try place(pt(200, 300), pt(500, 310))
        workspace.commitTextEdit()
        var auto = node.textStyle
        auto.fixedWidth = false
        try workspace.setStyle(.textStyle(auto))
        #expect(workspace.treeNode(node.id)?.textStyle.fixedWidth == nil)
        #expect(workspace.treeNode(node.id)?.frame == rc(200, 300, 300, 24))
        #expect(steps(workspace) == ["Add Text", "Change Text Style"])
        workspace.undo()
        #expect(workspace.treeNode(node.id)?.textStyle.fixedWidth == true)
        workspace.selectItem(title)
        try workspace.setStyle(.textStyle(DesignTextStyle(family: "System", size: 16, weight: 400, alignment: .leading, fixedWidth: true)))
        #expect(workspace.treeNode(title)?.textStyle.fixedWidth == true)
    }

    @Test func aWidthModeSwitchSetsEverySelectedText() throws {
        var (workspace, node) = try place(pt(200, 300), pt(500, 310))
        workspace.commitTextEdit()
        workspace.selectItem(node.id)
        workspace.toggleSelection(title)
        try workspace.setStyle(.textStyle(DesignTextStyle.default))
        #expect(workspace.treeNode(node.id)?.textStyle.fixedWidth == nil)
        #expect(workspace.treeNode(title)?.textStyle.fixedWidth == nil)
        var fixed = DesignTextStyle.default
        fixed.fixedWidth = true
        try workspace.setStyle(.textStyle(fixed))
        #expect(workspace.treeNode(node.id)?.textStyle.fixedWidth == true)
        #expect(workspace.treeNode(title)?.textStyle.fixedWidth == true)
    }
}
