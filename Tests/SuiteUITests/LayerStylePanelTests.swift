// LayerStylePanelTests.swift (layer-styles LS-3): each control sends the right StyleIntent and nothing more, the
// gradient editor shows only for a gradient fill, and every control has a `suite.style.*` id. macOS only.
import SuiteImaging
import SuiteKernel
@testable import SuiteUI
import Testing

@MainActor @Suite struct LayerStylePanelTests {
    private let shadow = LayerStyle(effects: [StyleRules.defaults(.dropShadow)], fillOpacity: 1)
    private let lifted = StylePreset(name: "Lifted", style: LayerStyle(effects: [StyleRules.defaults(.dropShadow)], fillOpacity: 1))

    @Test func aSwitchSendsOneToggle() {
        var sent: [StyleIntent] = []
        let switches = LayerStylePanel.switches(style: shadow, help: nil) { sent.append($0) }
        #expect(switches.map(\.id) == StyleKind.allCases.map(LayerStyleText.toggleID))
        let drop = switches.first { $0.kind == .dropShadow }
        #expect(drop?.isOn == true)
        drop?.set(false)
        drop?.set(true)  // already on: nothing to send
        #expect(sent == [.toggle(.dropShadow, false)])
        sent = []
        let none = LayerStylePanel.switches(style: nil, help: nil) { sent.append($0) }
        none.first?.set(true)
        #expect(sent.isEmpty && none.allSatisfy { $0.reason == StyleRules.noLayerHelp })
    }

    @Test func aDistanceScrubSetsUnderOneDragToken() throws {
        let fields = StyleEdit.fields(StyleRules.defaults(.dropShadow))
        let distance = try #require(fields.first { $0.key == "distance" })
        #expect(distance.id == "suite.style.distance")
        var scrub = StyleScrub()
        var made = 0
        let make = { made += 1; return "drag-\(made)" }
        let sent = [4.0, 8, 12].map { scrub.intent(.dropShadow, StyleEdit.patch(distance, shown: $0), make: make) }
        #expect(sent == [4.0, 8, 12].map { StyleIntent.set(.dropShadow, .object(["distance": .number($0)]), drag: "drag-1") })
        scrub.end()
        #expect(scrub.intent(.dropShadow, StyleEdit.patch(distance, shown: 2), make: make)
            == .set(.dropShadow, .object(["distance": .number(2)]), drag: "drag-2"))
        let opacity = try #require(fields.first { $0.key == "opacity" })
        #expect(StyleEdit.patch(opacity, shown: 50) == .object(["opacity": .number(0.5)]))
    }

    @Test func aPresetSendsOnePresetAndDoneCloses() {
        var sent: [StyleIntent] = []
        let items = LayerStylePanel.presetActions([lifted], blocked: nil) { sent.append($0) }
        #expect(items.map(\.title) == ["Lifted"])
        items.first?.perform()
        LayerStylePanel.done { sent.append($0) }.perform()
        #expect(sent == [.preset("Lifted"), .show(nil)])
        #expect(LayerStylePanel.presetsHelp([lifted], blocked: nil) == nil)
        #expect(LayerStylePanel.presetsHelp([], blocked: nil) != nil)
        #expect(LayerStylePanel.presetsHelp([lifted], blocked: StyleRules.noLayerHelp) == StyleRules.noLayerHelp)
    }

    @Test func theGradientEditorShowsOnlyForAGradientFill() {
        func editor(_ effect: StyleEffect) -> Bool { StyleEdit.fields(effect).contains(where: \.isGradient) }
        var stroke = StyleRules.defaults(.stroke)
        let linear = GradientRules.converted(.solid(.black), to: .linear, in: StyleEdit.unit)
        stroke.parameters = .stroke(StyleStroke(fill: linear, size: 3, position: .inside))
        #expect(editor(stroke) && editor(StyleRules.defaults(.gradientOverlay)))
        for kind in StyleKind.allCases where kind != .gradientOverlay { #expect(!editor(StyleRules.defaults(kind)), "\(kind)") }

        // Solid to Gradient on a stroke sends the linear fill; the editor's gestures send the edited fill.
        let chips = StyleEdit.fields(StyleRules.defaults(.stroke)).first { $0.key == "fill" }
        #expect(chips.flatMap { StyleEdit.choose("gradient", field: $0, in: StyleRules.defaults(.stroke)) }
            == (try? JSONValue(encoding: linear)).map { JSONValue.object(["fill": $0]) })
        let radial = GradientRules.converted(linear, to: .radial, in: StyleEdit.unit)
        #expect(StyleEdit.gradient(.type(.radial), on: linear) == (try? JSONValue(encoding: radial)).map { JSONValue.object(["fill": $0]) })
        #expect(StyleEdit.gradient(.type(.linear), on: linear) == nil)
        #expect(StyleEdit.drag(of: .angle(45, drag: "g")) == "g")
    }

    @Test func everyControlHasASuiteStyleID() {
        for kind in StyleKind.allCases {
            let ids = LayerStylePanel.controlIDs(style: shadow, selected: kind, presets: [lifted])
            #expect(ids.allSatisfy { $0.hasPrefix("suite.style.") } && Set(ids).count == ids.count, "\(kind)")
        }
        let ids = { LayerStylePanel.controlIDs(style: shadow, selected: $0, presets: [lifted]) }
        let expected = ["dropShadow": ["kind.dropShadow", "toggle.bevel", "distance", "angle", "opacity", "blend", "color",
                                       "fill-opacity", "presets", "preset.Lifted", "done"],
                        "stroke": ["position.inside", "fill.gradient"], "bevel": ["altitude"], "gradientOverlay": ["gradient.type"]]
        for (kind, names) in expected {
            let shown = StyleKind(rawValue: kind).map(ids) ?? []
            for name in names { #expect(shown.contains("suite.style.\(name)"), "\(kind): \(name)") }
        }
        #expect(LayerStyleText.words("colorDodge") == "Color Dodge")
    }
}
