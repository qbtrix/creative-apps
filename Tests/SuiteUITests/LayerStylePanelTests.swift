// LayerStylePanelTests.swift (layer-styles LS-3): the panel's controls send the right StyleIntent and nothing more. A
// switch sends one `.toggle`, a Distance scrub one `.set` per sample under one drag token, a preset one `.preset`, Done
// one `.show(nil)`; the gradient editor is there only for a gradient fill; every control has a `suite.style.*` id.
// macOS only.
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
        #expect(sent.isEmpty)
        #expect(none.allSatisfy { $0.reason == StyleRules.noLayerHelp })
    }

    @Test func aDistanceScrubSetsUnderOneDragToken() throws {
        let distance = try #require(StyleEdit.fields(StyleRules.defaults(.dropShadow)).first { $0.key == "distance" })
        #expect(distance.id == "suite.style.distance")
        var scrub = StyleScrub()
        var made = 0
        let make = { made += 1; return "drag-\(made)" }
        let sent = [4.0, 8, 12].map { scrub.intent(.dropShadow, StyleEdit.patch(distance, shown: $0), make: make) }
        #expect(sent == [4.0, 8, 12].map { StyleIntent.set(.dropShadow, .object(["distance": .number($0)]), drag: "drag-1") })
        scrub.end()
        #expect(scrub.intent(.dropShadow, StyleEdit.patch(distance, shown: 2), make: make)
            == .set(.dropShadow, .object(["distance": .number(2)]), drag: "drag-2"))

        let opacity = try #require(StyleEdit.fields(StyleRules.defaults(.dropShadow)).first { $0.key == "opacity" })
        #expect(StyleEdit.patch(opacity, shown: 50) == .object(["opacity": .number(0.5)]))
    }

    @Test func aPresetSendsOnePreset() {
        var sent: [StyleIntent] = []
        let items = LayerStylePanel.presetActions([lifted], blocked: nil) { sent.append($0) }
        #expect(items.map(\.title) == ["Lifted"])
        items.first?.perform()
        #expect(sent == [.preset("Lifted")])
        #expect(LayerStylePanel.presetsHelp([lifted], blocked: nil) == nil)
        #expect(LayerStylePanel.presetsHelp([], blocked: nil) != nil)
        #expect(LayerStylePanel.presetsHelp([lifted], blocked: StyleRules.noLayerHelp) == StyleRules.noLayerHelp)

        sent = []
        LayerStylePanel.done { sent.append($0) }.perform()
        #expect(sent == [.show(nil)])
    }

    @Test func theGradientEditorShowsOnlyForAGradientFill() {
        func editor(_ effect: StyleEffect) -> Bool { StyleEdit.fields(effect).contains(where: \.isGradient) }
        var stroke = StyleRules.defaults(.stroke)
        #expect(!editor(stroke))
        let linear = GradientRules.converted(.solid(.black), to: .linear, in: StyleEdit.unit)
        stroke.parameters = .stroke(StyleStroke(fill: linear, size: 3, position: .inside))
        #expect(editor(stroke))
        #expect(editor(StyleRules.defaults(.gradientOverlay)))
        for kind in StyleKind.allCases where kind != .gradientOverlay {
            #expect(!editor(StyleRules.defaults(kind)), "\(kind)")
        }

        // Solid to Gradient on a stroke sends the linear fill; the editor's gestures send the edited fill.
        let chips = StyleEdit.fields(StyleRules.defaults(.stroke)).first { $0.key == "fill" }
        let encoded = try? JSONValue(encoding: linear)
        #expect(chips.flatMap { StyleEdit.choose("gradient", field: $0, in: StyleRules.defaults(.stroke)) }
            == encoded.map { JSONValue.object(["fill": $0]) })
        let radial = GradientRules.converted(linear, to: .radial, in: StyleEdit.unit)
        #expect(StyleEdit.gradient(.type(.radial), on: linear)
            == (try? JSONValue(encoding: radial)).map { JSONValue.object(["fill": $0]) })
        #expect(StyleEdit.gradient(.type(.linear), on: linear) == nil)
        #expect(StyleEdit.drag(of: .angle(45, drag: "g")) == "g")
    }

    @Test func everyControlHasASuiteStyleID() {
        for kind in StyleKind.allCases {
            let ids = LayerStylePanel.controlIDs(style: shadow, selected: kind, presets: [lifted])
            #expect(ids.allSatisfy { $0.hasPrefix("suite.style.") }, "\(kind)")
            #expect(Set(ids).count == ids.count, "\(kind)")
        }
        let shadowIDs = LayerStylePanel.controlIDs(style: shadow, selected: .dropShadow, presets: [lifted])
        for id in ["suite.style.kind.dropShadow", "suite.style.toggle.bevel", "suite.style.distance", "suite.style.angle",
                   "suite.style.opacity", "suite.style.blend", "suite.style.color", "suite.style.fill-opacity",
                   "suite.style.presets", "suite.style.preset.Lifted", "suite.style.done"] {
            #expect(shadowIDs.contains(id), "\(id)")
        }
        let strokeIDs = LayerStylePanel.controlIDs(style: shadow, selected: .stroke, presets: [])
        #expect(strokeIDs.contains("suite.style.position.inside"))
        #expect(strokeIDs.contains("suite.style.fill.gradient"))
        #expect(LayerStylePanel.controlIDs(style: shadow, selected: .bevel, presets: []).contains("suite.style.altitude"))
        #expect(LayerStylePanel.controlIDs(style: shadow, selected: .gradientOverlay, presets: [])
            .contains("suite.style.gradient.type"))
        #expect(LayerStyleText.words("colorDodge") == "Color Dodge")
    }
}
