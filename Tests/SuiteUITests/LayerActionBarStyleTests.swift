// LayerActionBarStyleTests.swift (layer-styles LS-3): the Layers panel's fx item is `style.panel`'s spec, so its
// title and reason match the menu item's. macOS only.
import SuiteImaging
@testable import SuiteUI
import Testing

@MainActor @Suite struct LayerActionBarStyleTests {
    /// fx is `style.panel`'s spec: its title, enabled on a layer, else disabled with the menu item's reason.
    @Test func fxIsTheStylePanelSpec() {
        let fx = LayerActionBar.styles(on: PanelTarget(help: nil), identifier: "suite.layers.fx") {}
        #expect(fx.title == "Layer Style Panel" && fx.unavailableHelp == nil && fx.identifier == "suite.layers.fx")
        let off = LayerActionBar.styles(on: PanelTarget(help: StyleRules.noLayerHelp), identifier: nil) {}
        #expect(off.unavailableHelp == "Layer Style Panel: \(StyleRules.noLayerHelp)")
    }
}

/// A target for the fx item: `help` is why the style commands can't run.
private struct PanelTarget: LayerStyleTarget {
    var help: String?
    var styleSelection: LayerStyle? { help == nil ? LayerStyle.none : nil }
    var styleHelp: String? { help }
    var stylePanel: StyleKind? { nil }
    mutating func showStylePanel(_ kind: StyleKind?) {}
    mutating func setStyle(_ style: LayerStyle, name: String, drag: String?) throws {}
}
