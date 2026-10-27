// StyleCommandsTests.swift (layer-styles LS-1 written disabled, LS-6 turns it on and adds the
// drag, paste, panel and intent cases): the eleven style.* commands on a test target with a History.
import Testing
import SuiteImaging
import SuiteKernel

struct StyleTestTarget: LayerStyleTarget {
    var style = LayerStyle.none, selected = true, panel: StyleKind?
    var history = History<LayerStyle>()
    var styleSelection: LayerStyle? { selected ? style : nil }
    var styleHelp: String? { selected ? nil : StyleRules.noLayerHelp }
    var stylePanel: StyleKind? { panel }
    mutating func showStylePanel(_ kind: StyleKind?) { panel = kind }
    mutating func setStyle(_ new: LayerStyle, name: String, drag: String?) throws {
        history.record(name, style, key: drag.map { "style:\($0)" })
        style = new
    }
}

@Suite(.disabled("waits on LS-6")) struct StyleCommandsTests {
    /// The eleven ids and kinds; no selection blocks every one; copy needs a style.
    @Test func contractShape() throws {
        let catalog = try CommandCatalog(app: "test", StyleCommands.specs(StyleTestTarget.self)) { $0.history }
        #expect(catalog.ids == ["style.add", "style.clear", "style.copy", "style.enable", "style.fill-opacity", "style.panel",
                                "style.paste", "style.preset", "style.read", "style.remove", "style.set"])
        #expect(catalog.describeAll().filter { $0.kind == .edit }.count == 8)
        for id in catalog.ids { #expect(catalog.availability(id, on: StyleTestTarget(selected: false)).why == StyleRules.noLayerHelp) }
        #expect(catalog.availability("style.copy", on: StyleTestTarget()).why == "This layer has no style to copy.")
    }
}
