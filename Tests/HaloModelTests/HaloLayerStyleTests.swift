// HaloLayerStyleTests.swift: layer-styles MJ-HY, the Model walk. A layer's style saves under its own key and old
// projects re-save byte for byte (HY-1); the eleven `style.*` ids are in the catalog, the panel opens and closes,
// and the five style properties stay out of the transform rows (HY-1). The adapter's writes, keys and rows are
// run on HY-5's bodies. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct HaloLayerStyleTests {
    static let ids = ["style.read", "style.add", "style.remove", "style.enable", "style.set", "style.fill-opacity",
                      "style.preset", "style.copy", "style.paste", "style.clear", "style.panel"]

    /// A drop shadow 8 px away, 12 px soft at 60%, and an outer glow 10 px at 75%.
    static let lifted = LayerStyle(effects: [
        StyleEffect(kind: .dropShadow, isEnabled: true, blendMode: .multiply, opacity: 0.6,
                    parameters: .shadow(StyleShadow(color: .black, angle: 90, distance: 8, spread: 0, size: 12))),
        StyleEffect(kind: .outerGlow, isEnabled: true, blendMode: .screen, opacity: 0.75,
                    parameters: .glow(StyleGlow(color: .white, spread: 0, size: 10))),
    ], fillOpacity: 1)

    /// `three-layers` (Title text, Badge shape, Background solid, Rig null) with `name` selected.
    static func selecting(_ name: String) throws -> HaloProject {
        var project = HaloProject(services: .live)
        project.restore(try #require(HaloFixtures.project("three-layers")))
        let layers = try #require(project.selectedComposition?.layers)
        project.selectLayer(try #require(layers.first { $0.name == name }).id)
        return project
    }

    @Test func theElevenStyleIdsAreInTheCatalog() {
        let catalog = HaloProject.catalog
        #expect(Self.ids.allSatisfy { catalog.spec($0) != nil })
        #expect(catalog.ids.filter { $0.hasPrefix("style.") }.sorted() == Self.ids.sorted())
    }

    @Test(arguments: HaloFixtures.names.filter { $0 != "huge" })
    func oldProjectsReSaveByteForByte(name: String) throws {
        let files = LiveProjectFiles()
        let fixture = try #require(HaloFixtures.project(name))
        let first = try files.encode(fixture)
        #expect(String(decoding: first, as: UTF8.self).contains("\"style\"") == false)
        let decoded = try files.decode(first)
        #expect(decoded.compositions.flatMap(\.layers).allSatisfy { $0.style == nil })
        #expect(try files.encode(decoded) == first)
    }

    @Test func aStyleSavesUnderItsKeyAndComesBack() throws {
        var layer = HaloLayer(id: "t", name: "Title", kind: .text, inFrame: 0, outFrame: 10, color: HaloLayerKind.text.defaultColor)
        layer.style = Self.lifted
        let data = try JSONEncoder().encode(layer)
        #expect(String(decoding: data, as: UTF8.self).contains("\"style\""))
        let decoded = try JSONDecoder().decode(HaloLayer.self, from: data)
        #expect(decoded.style == Self.lifted)
        #expect(decoded.withID("u").style == Self.lifted)
    }

    @Test func anUnstyledLayerReadsAsNoStyleAndNoLayerAsNil() throws {
        #expect(HaloProject(services: .live).styleHelp == HaloProject.noStyleComposition)
        #expect(HaloProject(services: .live).styleSelection == nil)
        let project = try Self.selecting("Title")
        #expect(project.styleHelp == nil)
        #expect(project.styleSelection == LayerStyle.none)
    }

    @Test func thePanelOpensAndClosesWithoutAStep() throws {
        var project = try Self.selecting("Title")
        let steps = project.history.undo
        project.showStylePanel(.outerGlow)
        #expect(project.stylePanel == .outerGlow)
        project.showStylePanel(nil)
        #expect(project.stylePanel == nil)
        #expect(project.history.undo == steps)
    }

    @Test func styleValuesStayOutOfTheTransformRows() {
        #expect(HaloProperty.styles.allSatisfy { !HaloProperty.allCases.contains($0) })
        #expect(HaloProperty.glowSize.title == "Glow Size")
        #expect(HaloProperty.shadowOpacity.text(0.6) == "60%")
        #expect(HaloProperty.shadowDistance.text(8) == "8.0 px")
    }

    // HY-5: the adapter's bodies.

    @Test func anUnkeyedWriteUpdatesTheStyleInOneStep() throws {
        var project = try Self.selecting("Title")
        try project.setStyle(Self.lifted, name: "Add Outer Glow", drag: nil)
        let steps = project.history.undo.count
        project.setProperty(.glowSize, to: 20)
        #expect(project.history.undo.count == steps + 1)
        #expect(project.selectedLayer?.style?.effect(.outerGlow)?.parameters == .glow(StyleGlow(color: .white, spread: 0, size: 20)))
        #expect(project.selectedLayer?.tracks[HaloProperty.glowSize.rawValue] == nil)
    }

    @Test func aKeyedWriteSetsAKeyAtThePlayhead() throws {
        var project = try Self.selecting("Title")
        try project.setStyle(Self.lifted, name: "Add Outer Glow", drag: nil)
        project.toggleAnimation(.glowSize)
        project.scrub(to: 5)
        project.setProperty(.glowSize, to: 20)
        let track = try #require(project.selectedLayer?.tracks[HaloProperty.glowSize.rawValue])
        #expect(track.contains { $0.frame == 5 && $0.value == 20 })
    }

    @Test func rowsFollowTheEffects() throws {
        var project = try Self.selecting("Title")
        #expect(project.propertyRows.allSatisfy { !HaloProperty.styles.contains($0.property) })
        try project.setStyle(LayerStyle(effects: Array(Self.lifted.effects.prefix(1)), fillOpacity: 1), name: "Add Drop Shadow", drag: nil)
        #expect(project.propertyRows.map(\.property).filter(HaloProperty.styles.contains) == [HaloProperty.shadowDistance, .shadowSize, .shadowOpacity])
        try project.setStyle(Self.lifted, name: "Add Outer Glow", drag: nil)
        #expect(project.propertyRows.map(\.property).filter(HaloProperty.styles.contains) == HaloProperty.styles)
    }

    @Test func keysSurviveRemovingAndReAddingTheGlow() throws {
        var project = try Self.selecting("Title")
        try project.setStyle(Self.lifted, name: "Add Outer Glow", drag: nil)
        project.toggleAnimation(.glowSize)
        let track = project.selectedLayer?.tracks[HaloProperty.glowSize.rawValue]
        try project.setStyle(LayerStyle(effects: Array(Self.lifted.effects.prefix(1)), fillOpacity: 1), name: "Remove Outer Glow", drag: nil)
        #expect(project.propertyRows.contains { $0.property == .glowSize } == false)
        try project.setStyle(Self.lifted, name: "Add Outer Glow", drag: nil)
        #expect(project.selectedLayer?.tracks[HaloProperty.glowSize.rawValue] == track)
    }
}

// Packet-Review 1, amendments 1, 6, 7 and 8, written first: a style property runs through the catalog's property
// commands, `styleSelection` reads the style at the playhead, a panel write to a keyed number keys it there, Shadow
// Distance's range is StyleRules' 0 to 1,000, and a style track's keys show in the segment list, the lane and the
// easing pick.
extension HaloLayerStyleTests {
    /// Title with HaloLayerStyleTests' shadow and glow, Glow Size keyed 0 at frame 0 and 20 at frame 30.
    static func keyedGlow() throws -> HaloProject {
        var project = try Self.selecting("Title")
        try project.setStyle(Self.lifted, name: "Add Outer Glow", drag: nil)
        project.setProperty(.glowSize, to: 0)
        project.toggleAnimation(.glowSize)
        project.scrub(to: 30)
        project.setProperty(.glowSize, to: 20)
        return project
    }

    static func glowSize(_ style: LayerStyle?) -> Double? {
        guard case .glow(let g)? = style?.effect(.outerGlow)?.parameters else { return nil }
        return g.size
    }

    @Test func theCatalogKeysAStyleProperty() throws {
        var project = try Self.selecting("Title")
        try project.setStyle(Self.lifted, name: "Add Outer Glow", drag: nil)
        let glow: JSONValue = .object(["property": .string("glowSize")])
        _ = try HaloProject.catalog.run("inspector.toggle-animation", params: glow, on: &project)
        _ = try HaloProject.catalog.run("timeline.scrub", params: .object(["frame": .number(30)]), on: &project)
        let set: JSONValue = .object(["property": .string("glowSize"), "value": .number(20)])
        _ = try HaloProject.catalog.run("inspector.set-property", params: set, on: &project)
        let track = try #require(project.selectedLayer?.tracks[HaloProperty.glowSize.rawValue])
        #expect(track.contains { $0.frame == 30 && $0.value == 20 })
    }

    @Test func theSelectionIsTheStyleAtThePlayhead() throws {
        var project = try Self.keyedGlow()
        project.scrub(to: 15)
        #expect(Self.glowSize(project.styleSelection) == 10)
        project.scrub(to: 0)
        #expect(Self.glowSize(project.styleSelection) == 0)
    }

    @Test func aPanelWriteToAKeyedNumberKeysItAtThePlayhead() throws {
        var project = try Self.keyedGlow()
        project.scrub(to: 15)
        var style = try #require(project.styleSelection)
        style.effects = style.effects.map { e in
            guard e.kind == .outerGlow else { return e }
            var e = e
            e.parameters = .glow(StyleGlow(color: .white, spread: 0, size: 5))
            return e
        }
        try project.setStyle(style, name: "Change Outer Glow", drag: nil)
        let track = try #require(project.selectedLayer?.tracks[HaloProperty.glowSize.rawValue])
        #expect(track.contains { $0.frame == 15 && $0.value == 5 })
        #expect(track.contains { $0.frame == 30 && $0.value == 20 })
        #expect(Self.glowSize(project.styleSelection) == 5)
    }

    @Test func shadowDistanceRunsToAThousand() {
        #expect(HaloProperty.shadowDistance.range == 0...1_000)
    }

    @Test func aStyleTracksKeysShowEverywhereKeysDo() throws {
        let project = try Self.keyedGlow()
        #expect(project.keySegments.contains { $0.key.property == .glowSize && $0.key.frame == 0 })
        #expect(project.compositionKeys.filter { $0.property == .glowSize }.map(\.frame) == [0, 30, project.selectedComposition?.lastFrame ?? -1])
        let id = try #require(project.selectedLayerID)
        #expect(HaloEasingRules.keys(of: id, in: try #require(project.selectedComposition)).contains { $0.property == .glowSize })
    }
}
