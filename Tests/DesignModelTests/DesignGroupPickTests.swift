// DesignGroupPickTests.swift (area-selection AR-13, turned on by AR-14): in Design a click on a grouped
// layer picks its group and a Move drag carries the group whole; select.enter-group (double-click,
// Return) lets the next click pick inside it, select.exit-group (Escape) steps out one level and picks
// the group again, and a deep pick (Command) takes the layer itself. Each pick is a view change, not an
// undo step. The card is made by commands on `cards`: Group of A (node-2) and Title (node-5). Fails when
// the press lifts nothing (the drag pulls Title out of its card) or Escape leaves every group.
// The catalog ids and the canvas press come from DesignGroupPick+Kernel.swift (AR-14).
// Runs on Linux and macOS.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignGroupPickTests {
    /// A (100, 100, 100, 80) and Title (100, 40, 200, 32), the card's two layers.
    static let a = "node-2", title = "node-5"
    /// A point on Title and none on A.
    static let onTitle = pt(150, 56)

    /// `cards` on `.live` with A and Title grouped by commands into the card, nothing picked; the card's id.
    static func card() throws -> (DesignWorkspace, String) {
        var workspace = DesignFixtures.cards
        workspace.useServices(.live)
        _ = try run("edit.select", ["ids": .array([.string(a), .string(title)])], on: &workspace)
        _ = try run("object.group", [:], on: &workspace)
        let card = try #require(workspace.selectedNodeID)
        workspace.deselect()
        return (workspace, card)
    }

    static func run(_ id: String, _ params: [String: JSONValue], on workspace: inout DesignWorkspace) throws -> JSONValue {
        try DesignWorkspace.catalog.run(id, params: .object(params), on: &workspace).result
    }

    /// select.pick at `point`, deep when Command is held.
    static func pick(_ point: DesignPoint, deep: Bool = false, on workspace: inout DesignWorkspace) throws {
        _ = try run("select.pick", ["x": .number(point.x), "y": .number(point.y), "deep": .bool(deep)], on: &workspace)
    }

    @Test
    func aPressOnTheCardsTextPicksTheCardAndMakesNoStep() throws {
        var (workspace, card) = try Self.card()
        workspace.gesture(.move, Self.onTitle, Self.onTitle)
        #expect(workspace.selectedNodeIDs == [card])
        #expect(workspace.undoActionName == "Undo Group")
        workspace.deselect()
        try Self.pick(Self.onTitle, on: &workspace)
        #expect(workspace.selectedNodeIDs == [card])
        #expect(workspace.undoActionName == "Undo Group")
    }

    @Test
    func aDragOnTheCardsTextMovesTheCardWhole() throws {
        var (workspace, card) = try Self.card()
        workspace.gesture(.move, Self.onTitle, pt(190, 56))
        #expect(workspace.frame(card) == rc(140, 40, 200, 140))
        #expect(workspace.frame(Self.title) == rc(140, 40, 200, 32))
        #expect(workspace.frame(Self.a) == rc(140, 100, 100, 80))
        #expect(workspace.undoActionName == "Undo Move")
    }

    @Test
    func enterThenAClickPicksTheTextAndADragMovesOnlyIt() throws {
        var (workspace, card) = try Self.card()
        #expect(DesignWorkspace.catalog.availability("select.enter-group", on: workspace).why != nil)
        try Self.pick(Self.onTitle, on: &workspace)
        #expect(DesignWorkspace.catalog.availability("select.enter-group", on: workspace).why == nil)
        _ = try Self.run("select.enter-group", [:], on: &workspace)
        #expect(workspace.selectedNodeIDs.isEmpty)
        try Self.pick(Self.onTitle, on: &workspace)
        #expect(workspace.selectedNodeIDs == [Self.title])
        workspace.gesture(.move, Self.onTitle, pt(160, 56))
        #expect(workspace.frame(Self.title) == rc(110, 40, 200, 32))
        #expect(workspace.frame(Self.a) == rc(100, 100, 100, 80))
        #expect(workspace.treeNode(card)?.children.map(\.id).contains(Self.title) == true)
    }

    @Test
    func exitStepsOutOneLevelAndPicksTheCardAgain() throws {
        var (workspace, card) = try Self.card()
        #expect(DesignWorkspace.catalog.availability("select.exit-group", on: workspace).why != nil)
        try Self.pick(Self.onTitle, on: &workspace)
        _ = try Self.run("select.enter-group", [:], on: &workspace)
        try Self.pick(Self.onTitle, on: &workspace)
        _ = try Self.run("select.exit-group", [:], on: &workspace)
        #expect(workspace.selectedNodeIDs == [card])
        #expect(DesignWorkspace.catalog.availability("select.exit-group", on: workspace).why != nil)
        // Out of the card, a click on Title picks the card, not Title.
        try Self.pick(Self.onTitle, on: &workspace)
        #expect(workspace.selectedNodeIDs == [card])
    }

    @Test
    func aDeepPickTakesTheTextItselfFromTheRoot() throws {
        var (workspace, _) = try Self.card()
        try Self.pick(Self.onTitle, deep: true, on: &workspace)
        #expect(workspace.selectedNodeIDs == [Self.title])
        #expect(workspace.undoActionName == "Undo Group")
        // A ⌘ press on the canvas does the same.
        workspace.deselect()
        workspace.gesture(.move, Self.onTitle, Self.onTitle, [.deep])
        #expect(workspace.selectedNodeIDs == [Self.title])
    }

    /// A double-click (`.enter`) on the picked card enters it and picks Title under the pointer.
    @Test func aDoubleClickOnThePickedCardEntersItAndPicksTheText() throws {
        var (workspace, card) = try Self.card()
        workspace.gesture(.move, Self.onTitle, Self.onTitle)
        workspace.gesture(.move, Self.onTitle, Self.onTitle, [.enter])
        #expect(workspace.selectedNodeIDs == [Self.title])
        #expect(workspace.groupScope == GroupScope(path: [card]))
    }

    /// Leaving the card resets the scope: a deselect, or a press on B (node-3, 300, 140, 200, 80) outside it; then Title picks the card.
    @Test func deselectOrAPressOutsideLeavesTheEnteredCard() throws {
        var (workspace, card) = try Self.card()
        try Self.pick(Self.onTitle, on: &workspace)
        _ = try Self.run("select.enter-group", [:], on: &workspace)
        workspace.deselect()
        #expect(workspace.groupScope == .root)
        try Self.pick(Self.onTitle, on: &workspace)
        #expect(workspace.selectedNodeIDs == [card])
        _ = try Self.run("select.enter-group", [:], on: &workspace)
        let onB = pt(400, 180)
        workspace.gesture(.move, onB, onB)
        #expect(workspace.selectedNodeIDs == ["node-3"])
        workspace.gesture(.move, Self.onTitle, Self.onTitle)
        #expect(workspace.selectedNodeIDs == [card])
    }

    /// On the canvas, Return enters the picked card and Escape steps out of it; with no group entered Escape deselects.
    @Test func returnEntersThePickedCardAndEscapeStepsOut() throws {
        var (workspace, card) = try Self.card()
        #expect(workspace.canvasKeyAction(.escape, modifiers: []) == .deselect)
        try Self.pick(Self.onTitle, on: &workspace)
        #expect(workspace.canvasKeyAction(.enter, modifiers: []) == .enterGroup)
        workspace.enterGroup()
        #expect(workspace.groupScope == GroupScope(path: [card]))
        #expect(workspace.canvasKeyAction(.escape, modifiers: []) == .exitGroup)
        workspace.exitGroup()
        #expect(workspace.selectedNodeIDs == [card] && workspace.groupScope == .root)
    }
}
