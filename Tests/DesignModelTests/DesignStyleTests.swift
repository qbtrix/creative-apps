// DesignStyleTests.swift: LiveStyling, the live StyleEditing (style-rows ST-1,
// blueprint 5.4), on DesignFixtures' `cards` through `.live`: every setter acts
// on the named layers as one coalescing step, clamps, skips the kinds that don't
// take it, refuses locked and hidden layers by name, and holds the help law.
// Ends with walk MJ8. Runs on Linux and macOS.
@testable import DesignModel
import Testing

// cards: Desktop node-1 holds A node-2, B node-3, Title node-5, Pair node-6 (E1 node-7, E2 node-8),
// Locked node-9 and Hidden node-10.
private enum ID {
    static let desktop = "node-1", a = "node-2", b = "node-3", title = "node-5", pair = "node-6"
    static let e1 = "node-7", e2 = "node-8", locked = "node-9", hidden = "node-10"
}

/// `cards` on `.live` with `selection` selected, primary last.
private func open(selecting selection: [String]) -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.useServices(.live)
    for (index, id) in selection.enumerated() {
        if index == 0 { workspace.selectItem(id) } else { workspace.toggleSelection(id) }
    }
    return workspace
}

private func node(_ workspace: DesignWorkspace, _ id: String) -> DesignNode? { workspace.selectedPage?.nodes.node(id) }
private func stepNames(_ workspace: DesignWorkspace) -> [String] { workspace.history.undo.map(\.name) }
private let bold = DesignTextStyle(family: "System", size: 32, weight: 700, alignment: .center)

@Suite struct DesignStyleTests {
    let live = LiveStyling()
    let page = DesignFixtures.cards.selectedPage ?? DesignPage(id: "none", name: "None", frameWidth: 1, frameHeight: 1)
    let ab = [ID.a, ID.b]

    func layer(_ id: String, _ edit: DesignEdit) -> DesignNode? { edit.nodes.node(id) }

    /// `page` after `edit`.
    func after(_ edit: DesignEdit) -> DesignPage {
        var page = page
        page.nodes = edit.nodes
        return page
    }

    @Test func opacityOnAAndBSetsBothAsOneRunAndClamps() throws {
        var workspace = open(selecting: ab)
        for value in [0.9, 0.8, 0.7, 0.6, 0.5] { try workspace.setStyle(.opacity(value)) }
        #expect(node(workspace, ID.a)?.opacity == 0.5 && node(workspace, ID.b)?.opacity == 0.5)
        #expect(stepNames(workspace) == ["Change Opacity"])
        let edit = try live.setOpacity(0.5, ab, on: page)
        #expect(edit.name == "Change Opacity" && edit.selection == ab)
        #expect(edit.coalescingKey == DesignEdit.runKey("opacity", ab))
        #expect(live.styleHelp(.opacity, ab, on: page) == nil)
        #expect(layer(ID.a, try live.setOpacity(2, ab, on: after(edit)))?.opacity == 1)
        #expect(layer(ID.b, try live.setOpacity(-1, ab, on: after(edit)))?.opacity == 0)
        #expect(throws: DesignRefusal.unchanged) { try live.setOpacity(2, [ID.a], on: page) }  // A is 1 already
    }

    @Test func strokeWidthClampsAndNilRemovesIt() throws {
        let wide = try live.setStroke(DesignStroke(color: .black, width: 4000), ab, on: page)
        #expect(layer(ID.a, wide)?.stroke == DesignStroke(color: .black, width: 1000) && layer(ID.b, wide)?.stroke?.width == 1000)
        #expect(wide.name == "Change Stroke" && wide.coalescingKey == DesignEdit.runKey("stroke", ab))
        #expect(layer(ID.a, try live.setStroke(DesignStroke(color: .black, width: -5), ab, on: after(wide)))?.stroke?.width == 0)
        let removed = try live.setStroke(nil, ab, on: after(wide))
        #expect(layer(ID.a, removed)?.stroke == nil && layer(ID.b, removed)?.stroke == nil)
        #expect(throws: DesignRefusal.unchanged) { try live.setStroke(nil, [ID.a], on: page) }
    }

    @Test func cornerRadiusSetsRectanglesSkipsTheRestAndClamps() throws {
        let edit = try live.setCornerRadius(12, [ID.a, ID.e1], on: page)
        #expect(layer(ID.a, edit)?.cornerRadius == 12 && layer(ID.e1, edit)?.cornerRadius == 0)
        #expect(edit.name == "Change Corner Radius" && edit.coalescingKey == DesignEdit.runKey("radius", [ID.a, ID.e1]))
        #expect(live.styleHelp(.cornerRadius, [ID.a, ID.e1], on: page) == nil)
        #expect(throws: DesignRefusal.noCorners("E2")) { try live.setCornerRadius(12, [ID.e1, ID.e2], on: page) }
        #expect(live.styleHelp(.cornerRadius, [ID.e1, ID.e2], on: page) == "E2 has no corners to round.")
        // One layer selected keeps DesignCorners' per-kind help through the workspace.
        #expect(open(selecting: [ID.e1]).styleHelp(.cornerRadius) == "An ellipse has no corners to round.")
        // A is 100 × 80, B 200 × 80: both clamp to 40.
        let big = try live.setCornerRadius(500, ab, on: page)
        #expect(layer(ID.a, big)?.cornerRadius == 40 && layer(ID.b, big)?.cornerRadius == 40)
        #expect(layer(ID.a, try live.setCornerRadius(-3, ab, on: after(big)))?.cornerRadius == 0)
    }

    @Test func textStyleClampsSizeAndWeightAndSetsTextLayersOnly() throws {
        let tiny = DesignTextStyle(family: "Serif", size: 0, weight: 950, alignment: .trailing)
        let edit = try live.setTextStyle(tiny, [ID.title], on: page)
        #expect(layer(ID.title, edit)?.textStyle == DesignTextStyle(family: "Serif", size: 1, weight: 900, alignment: .trailing))
        #expect(edit.name == "Change Text Style" && edit.coalescingKey == DesignEdit.runKey("text-style", [ID.title]))
        let huge = try live.setTextStyle(DesignTextStyle(family: "Serif", size: 5000, weight: 50, alignment: .leading), [ID.title], on: page)
        #expect(layer(ID.title, huge)?.textStyle.size == 1000 && layer(ID.title, huge)?.textStyle.weight == 100)
        let both = try live.setTextStyle(bold, [ID.title, ID.a], on: page)
        #expect(layer(ID.title, both)?.textStyle == bold && layer(ID.a, both)?.textStyle == .default)
        #expect(live.styleHelp(.textStyle, [ID.title, ID.a], on: page) == nil)
        #expect(throws: DesignRefusal.notText("A")) { try live.setTextStyle(bold, [ID.a], on: page) }
        #expect(live.styleHelp(.textStyle, [ID.a], on: page) == "A isn't a text layer.")
        #expect(throws: DesignRefusal.notText("B")) { try live.setTextStyle(bold, ab, on: page) }
    }

    @Test func frameAndFillSetEachLayer() throws {
        let moved = try live.setFrame(.x, to: 300, ab, on: page)
        #expect(layer(ID.a, moved)?.frame == rc(300, 100, 100, 80) && layer(ID.b, moved)?.frame == rc(300, 140, 200, 80))
        #expect(moved.name == "Change Frame" && moved.coalescingKey == DesignEdit.runKey("frame", ab))
        #expect(layer(ID.a, try live.setFrame(.width, to: 0, ab, on: page))?.frame.width == 1)
        // A frame moves with its children.
        let desktop = try live.setFrame(.y, to: 10, [ID.desktop, ID.a], on: page)
        #expect(layer(ID.desktop, desktop)?.frame.y == 10 && layer(ID.a, desktop)?.frame.y == 10)
        let filled = try live.setFill(DesignColor(1, 2, 3), [ID.a, ID.title], on: page)
        #expect(layer(ID.a, filled)?.fill == DesignColor(1, 2, 3) && layer(ID.title, filled)?.fill == DesignColor(1, 2, 3))
        #expect(filled.name == "Change Fill" && filled.coalescingKey == DesignEdit.runKey("fill", [ID.a, ID.title]))
    }

    /// Every setter on `ids` throws `refusal`, and every row's help reads its sentence.
    func expectRefused(_ ids: [String], _ refusal: DesignRefusal, on page: DesignPage) {
        #expect(throws: refusal) { try live.setFrame(.x, to: 300, ids, on: page) }
        #expect(throws: refusal) { try live.setFill(.black, ids, on: page) }
        #expect(throws: refusal) { try live.setCornerRadius(12, ids, on: page) }
        #expect(throws: refusal) { try live.setOpacity(0.5, ids, on: page) }
        #expect(throws: refusal) { try live.setStroke(.default, ids, on: page) }
        #expect(throws: refusal) { try live.setTextStyle(bold, ids, on: page) }
        for property in DesignStyleProperty.allCases { #expect(live.styleHelp(property, ids, on: page) == refusal.help, "\(property)") }
    }

    @Test func lockedHiddenAndNothingSelectedRefuseEverySetter() {
        expectRefused([ID.a, ID.locked], .locked("Locked"), on: page)
        expectRefused([ID.hidden, ID.a], .hidden("Hidden"), on: page)
        expectRefused([], .nothingSelected, on: page)
        expectRefused(["node-404"], .nothingSelected, on: page)
        var inside = page
        _ = inside.nodes.update(ID.pair) { $0.isLocked = true }
        expectRefused([ID.e1], .locked("E1"), on: inside)
        _ = inside.nodes.update(ID.pair) { ($0.isLocked, $0.isHidden) = (false, true) }
        expectRefused([ID.e2], .hidden("E2"), on: inside)
    }

    @Test func theCurrentValueAndANonFiniteOneAreUnchanged() throws {
        let fill = try #require(page.nodes.node(ID.a)?.fill)
        #expect(throws: DesignRefusal.unchanged) { try live.setOpacity(1, ab, on: page) }
        #expect(throws: DesignRefusal.unchanged) { try live.setCornerRadius(0, ab, on: page) }
        #expect(throws: DesignRefusal.unchanged) { try live.setFill(fill, [ID.a], on: page) }
        #expect(throws: DesignRefusal.unchanged) { try live.setTextStyle(.default, [ID.title], on: page) }
        #expect(throws: DesignRefusal.unchanged) { try live.setFrame(.x, to: 100, [ID.a], on: page) }
        #expect(throws: DesignRefusal.unchanged) { try live.setOpacity(.nan, ab, on: page) }
        #expect(throws: DesignRefusal.unchanged) { try live.setCornerRadius(.infinity, ab, on: page) }
        #expect(throws: DesignRefusal.unchanged) { try live.setFrame(.width, to: .nan, ab, on: page) }
        #expect(throws: DesignRefusal.unchanged) { try live.setStroke(DesignStroke(color: .black, width: .infinity), ab, on: page) }
        let nan = DesignTextStyle(family: "System", size: .nan, weight: 700, alignment: .leading)
        #expect(throws: DesignRefusal.unchanged) { try live.setTextStyle(nan, [ID.title], on: page) }
        for property in DesignStyleProperty.allCases where property != .textStyle {
            #expect(live.styleHelp(property, ab, on: page) == nil, "\(property)")
        }
        #expect(live.styleHelp(.textStyle, [ID.title], on: page) == nil)
    }

    @Test func helpLawHoldsOnLive() {
        let law = DesignContractLaw.check(.live, on: page)
        #expect(law.violations.isEmpty, "\(law.violations)")
    }

    /// MJ8: on `cards` through `.live`, opacity, radius, stroke and text style set through
    /// `setStyle`, each one step, then undone in order.
    @Test func walkStyleRows() throws {
        var workspace = open(selecting: ab)
        try workspace.setStyle(.opacity(0.5))
        #expect(workspace.undoActionName == "Undo Change Opacity")
        try workspace.setStyle(.cornerRadius(12))
        #expect(workspace.undoActionName == "Undo Change Corner Radius")
        try workspace.setStyle(.stroke(DesignStroke(color: .black, width: 4)))
        #expect(workspace.undoActionName == "Undo Change Stroke")
        workspace.selectItem(ID.title)
        workspace.toggleSelection(ID.a)
        try workspace.setStyle(.textStyle(bold))
        #expect(workspace.undoActionName == "Undo Change Text Style")
        #expect(stepNames(workspace) == ["Change Opacity", "Change Corner Radius", "Change Stroke", "Change Text Style"])
        let (a, b, title) = (node(workspace, ID.a), node(workspace, ID.b), node(workspace, ID.title))
        #expect(a?.opacity == 0.5 && b?.opacity == 0.5 && a?.cornerRadius == 12 && b?.cornerRadius == 12)
        #expect(a?.stroke?.width == 4 && b?.stroke?.width == 4 && title?.textStyle == bold && a?.textStyle == .default)
        workspace.undo()
        #expect(node(workspace, ID.title)?.textStyle == .default)
        workspace.undo()
        #expect(node(workspace, ID.a)?.stroke == nil && node(workspace, ID.b)?.stroke == nil)
        workspace.undo()
        #expect(node(workspace, ID.a)?.cornerRadius == 0)
        workspace.undo()
        #expect(node(workspace, ID.a)?.opacity == 1 && node(workspace, ID.b)?.opacity == 1)
        #expect(!workspace.canUndo && workspace.pages == DesignFixtures.cards.pages)
    }
}
