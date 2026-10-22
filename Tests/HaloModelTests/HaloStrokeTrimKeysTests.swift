// HaloStrokeTrimKeysTests.swift: stroke-style HK-3, the trim rows' key
// diamonds (HaloStrokeTrimKeys.swift). A shape layer with a stroke lists
// Trim Start, End and Offset in that order, each with its track's key state
// at the playhead; no stroke, or any other kind of layer, lists none. While a
// reason is set a key is off and its click sends nothing; without one the
// diamond keys the property and the stopwatch animates it. Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloStrokeTrimKeysTests {
    /// `three-layers` with Badge (the shape) selected, stroked when `stroked`,
    /// and its Trim End keyed at 0 and 24, the playhead at `frame`.
    static func badge(stroked: Bool = true, frame: Int = 0) throws -> HaloProject {
        var doc = try #require(HaloFixtures.project("three-layers"))
        let i = try #require(doc.compositions.first?.layers.firstIndex { $0.name == "Badge" })
        if stroked { doc.compositions[0].layers[i].stroke = VectorStroke(width: 4) }
        doc.compositions[0].layers[i].tracks["trimEnd"] = HaloFixtures.keys([(0, 1), (24, 0.5)])
        var project = HaloProject(services: .fake, document: doc)
        project.selectLayer(doc.compositions[0].layers[i].id)
        project.scrub(to: frame)
        return project
    }

    @Test func aStrokedShapeListsTheThreeTrimKeysInOrder() throws {
        let keys = try Self.badge().trimKeys
        #expect(keys.map(\.raw) == ["trimStart", "trimEnd", "trimOffset"])
        #expect(keys.map(\.title) == ["Trim Start", "Trim End", "Trim Offset"])
    }

    @Test func noStrokeListsNoKeys() throws {
        #expect(try Self.badge(stroked: false).trimKeys.isEmpty, "a shape without a stroke has no trim rows")
    }

    @Test func otherLayersListNoKeys() throws {
        var doc = try #require(HaloFixtures.project("three-layers"))
        for i in doc.compositions[0].layers.indices { doc.compositions[0].layers[i].stroke = VectorStroke(width: 4) }
        for layer in doc.compositions[0].layers where layer.kind != .shape {
            #expect(HaloProject.trimKeys(of: layer, at: 0) { _ in nil }.isEmpty, "\(layer.name) takes no stroke")
        }
        #expect(HaloProject.trimKeys(of: nil, at: 0) { _ in nil }.isEmpty, "no layer, no keys")
    }

    @Test func eachKeyReadsItsTrackAtThePlayhead() throws {
        let here = try Self.badge(frame: 0).trimKeys
        #expect(here.map(\.keyState) == [.notAnimated, .keyedHere, .notAnimated])
        let between = try Self.badge(frame: 12).trimKeys
        #expect(between.map(\.keyState) == [.notAnimated, .animated, .notAnimated])
    }

    @Test func aReasonTurnsTheKeyOffAndItsClickSendsNothing() throws {
        #expect(HaloProject.trimKeyHelp("trimEnd", strokeHelp: "no stroke") { _ in "busy" } == "no stroke",
                "the stroke's reason comes first")
        #expect(HaloProject.trimKeyHelp("nope", strokeHelp: nil) { _ in nil } == HaloProject.trimKeysNotBuiltHelp,
                "a trim track with no property says keying the trim isn't built")
        #expect(HaloProject.trimKeyHelp("x", strokeHelp: nil) { _ in "busy" } == "busy", "the property's own reason")
        let busy = HaloTrimKey(raw: HaloProperty.x.rawValue, title: "X", keyState: .animated, help: "busy")
        #expect(HaloProject.trimKeyCommand(busy, diamond: true) == nil, "a reason sends nothing, property or not")
        let free = HaloTrimKey(raw: HaloProperty.x.rawValue, title: "X", keyState: .animated, help: nil)
        #expect(HaloProject.trimKeyCommand(free, diamond: true) == .toggleKey(.x))
        #expect(HaloProject.trimKeyCommand(free, diamond: false) == .toggleAnimation(.x))
    }

    @Test func aBuiltStrokesTrimKeysActOnTheirProperties() throws {
        let project = try Self.badge()
        #expect(project.strokeHelp == nil, "a stroked shape layer edits its stroke (HK-6)")
        let keys = project.trimKeys
        #expect(keys.allSatisfy { $0.help == nil }, "every trim key acts on a stroked shape")
        #expect(keys.map { HaloProject.trimKeyCommand($0, diamond: true) } == HaloProperty.trims.map { .toggleKey($0) })
        #expect(
            keys.map { HaloProject.trimKeyCommand($0, diamond: false) } == HaloProperty.trims.map { .toggleAnimation($0) })
    }

    @Test func withoutAReasonTheDiamondKeysAndTheStopwatchAnimates() throws {
        let project = try Self.badge()
        let keys = HaloProject.trimKeys(of: project.selectedLayer, at: 0) { _ in nil }
        let end = try #require(keys.first { $0.raw == "trimEnd" })
        #expect(end.help == nil)
        if let p = HaloProperty(rawValue: "trimEnd") {
            #expect(HaloProject.trimKeyCommand(end, diamond: true) == .toggleKey(p))
            #expect(HaloProject.trimKeyCommand(end, diamond: false) == .toggleAnimation(p))
        } else {
            #expect(HaloProject.trimKeyCommand(end, diamond: true) == nil, "no trim property yet (HK-5): nothing to key")
        }
    }
}
