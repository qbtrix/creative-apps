// DesignLayerDropLineTests.swift: where a Layers drag draws its insertion line
// (layers-panel L-4). DesignDropPosition(y:height:holdsChildren:) maps a
// pointer's y over a row to above, below or into, and layerDropLine keeps only
// the positions layerDrop and moveLayerHelp both take, on `cards`: Desktop
// holds A, B, C, Title, Pair (E1, E2), Locked and Hidden. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignLayerDropLineTests {
    let workspace = DesignFixtures.cards
    let desktop = "node-1", a = "node-2", b = "node-3", pair = "node-6", e1 = "node-7", locked = "node-9"

    @Test func aRowThatHoldsChildrenSplitsIntoQuarters() {
        let at = { (y: Double) in DesignDropPosition(y: y, height: 24, holdsChildren: true) }
        #expect(at(0) == .above)
        #expect(at(5.9) == .above)
        #expect(at(6) == .into)
        #expect(at(12) == .into)
        #expect(at(18) == .into)
        #expect(at(18.1) == .below)
        #expect(at(24) == .below)
    }

    @Test func aLeafRowSplitsInHalves() {
        let at = { (y: Double) in DesignDropPosition(y: y, height: 24, holdsChildren: false) }
        #expect(at(0) == .above)
        #expect(at(11.9) == .above)
        #expect(at(12) == .below)
        #expect(at(24) == .below)
    }

    @Test func aPointerOffTheRowOrARowWithNoHeightPicksNothing() {
        #expect(DesignDropPosition(y: -0.1, height: 24, holdsChildren: true) == nil)
        #expect(DesignDropPosition(y: 24.1, height: 24, holdsChildren: false) == nil)
        #expect(DesignDropPosition(y: 0, height: 0, holdsChildren: false) == nil)
        #expect(DesignDropPosition(y: .nan, height: 24, holdsChildren: false) == nil)
        #expect(DesignDropPosition(y: .infinity, height: .infinity, holdsChildren: false) == nil)
    }

    @Test func theLineFollowsThePointerOverAnAcceptingRow() {
        #expect(workspace.layerDropLine(e1, over: b, y: 2, height: 24) == .above)
        #expect(workspace.layerDropLine(e1, over: b, y: 22, height: 24) == .below)
        #expect(workspace.layerDropLine(e1, over: b, y: 12, height: 24) == .below)
        #expect(workspace.layerDropLine(a, over: pair, y: 12, height: 24) == .into)
        #expect(workspace.layerDropLine(a, over: desktop, y: 12, height: 24) == .into)
    }

    @Test func aRefusedDropDrawsNoLine() {
        // Onto itself, into its own child, off the row, an unknown row.
        #expect(workspace.layerDropLine(b, over: b, y: 2, height: 24) == nil)
        #expect(workspace.layerDropLine(pair, over: e1, y: 2, height: 24) == nil)
        #expect(workspace.layerDropLine(desktop, over: pair, y: 12, height: 24) == nil)
        #expect(workspace.layerDropLine(e1, over: b, y: 30, height: 24) == nil)
        #expect(workspace.layerDropLine(e1, over: "node-99", y: 2, height: 24) == nil)
        // moveLayerHelp's refusals: a locked layer stays put.
        #expect(workspace.moveLayerHelp(locked, into: desktop, at: 0) != nil)
        #expect(workspace.layerDropLine(locked, over: a, y: 2, height: 24) == nil)
    }
}
