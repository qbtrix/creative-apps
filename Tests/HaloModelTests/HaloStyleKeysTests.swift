// HaloStyleKeysTests.swift: layer-styles Packet-Review 1, amendments 1, 6, 7 and 8, written first. A style
// property runs through the catalog's property commands, `styleSelection` reads the style at the playhead,
// a panel write to a keyed number keys it there, Shadow Distance's range is StyleRules' 0 to 1,000, and a
// style track's keys show in the segment list, the lane and the easing pick. Linux and macOS.
@testable import HaloModel
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct HaloStyleKeysTests {
    /// Title with HaloLayerStyleTests' shadow and glow, Glow Size keyed 0 at frame 0 and 20 at frame 30.
    static func keyedGlow() throws -> HaloProject {
        var project = try HaloLayerStyleTests.selecting("Title")
        try project.setStyle(HaloLayerStyleTests.lifted, name: "Add Outer Glow", drag: nil)
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
        var project = try HaloLayerStyleTests.selecting("Title")
        try project.setStyle(HaloLayerStyleTests.lifted, name: "Add Outer Glow", drag: nil)
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
