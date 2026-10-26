// PhotoStyleMenuTests.swift (layer-styles PY-2): Layer > Layer Style…, Copy, Paste and Clear Layer Style and the
// style panel's sheet: when each is on and what it says, and what a panel intent runs.
import SuiteImaging
import SuiteKernel
import Testing
@testable import PhotoModel

struct PhotoStyleMenuTests {
    static func why(_ id: String, _ state: PhotoMenuState) -> String? { PhotoMenuState.spec(id).availability(state).why }

    @Test func showOpensAndClosesThePanelWithNoStep() throws {
        var ws = try PhotoLayerStyleTests.twoLayers()
        let steps = ws.historySteps
        try ws.runStyleIntent(.show(.stroke))
        #expect(ws.stylePanel == .stroke)
        try ws.runStyleIntent(.show(nil))
        #expect(ws.stylePanel == nil)
        #expect(ws.historySteps == steps)
    }

    @Test func otherIntentsRunTheirCommandAndAreRefusedUntilBuilt() throws {
        var ws = try PhotoLayerStyleTests.twoLayers()
        ws.showStylePanel(.dropShadow)
        let layers = ws.layers
        for intent in [StyleIntent.toggle(.dropShadow, true), .preset("Lifted"), .fillOpacity(0.5, drag: nil)] {
            #expect(throws: CatalogError.self) { try ws.runStyleIntent(intent) }
        }
        #expect(throws: CatalogError.self) { try ws.pasteLayerStyle(.object(["effects": .array([]), "fillOpacity": .number(1)])) }
        #expect(ws.layers == layers && ws.stylePanel == .dropShadow)
    }

    @Test func copyAndClearSayTheLayerHasNoStyle() throws {
        var ws = try PhotoLayerStyleTests.twoLayers()
        let state = PhotoMenuState(workspace: ws, hasWindow: true)
        #expect(Self.why("style.copy", state) == "This layer has no style to copy.")
        #expect(Self.why("style.clear", state) == "This layer has no style to clear.")
        #expect(throws: CatalogError.self) { _ = try ws.copyLayerStyle() }
        #expect(throws: CatalogError.self) { try ws.clearLayerStyle() }
    }

    @Test func pasteNeedsACopiedStyle() throws {
        let ws = try PhotoLayerStyleTests.twoLayers()
        #expect(Self.why("style.paste", PhotoMenuState(workspace: ws, hasWindow: true)) == PhotoMenuState.noStyleToPaste)
        #expect(Self.why("style.paste", PhotoMenuState(workspace: ws, hasWindow: true, pasteboardHasStyle: true)) == nil)
        // With no layer the layer's reason comes first, copied style or not.
        let none = PhotoMenuState(hasWindow: true, pasteboardHasStyle: true)
        #expect(Self.why("style.paste", none) == StyleRules.noLayerHelp)
        #expect(Self.why("style.paste", PhotoMenuState(hasWindow: true)) == StyleRules.noLayerHelp)
    }

    @Test func thePanelItemOpensOnALayerAndAlwaysCloses() throws {
        var ws = PhotoWorkspace(services: .fake)
        #expect(Self.why("style.panel", PhotoMenuState(workspace: ws, hasWindow: true)) == StyleRules.noLayerHelp)
        ws.showStylePanel(.dropShadow)
        #expect(Self.why("style.panel", PhotoMenuState(workspace: ws, hasWindow: true)) == nil, "Done closes it")
        let layered = try PhotoLayerStyleTests.twoLayers()
        #expect(Self.why("style.panel", PhotoMenuState(workspace: layered, hasWindow: true)) == nil)
        #expect(layered.menuTitle("style.panel") == "Layer Style…")
        #expect(layered.menuTitle("style.copy") == "Copy Layer Style")
    }
}
