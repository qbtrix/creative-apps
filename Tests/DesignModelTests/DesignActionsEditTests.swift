// DesignActionsEditTests.swift: the clipboard, Move Layer and style actions of
// DesignActions+Edit.swift on DesignFixtures.cards. Each is one named step and a refusal records
// none; Paste lands in the selected frame (#415); on `.live` one-layer frame, fill and corner
// radius rows keep today's methods while several layers go through LiveStyling (DesignStyleTests);
// a run of one row is one step. Ends with walk MJ4. Runs on Linux and macOS.
@testable import DesignModel
import Testing

// cards: Desktop node-1 holds A node-2, B node-3, C node-4, Title node-5, Pair node-6 (E1 node-7,
// E2 node-8), Locked node-9 and Hidden node-10.
private enum ID {
    static let desktop = "node-1", a = "node-2", b = "node-3", c = "node-4"
    static let title = "node-5", pair = "node-6", e1 = "node-7", locked = "node-9"
}

/// `cards` on `services` with `selection` selected, primary last.
private func open(_ services: DesignServices, selecting selection: [String]) -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.useServices(services)
    for (index, id) in selection.enumerated() {
        if index == 0 { workspace.selectItem(id) } else { workspace.toggleSelection(id) }
    }
    return workspace
}

private func everyID(_ nodes: [DesignNode]) -> Set<String> {
    nodes.reduce(into: []) { $0.insert($1.id); $0.formUnion(everyID($1.children)) }
}

private func node(_ workspace: DesignWorkspace, _ id: String) -> DesignNode? { workspace.selectedPage?.nodes.node(id) }

private func stepNames(_ workspace: DesignWorkspace) -> [String] { workspace.history.undo.map(\.name) }

@Suite struct DesignActionsEditTests {
    @Test func copyPairThenPasteIsOnePasteStepWithFreshIDs() throws {
        var workspace = open(.fake, selecting: [ID.pair])
        let before = everyID(workspace.selectedPage?.nodes ?? [])
        try workspace.paste(try workspace.copySelection())
        #expect(stepNames(workspace) == ["Paste"])
        let pasted = try #require(workspace.selectedNodeIDs.last.flatMap { node(workspace, $0) })
        #expect(pasted.children.count == 2)
        #expect(everyID([pasted]).isDisjoint(with: before))
    }

    @Test func cutIsOneStepAndItsBytesPasteBack() throws {
        var workspace = open(.fake, selecting: [ID.b])
        let data = try workspace.cutSelection()
        #expect(stepNames(workspace) == ["Cut"])
        #expect(node(workspace, ID.b) == nil)
        try workspace.paste(data)
        let back = try #require(workspace.selectedNodeIDs.last.flatMap { node(workspace, $0) })
        #expect(back.name == "B" && back.frame == DesignRect(x: 310, y: 150, width: 200, height: 80))
        #expect(stepNames(workspace) == ["Cut", "Paste"])

        var two = open(.fake, selecting: [ID.a, ID.c])
        _ = try two.cutSelection()
        #expect(stepNames(two) == ["Cut"])
        #expect(node(two, ID.a) == nil && node(two, ID.c) == nil)
    }

    @Test func cutOfALockedLayerRecordsNothing() {
        var workspace = open(.fake, selecting: [ID.locked])
        let before = workspace
        #expect(throws: DesignRefusal.locked("Locked")) { _ = try workspace.cutSelection() }
        #expect(workspace == before)
    }

    @Test func pasteGoesIntoTheSelectedFrame() throws {
        var workspace = open(.fake, selecting: [ID.e1])
        let data = try workspace.copySelection()
        workspace.selectItem(ID.desktop)
        try workspace.paste(data)
        let pasted = try #require(workspace.selectedNodeIDs.last)
        #expect(workspace.selectedPage?.nodes.ancestors(of: pasted)?.last == ID.desktop)
    }

    @Test func pasteHelpOfNothingIsAReason() {
        #expect(open(.fake, selecting: []).pasteHelp(nil) != nil)
        #expect(open(.live, selecting: []).pasteHelp(nil) != nil)
    }

    @Test func moveTitleIntoPairIsOneStep() throws {
        var workspace = open(.fake, selecting: [ID.title])
        #expect(workspace.moveLayerHelp(ID.title, into: ID.pair, at: 0) == nil)
        try workspace.moveLayer(ID.title, into: ID.pair, at: 0)
        #expect(stepNames(workspace) == ["Move Layer"])
        #expect(node(workspace, ID.pair)?.children.first?.id == ID.title)
    }

    @Test func oneLayerRowsKeepTodaysMethodsOnLive() throws {
        var workspace = open(.live, selecting: [ID.a])
        for property in [DesignStyleProperty.frame, .fill, .cornerRadius] {
            #expect(workspace.styleHelp(property) == nil, "\(property)")
        }
        #expect(workspace.styleHelp(.opacity) == nil)
        try workspace.setStyle(.frame(.x, 300))
        try workspace.setStyle(.fill(.black))
        try workspace.setStyle(.cornerRadius(12))
        let a = try #require(node(workspace, ID.a))
        #expect(a.frame.x == 300 && a.fill == .black && a.cornerRadius == 12)
        #expect(stepNames(workspace) == ["Change Frame", "Change Fill", "Change Corner Radius"])
    }

    @Test func aOneLayerRefusalRecordsNothing() {
        var workspace = open(.live, selecting: [ID.locked])
        let before = workspace
        #expect(throws: DesignRefusal.locked("Locked")) { try workspace.setStyle(.fill(.black)) }
        #expect(workspace == before)
    }

    @Test func severalLayersGoThroughTheStylingService() throws {
        var fake = open(.fake, selecting: [ID.a, ID.b])
        try fake.setStyle(.frame(.x, 300))
        #expect(node(fake, ID.a)?.frame.x == 300 && node(fake, ID.b)?.frame.x == 300)
        #expect(stepNames(fake) == ["Change Frame"])

        var live = open(.live, selecting: [ID.a, ID.b])
        #expect(live.styleHelp(.frame) == nil)
        try live.setStyle(.frame(.x, 300))
        #expect(node(live, ID.a)?.frame.x == 300 && node(live, ID.b)?.frame.x == 300)
        #expect(stepNames(live) == ["Change Frame"])
    }

    @Test func aRunOfOpacityChangesIsOneStep() throws {
        var workspace = open(.fake, selecting: [ID.a])
        try workspace.setStyle(.opacity(0.5))
        try workspace.setStyle(.opacity(0.25))
        #expect(stepNames(workspace) == ["Change Opacity"])
        #expect(node(workspace, ID.a)?.opacity == 0.25)
    }

    /// MJ4: every workspace command records one named step or says why.
    @Test func testCommandsWalk() throws {
        var three = open(.fake, selecting: [ID.a, ID.b, ID.c])
        try three.run(.align(.top))
        #expect(three.undoActionName == "Undo Align Top")
        try three.run(.distribute(.horizontal))
        #expect(three.undoActionName == "Undo Distribute Horizontally")
        #expect(open(.fake, selecting: [ID.a, ID.b]).help(.distribute(.horizontal))
            == "Select three or more layers to distribute.")

        var pair = open(.fake, selecting: [ID.pair])
        try pair.paste(try pair.copySelection())
        #expect(pair.undoActionName == "Undo Paste")
        let copy = try #require(pair.selectedNodeIDs.last.flatMap { node(pair, $0) })
        #expect(pair.selectedPage?.nodes.ancestors(of: copy.id)?.last == ID.desktop)
        #expect(copy.frame == DesignRect(x: 910, y: 410, width: 300, height: 100) && copy.children.count == 2)

        var cut = open(.fake, selecting: [ID.b])
        _ = try cut.cutSelection()
        #expect(cut.undoActionName == "Undo Cut")

        var live = open(.live, selecting: [ID.a])
        try live.run(.nudge(.right, large: false))
        try live.run(.align(.left))
        try live.setStyle(.frame(.x, 300))
        try live.setStyle(.fill(.black))
        try live.setStyle(.cornerRadius(12))
        try live.run(.delete)
        #expect(stepNames(live) == ["Nudge", "Align Left", "Change Frame", "Change Fill", "Change Corner Radius",
                                    "Delete Rectangle"])
        #expect(node(live, ID.a) == nil)
    }
}
