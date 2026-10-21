// HaloGradientTests.swift: gradient-fill MJ-HG, the Model walk. A layer's
// gradient saves under its own key and old projects open without one (HG-1);
// the fill commands on a solid, a refused text layer and a drag that is one
// undo step run on HG-7's conformance bodies. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloGradientTests {
    /// Black at the centre of the unit box to white at its edge.
    static let radial = Fill.radial(
        stops: [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 0)), GradientStop(offset: 1, color: .white)],
        center: Point(x: 0.5, y: 0.5), radius: 0.5)

    /// `three-layers` with the layer named `select` selected.
    static func project(select: String) throws -> HaloProject {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("three-layers")))
        project.selectLayer(try #require(project.selectedComposition?.layers.first { $0.name == select }).id)
        return project
    }

    @Test func oldProjectsOpenWithoutAGradient() throws {
        let state = try #require(HaloFixtures.project("three-layers"))
        let data = try JSONEncoder().encode(state)
        #expect(String(decoding: data, as: UTF8.self).contains("\"gradient\"") == false)
        let decoded = try JSONDecoder().decode(HaloDocumentState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.compositions.flatMap(\.layers).allSatisfy { $0.gradient == nil })
    }

    @Test func aGradientSavesUnderItsKeyAndComesBack() throws {
        var layer = HaloLayer(
            id: "s", name: "Solid", kind: .solid, inFrame: 0, outFrame: 10, color: HaloLayerKind.solid.defaultColor)
        layer.gradient = Self.radial
        let data = try JSONEncoder().encode(layer)
        #expect(String(decoding: data, as: UTF8.self).contains("\"gradient\""))
        let decoded = try JSONDecoder().decode(HaloLayer.self, from: data)
        #expect(decoded.gradient == Self.radial)
        #expect(decoded.withID("t").gradient == Self.radial)
    }

    @Test func radialOnASolidStoresAUnitBoxFill() throws {
        var project = try Self.project(select: "Background")
        #expect(project.fillHelp == nil)
        project.runFill(.type(.radial))
        let layer = try #require(project.selectedLayer)
        guard case .radial(_, let center, let radius) = layer.gradient else {
            Issue.record("no radial gradient stored"); return
        }
        #expect((0...1).contains(center.x) && (0...1).contains(center.y) && radius > 0 && radius <= 1)
        #expect(project.history.undoTitle == "Undo Change Fill")
        let selection = try #require(project.fillSelection)
        #expect(selection.box.maxX > 1)  // the layer's box in composition pixels, not the unit box
    }

    @Test func textRefuses() throws {
        var project = try Self.project(select: "Title")
        #expect(project.fillSelection == nil)
        #expect(project.fillHelp?.isEmpty == false)
        let before = project.document
        project.runFill(.type(.radial))
        #expect(project.document == before)
        #expect(project.history.undo.isEmpty)
    }

    @Test func dragIsOneStep() throws {
        var project = try Self.project(select: "Badge")
        project.runFill(.type(.linear))
        let steps = project.history.undo.count
        for i in 1...120 { project.runFill(.move(index: 0, offset: Double(i) / 240, drag: "stop-drag")) }
        #expect(project.history.undo.count == steps + 1)
        let stops = try #require(project.fillSelection?.fill.stops)
        #expect(abs((stops.first?.offset ?? 0) - 0.5) < 1e-9)
    }
}
