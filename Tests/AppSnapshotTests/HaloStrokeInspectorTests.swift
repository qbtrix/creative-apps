// HaloStrokeInspectorTests.swift (stroke-style HK-3): STROKE's trim rows carry
// key diamonds. Each trim key the Model lists (HaloProject.trimKeys) gets a
// stopwatch and diamond identified `halo.inspector.key.<trim>`, the diamond
// shown once the track is animated; one diamond click sends one key toggle,
// one stopwatch click one animate toggle, and a key with a reason sends
// nothing. On the project the section reads the Model's keys. macOS only.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloStrokeInspectorTests {
    static let keys = [
        HaloTrimKey(raw: "trimStart", title: "Trim Start", keyState: .notAnimated, help: nil),
        HaloTrimKey(raw: "trimEnd", title: "Trim End", keyState: .keyedHere, help: nil),
        HaloTrimKey(raw: "trimOffset", title: "Trim Offset", keyState: .animated, help: nil),
    ]

    @Test func theTrimRowsCarryKeyDiamonds() {
        let section = HaloStrokeInspector(stroke: VectorStroke(width: 2), help: nil, trimKeys: Self.keys)
        #expect(section.trimKeys.map(\.raw) == ["trimStart", "trimEnd", "trimOffset"], "one key per trim row")
        #expect(HaloStrokeInspector.keyID(Self.keys[1]) == "halo.inspector.key.trimEnd")
        let diamonds = section.trimKeys.map { HaloPropertyRowView.keyState($0.keyState).diamond != nil }
        #expect(diamonds == [false, true, true], "a diamond once the trim track is animated")
    }

    @Test func oneDiamondClickEmitsOneKeyToggle() {
        var sent: [(String, Bool)] = []
        let section = HaloStrokeInspector(
            stroke: VectorStroke(width: 2), help: nil, trimKeys: Self.keys,
            toggleKey: { key, diamond in sent.append((key.raw, diamond)) })
        section.key(Self.keys[1], diamond: true)
        #expect(sent.count == 1, "one diamond click, one toggle")
        #expect(sent.first?.0 == "trimEnd" && sent.first?.1 == true, "the diamond keys Trim End")
        section.key(Self.keys[2], diamond: false)
        #expect(sent.count == 2 && sent.last?.1 == false, "the stopwatch animates")
    }

    @Test func aKeyWithAReasonSendsNothing() {
        var sent = 0
        let off = HaloTrimKey(raw: "trimEnd", title: "Trim End", keyState: .animated, help: "Not yet.")
        let section = HaloStrokeInspector(
            stroke: VectorStroke(width: 2), help: nil, trimKeys: [off], toggleKey: { _, _ in sent += 1 })
        section.key(off, diamond: true)
        #expect(sent == 0, "a disabled diamond sends no toggle")
    }

    @Test func theProjectSectionReadsTheModelsKeys() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        let badge = try #require(project.selectedComposition?.layers.first { $0.kind == .shape })
        project.selectLayer(badge.id)
        let section = HaloStrokeInspector(model: project, runStroke: { _ in })
        #expect(section.trimKeys == project.trimKeys)
    }
}
