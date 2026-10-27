// PhotoLayerStyleTests.swift (layer-styles PY-1 contract, PY-5 behaviour): Photo as SuiteImaging's LayerStyleTarget.
// setStyle runs on the workspace (PY-5); the tests through `style.*` wait on SuiteImaging's
// StyleCommands bodies (LS-6).
// Wire: layer-styles:LS-6 (turns on the tests marked "waits on LS-6")
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteImaging
import SuiteKernel
import Testing
@testable import PhotoModel

struct PhotoLayerStyleTests {
    /// A 16x12 image with two pixel layers, the top one selected.
    static func twoLayers() throws -> PhotoWorkspace {
        var ws = PhotoWorkspace(services: .fake)
        try ws.newCanvas(width: 16, height: 12)
        ws.addLayer()
        return ws
    }

    static func ledger() throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/photo.txt")
        return Set(try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init))
    }

    @Test func theElevenStyleIDsAreCataloguedAndLedgered() throws {
        let style = StyleCommands.specs(PhotoWorkspace.self).map(\.id)
        #expect(style.count == 11)
        #expect(PhotoWorkspace.catalog.ids.filter { $0.hasPrefix("style.") }.sorted() == style.sorted())
        let ledger = try Self.ledger()
        #expect(style.filter { !ledger.contains($0) } == [], "every style id is in the ledger")
    }

    @Test func aNewLayerHasNoStyle() throws {
        let ws = try Self.twoLayers()
        #expect(ws.layers.allSatisfy { $0.style == .none })
        #expect(ws.styleSelection == LayerStyle.none)
        #expect(ws.styleHelp == nil)
    }

    @Test func showStylePanelOpensAndClosesIt() throws {
        var ws = try Self.twoLayers()
        let steps = ws.historySteps
        ws.showStylePanel(.dropShadow)
        #expect(ws.stylePanel == .dropShadow)
        #expect(ws.historySteps == steps, "the panel is not an undo step")
        ws.showStylePanel(nil)
        #expect(ws.stylePanel == nil)
    }

    @Test func noImageSaysSelectALayer() {
        let ws = PhotoWorkspace(services: .fake)
        #expect(ws.styleSelection == nil)
        #expect(ws.styleHelp == StyleRules.noLayerHelp)
        #expect(PhotoWorkspace.catalog.availability("style.add", on: ws).why == StyleRules.noLayerHelp)
    }

    @Test func anAdjustmentLayerTakesNoStyle() throws {
        var ws = try Self.twoLayers()
        ws.addAdjustmentLayer(.exposure)
        #expect(ws.styleSelection == nil)
        #expect(ws.styleHelp == "Layer styles go on pixel and text layers.")
        #expect(PhotoWorkspace.catalog.availability("style.add", on: ws).why == "Layer styles go on pixel and text layers.")
    }

    /// A style with one stroke at `fill` fill opacity, so steps differ.
    static func stroked(_ fill: Double = 1) -> LayerStyle {
        LayerStyle(effects: [StyleRules.defaults(.stroke)], fillOpacity: fill)
    }

    @Test func twoSelectedLayersTakeTheStyleInOneStep() throws {
        var ws = try Self.twoLayers()
        ws.selectAllLayers()
        let steps = ws.historySteps.count
        try ws.setStyle(Self.stroked(), name: "Add Layer Style", drag: nil)
        #expect(ws.layers.count == 2)
        #expect(ws.layers.allSatisfy { $0.style == Self.stroked() })
        #expect(ws.historySteps.count == steps + 1)
        #expect(ws.historySteps.last == "Add Layer Style")
        #expect(ws.styleSelection == Self.stroked())
        ws.undo()
        #expect(ws.layers.allSatisfy { $0.style == .none })
    }

    @Test func adjustmentLayersRefuse() throws {
        var ws = try Self.twoLayers()
        ws.addAdjustmentLayer(.exposure)
        let before = ws.layers, steps = ws.historySteps
        #expect(throws: CatalogError.unavailable(id: "style", why: PhotoWorkspace.styleOnAdjustment)) {
            try ws.setStyle(Self.stroked(), name: "Add Layer Style", drag: nil)
        }
        #expect(ws.layers == before)
        #expect(ws.historySteps == steps, "a refusal is not an undo step")
    }

    @Test func anAdjustmentLayerInTheSelectionIsSkipped() throws {
        var ws = try Self.twoLayers()
        ws.addAdjustmentLayer(.exposure)
        ws.selectAllLayers()
        #expect(ws.styleHelp == nil, "an image layer in the selection can take the style")
        let steps = ws.historySteps.count
        try ws.setStyle(Self.stroked(), name: "Add Layer Style", drag: nil)
        #expect(ws.historySteps.count == steps + 1)
        #expect(ws.layers.filter { $0.style == Self.stroked() }.count == 2)
        for layer in ws.layers {
            if case .adjustment = layer.kind { #expect(layer.style == .none) } else { #expect(layer.style == Self.stroked()) }
        }
    }

    @Test func dragIsOneStep() throws {
        var ws = try Self.twoLayers()
        try ws.setStyle(Self.stroked(), name: "Add Layer Style", drag: nil)
        let before = ws.layers, steps = ws.historySteps.count
        for i in 1...120 { try ws.setStyle(Self.stroked(Double(i) / 240), name: "Layer Style", drag: "d1") }
        #expect(ws.historySteps.count == steps + 1)
        #expect(ws.selectedLayer?.style == Self.stroked(0.5))
        try ws.setStyle(Self.stroked(0.25), name: "Layer Style", drag: "d2")
        #expect(ws.historySteps.count == steps + 2, "a new token is a new step")
        try ws.setStyle(Self.stroked(0.75), name: "Layer Style", drag: nil)
        try ws.setStyle(Self.stroked(0.8), name: "Layer Style", drag: nil)
        #expect(ws.historySteps.count == steps + 4, "no token never folds")
        ws.undo()
        ws.undo()
        ws.undo()
        #expect(ws.selectedLayer?.style == Self.stroked(0.5))
        ws.undo()
        #expect(ws.layers == before)
    }

    // Through the catalog: StyleCommands' runs throw StyleRules.notBuilt until LS-6.

    @Test(.disabled("waits on LS-6")) func panelCommandSetsThePanel() throws {
        var ws = try Self.twoLayers()
        _ = try PhotoWorkspace.catalog.run("style.panel", params: .object(["kind": .string("stroke")]), on: &ws)
        #expect(ws.stylePanel == .stroke)
    }

    @Test(.disabled("waits on LS-6")) func addOnTwoSelectedLayersIsOneStep() throws {
        var ws = try Self.twoLayers()
        ws.selectAllLayers()
        let steps = ws.historySteps.count
        _ = try PhotoWorkspace.catalog.run("style.add", params: .object(["kind": .string("dropShadow")]), on: &ws)
        #expect(ws.layers.allSatisfy { $0.style.effects.map(\.kind) == [.dropShadow] })
        #expect(ws.historySteps.count == steps + 1)
        ws.undo()
        #expect(ws.layers.allSatisfy { $0.style == .none })
    }

    @Test(.disabled("waits on LS-6")) func anAdjustmentLayerIsSkippedOrRefused() throws {
        var ws = try Self.twoLayers()
        ws.addAdjustmentLayer(.exposure)
        #expect(throws: CatalogError.self) {
            try ws.setStyle(StyleRules.adding(.stroke, to: .none), name: "Add Layer Style", drag: nil)
        }
        ws.selectAllLayers()
        try ws.setStyle(StyleRules.adding(.stroke, to: .none), name: "Add Layer Style", drag: nil)
        for layer in ws.layers {
            if case .adjustment = layer.kind { #expect(layer.style == .none) } else { #expect(layer.style != .none) }
        }
    }

    @Test(.disabled("waits on LS-6")) func oneHundredTwentySetsUnderOneDragUndoInOne() throws {
        var ws = try Self.twoLayers()
        _ = try PhotoWorkspace.catalog.run("style.add", params: .object(["kind": .string("dropShadow")]), on: &ws)
        let before = ws.layers, steps = ws.historySteps.count
        for i in 1...120 {
            let params = JSONValue.object(["kind": .string("dropShadow"), "distance": .number(Double(i) / 4), "drag": .string("d1")])
            _ = try PhotoWorkspace.catalog.run("style.set", params: params, on: &ws)
        }
        #expect(ws.historySteps.count == steps + 1)
        ws.undo()
        #expect(ws.layers == before)
    }
}
