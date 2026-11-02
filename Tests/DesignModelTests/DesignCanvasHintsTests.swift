// DesignCanvasHintsTests.swift: what the canvas shows before a click (DesignCanvasHints):
// the pointer each hint names, what hover(at:) picks, the Text tool's box and the
// selection badge's text. Runs on Linux and macOS.
import DesignModel
import Testing

/// `cards` with A (node-2, 100 100 100 80) selected.
private func withA() -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.selectItem("node-2")
    return workspace
}

@Test func pointerNamesAreTheAccessibilityValues() {
    #expect(DesignPointerHint.tool.name == "tool")
    #expect(DesignPointerHint.move.name == "move")
    #expect(DesignPointerHint.copy.name == "copy")
    #expect(DesignPointerHint.text.name == "text")
    #expect(DesignPointerHint.resize(.bottomRight).name == "resize-bottom-right")
    #expect(DesignPointerHint.resize(.topLeft).name == "resize-top-left")
    #expect(DesignPointerHint.resize(.top).name == "resize-top")
    #expect(DesignPointerHint.resize(.left).name == "resize-left")
}

@Test func everyHandleHasItsOwnResizeName() {
    let names = Set(DesignHandle.allCases.map { DesignPointerHint.resize($0).name })
    #expect(names.count == DesignHandle.allCases.count)
    #expect(names.subtracting(["rotate"]).allSatisfy { $0.hasPrefix("resize-") })
    #expect(names.contains("rotate"))
}

@Test func aMovePressOverALayerPicksIt() {
    let hover = DesignFixtures.cards.hover(at: pt(150, 140), modifiers: [])
    #expect(hover.nodeID == "node-2")
    #expect(hover.outline == rc(100, 100, 100, 80))
    #expect(hover.pointer == .move)
}

@Test func bareCanvasInsideTheDesktopPicksTheDesktop() {
    let hover = DesignFixtures.cards.hover(at: pt(50, 500), modifiers: [])
    #expect(hover.nodeID == "node-1")
    #expect(hover.outline == rc(0, 0, 1440, 1024))
    #expect(hover.pointer == .move)
}

@Test func pastThePageThereIsNoOutlineAndTheToolPointer() {
    let hover = DesignFixtures.cards.hover(at: pt(2000, 2000), modifiers: [])
    #expect(hover.nodeID == nil)
    #expect(hover.outline == nil)
    #expect(hover.pointer == .tool)
}

@Test func aLockedLayerIsNeverPickedTheLayerUnderIt() {
    // "Locked" (node-9) covers 400...500 by 600...700; the Desktop under it is picked.
    let hover = DesignFixtures.cards.hover(at: pt(450, 650), modifiers: [])
    #expect(hover.nodeID == "node-1")
}

@Test func aHiddenLayerIsNeverPicked() {
    // "Hidden" (node-10) covers 600...700 by 600...700 and is hidden.
    let hover = DesignFixtures.cards.hover(at: pt(650, 650), modifiers: [])
    #expect(hover.nodeID == "node-1")
}

@Test func aChildOfAGroupIsPickedNotTheGroup() {
    // E1 (node-7) sits inside the group Pair (node-6); the group's blank part picks the group.
    let child = DesignFixtures.cards.hover(at: pt(950, 450), modifiers: [])
    #expect(child.nodeID == "node-7")
    #expect(child.outline == rc(900, 400, 100, 100))
    let group = DesignFixtures.cards.hover(at: pt(1050, 420), modifiers: [])
    #expect(group.nodeID == "node-6")
    #expect(group.outline == rc(900, 400, 300, 100))
}

@Test func optionMakesTheMovePointerACopyPointer() {
    let hover = DesignFixtures.cards.hover(at: pt(150, 140), modifiers: [.option])
    #expect(hover.nodeID == "node-2")
    #expect(hover.pointer == .copy)
}

@Test func withoutASelectionACornerOfALayerIsAMovePointer() {
    // No handles show without a selection, so the press over A's corner moves it.
    let hover = DesignFixtures.cards.hover(at: pt(200, 180), modifiers: [])
    #expect(hover.nodeID == "node-2")
    #expect(hover.pointer == .move)
}

@Test func aHandleOfTheSelectionShowsItsResizePointer() {
    let hover = withA().hover(at: pt(200, 180), modifiers: [])
    #expect(hover.nodeID == "node-2")
    #expect(hover.outline == rc(100, 100, 100, 80))
    #expect(hover.pointer == .resize(.bottomRight))
}

@Test func aHandleBeatsCopy() {
    let hover = withA().hover(at: pt(200, 180), modifiers: [.option])
    #expect(hover.pointer == .resize(.bottomRight))
}

@Test func drawingToolsShowNoOutlineAndTheToolPointer() {
    for tool in [DesignTool.frame, .rectangle, .ellipse, .pen] {
        var workspace = withA()
        workspace.selectTool(tool)
        let hover = workspace.hover(at: pt(150, 140), modifiers: [])
        #expect(hover.nodeID == nil)
        #expect(hover.outline == nil)
        #expect(hover.pointer == .tool)
    }
}

@Test func theTextToolShowsItsBoxAtThePoint() {
    var workspace = DesignFixtures.cards
    workspace.selectTool(.text)
    let hover = workspace.hover(at: pt(300, 400), modifiers: [])
    #expect(hover.nodeID == nil)
    #expect(hover.outline == rc(300, 400, 120, 24))
    #expect(hover.pointer == .text)
}

@Test func theTextBoxIsShownOverALayerToo() {
    var workspace = DesignFixtures.cards
    workspace.selectTool(.text)
    let hover = workspace.hover(at: pt(150, 140), modifiers: [])
    #expect(hover.nodeID == nil)
    #expect(hover.outline == rc(150, 140, 120, 24))
    #expect(hover.pointer == .text)
}

@Test func aNilPointGivesNoOutlineAndTheToolPointer() {
    var workspace = DesignFixtures.cards
    let hover = workspace.hover(at: nil, modifiers: [])
    #expect(hover.nodeID == nil)
    #expect(hover.outline == nil)
    #expect(hover.pointer == .tool)
    workspace.selectTool(.text)
    let text = workspace.hover(at: nil, modifiers: [])
    #expect(text.outline == nil)
    #expect(text.pointer == .tool)
}

@Test func aNonFinitePointGivesNothing() {
    var text = DesignFixtures.cards
    text.selectTool(.text)
    for point in [pt(.nan, 0), pt(.infinity, 0), pt(0, -.infinity)] {
        for workspace in [DesignFixtures.cards, text] {
            let hover = workspace.hover(at: point, modifiers: [])
            #expect(hover.nodeID == nil)
            #expect(hover.outline == nil)
            #expect(hover.pointer == .tool)
        }
    }
}

@Test func aLiveGestureGivesNoOutlineAndTheToolPointer() {
    var workspace = withA()
    // The move is still under way (no endDrag yet): A now spans 140...240, so (200, 150) is on it.
    workspace.drag(from: pt(150, 140), to: pt(190, 140))
    let hover = workspace.hover(at: pt(200, 150), modifiers: [])
    #expect(hover.nodeID == nil)
    #expect(hover.outline == nil)
    #expect(hover.pointer == .tool)
}

@Test func hoverChangesNothing() {
    let workspace = withA()
    let pages = workspace.pages
    _ = workspace.hover(at: pt(150, 140), modifiers: [.option])
    _ = workspace.hover(at: pt(200, 180), modifiers: [])
    #expect(workspace.pages == pages)
    #expect(workspace.selectedNodeID == "node-2")
}

@Test func theBadgeIsNilWithNothingSelected() {
    #expect(DesignFixtures.cards.selectionBadge == nil)
}

@Test func theBadgeIsTheSizeOfOneLayer() {
    #expect(withA().selectionBadge == "100 × 80")
}

@Test func theBadgeIsTheBoundsOfSeveralLayers() {
    var workspace = withA()
    workspace.toggleSelection("node-3")
    // A (100...200 by 100...180) and B (300...500 by 140...220) span 400 by 120.
    #expect(workspace.selectionBadge == "400 × 120")
}

@Test func theBadgeIsWholePoints() throws {
    var workspace = withA()
    // Width 99.6 and height 80.6 round to 100 and 81.
    try workspace.resizeNode("node-2", handle: .bottomRight, by: pt(-0.4, 0.6), shift: false, option: false)
    #expect(workspace.selectionBadge == "100 × 81")
}

@Test func theBadgeShowsXAndYWhileAMoveRuns() {
    var workspace = withA()
    workspace.drag(from: pt(150, 140), to: pt(190, 140))
    #expect(workspace.selectionBadge == "X 140, Y 100")
}

@Test func theBadgeReturnsToSizeWhenTheMoveEnds() {
    var workspace = withA()
    workspace.drag(from: pt(150, 140), to: pt(190, 140))
    workspace.endDrag()
    #expect(workspace.selectionBadge == "100 × 80")
}

@Test func theHoverMarkIsTheLayerOrTheTextBoxOnly() {
    let layer = DesignFixtures.cards.hover(at: pt(150, 140), modifiers: [])
    #expect(layer.mark == rc(100, 100, 100, 80))
    #expect(layer.placement == nil)
    var text = DesignFixtures.cards
    text.selectTool(.text)
    let box = text.hover(at: pt(300, 400), modifiers: [])
    #expect(box.mark == rc(300, 400, 120, 24))
    #expect(box.placement == rc(300, 400, 120, 24))
    // An outline that names no layer and isn't the Text tool's is never drawn.
    let stray = DesignHover(nodeID: nil, outline: rc(1, 2, 3, 4), pointer: .move)
    #expect(stray.mark == nil)
    #expect(stray.placement == nil)
}

@Test func theSteadyAnswerDropsOnlyTheTextBox() {
    var text = DesignFixtures.cards
    text.selectTool(.text)
    let here = text.hover(at: pt(300, 400), modifiers: []).steady
    let there = text.hover(at: pt(310, 420), modifiers: []).steady
    #expect(here == DesignHover(nodeID: nil, outline: nil, pointer: .text))
    #expect(here == there)
    let layer = DesignFixtures.cards.hover(at: pt(150, 140), modifiers: [])
    #expect(layer.steady == layer)
    #expect(DesignFixtures.cards.hover(at: pt(5000, 5000), modifiers: []).steady == nil)
}

@Test func theBadgeHangsUnderTheMiddleOfTheSelection() {
    #expect(DesignFixtures.cards.selectionBadgeAnchor == nil)
    #expect(withA().selectionBadgeAnchor == pt(150, 180))
    var both = withA()
    both.toggleSelection("node-3")
    // A and B span 100...500 by 100...220.
    #expect(both.selectionBadgeAnchor == pt(300, 220))
    // The canvas reads the text and the anchor together, from one walk.
    #expect(both.sizeBadge(draft: nil)?.text == "400 × 120")
    #expect(both.sizeBadge(draft: nil)?.anchor == pt(300, 220))
    #expect(DesignFixtures.cards.sizeBadge(draft: nil) == nil)
}

@Test func theLiveCopysBadgeReadsTheDragWhileTheWorkspaceKeepsItsSize() {
    var workspace = withA()
    let handle = pt(200, 180)
    workspace.drag(from: handle, to: handle)
    var live = DesignLiveEdit()
    live.begin(from: workspace)
    live.sample(from: handle, to: pt(230, 195))
    #expect(live.workspace?.selectionBadge == "130 × 95")
    #expect(live.workspace?.selectionBadgeAnchor == pt(165, 195))
    #expect(workspace.selectionBadge == "100 × 80")
    live.end(into: &workspace)
    #expect(workspace.selectionBadge == "130 × 95")
}
