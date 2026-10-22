// HaloStrokeTrimKeysTests.swift: stroke-style HK-3, the trim rows' key
// diamonds (HaloStrokeTrimKeys.swift). A shape layer with a stroke lists
// Trim Start, End and Offset in that order, each with its track's key state
// at the playhead; no stroke, or any other kind of layer, lists none. While a
// reason is set a key is off and its click sends nothing; without one the
// diamond keys the property and the stopwatch animates it, on live services
// too (HK-7, J-HK step 3). Linux and macOS.
import FlareCore
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
        #expect(HaloProject.trimKeyHelp(.trimEnd, strokeHelp: "no stroke") { _ in "busy" } == "no stroke",
                "the stroke's reason comes first")
        #expect(HaloProject.trimKeyHelp(.trimEnd, strokeHelp: nil) { _ in "busy" } == "busy", "the property's own reason")
        #expect(HaloProject.trimKeyHelp(.trimEnd, strokeHelp: nil) { _ in nil } == nil, "no reason, the key acts")
        let busy = HaloTrimKey(raw: HaloProperty.x.rawValue, title: "X", keyState: .animated, help: "busy")
        #expect(HaloProject.trimKeyCommand(busy, diamond: true) == nil, "a reason sends nothing, property or not")
        let free = HaloTrimKey(raw: HaloProperty.x.rawValue, title: "X", keyState: .animated, help: nil)
        #expect(HaloProject.trimKeyCommand(free, diamond: true) == .toggleKey(.x))
        #expect(HaloProject.trimKeyCommand(free, diamond: false) == .toggleAnimation(.x))
        let unknown = HaloTrimKey(raw: "nope", title: "Nope", keyState: .animated, help: nil)
        #expect(HaloProject.trimKeyCommand(unknown, diamond: true) == nil, "no property, nothing to key")
        let keys = HaloProject.trimKeys(of: try Self.badge().selectedLayer, at: 0) { _ in "off" }
        #expect(keys.allSatisfy { $0.help == "off" && HaloProject.trimKeyCommand($0, diamond: false) == nil })
    }

    @Test func withoutAReasonTheDiamondKeysAndTheStopwatchAnimates() throws {
        let project = try Self.badge()
        let keys = HaloProject.trimKeys(of: project.selectedLayer, at: 0) { _ in nil }
        let end = try #require(keys.first { $0.raw == "trimEnd" })
        #expect(end.help == nil)
        #expect(HaloProject.trimKeyCommand(end, diamond: true) == .toggleKey(.trimEnd))
        #expect(HaloProject.trimKeyCommand(end, diamond: false) == .toggleAnimation(.trimEnd))
    }

    /// J-HK step 3 on live services: Trim End at 0 at frame 0, its stopwatch
    /// (the row's one control until it animates), then 100% at frame 24 is a
    /// draw-on keyed at 0 and 24.
    @Test func aStrokedShapesTrimKeysActOnLiveServicesAndDrawOn() throws {
        var doc = try #require(HaloFixtures.project("three-layers"))
        let i = try #require(doc.compositions.first?.layers.firstIndex { $0.name == "Badge" })
        doc.compositions[0].layers[i].stroke = VectorStroke(width: 8, trim: StrokeTrim(start: 0, end: 0))
        var project = HaloProject(services: .live, document: doc)
        project.selectLayer(doc.compositions[0].layers[i].id)
        let keys = project.trimKeys
        #expect(keys.map(\.help) == [nil, nil, nil], "the trim keys act once the trim properties exist")
        let end = try #require(keys.first { $0.raw == "trimEnd" })
        #expect(end.keyState == .notAnimated)
        #expect(HaloProject.trimKeyCommand(end, diamond: false) == .toggleAnimation(.trimEnd))
        project.toggleAnimation(.trimEnd)
        project.scrub(to: 24)
        try project.setStroke(VectorStroke(width: 8, trim: StrokeTrim(start: 0, end: 1)), name: "Trim Path", drag: nil)
        let frames = project.selectedLayer?.tracks["trimEnd"]?.map(\.frame) ?? []
        #expect(frames.contains(0) && frames.contains(24), "Trim End keyed at 0 and 24: \(frames)")
        #expect(project.trimKeys.first { $0.raw == "trimEnd" }?.keyState == .keyedHere)
        project.scrub(to: 0)
        #expect(project.selectedStroke?.trim?.end == 0)
        project.scrub(to: 12)
        let half = try #require(project.selectedStroke?.trim?.end)
        #expect(half > 0 && half < 1, "frame 12 is part-way drawn: \(half)")
    }
}
