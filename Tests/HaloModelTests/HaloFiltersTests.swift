// HaloFiltersTests.swift (adjust-everywhere AJ-12): a layer's list of filters and kinds draws on that layer's
// pixels before its blend, round-trips in a .halo file, writes no key while empty, and each change through the
// catalog is one undo step that edits in place.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import HaloModel
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct HaloFiltersTests {
    static let ball = "comp-1-layer-2", frame = 12
    /// `keyed` with Ball selected.
    static func ballSelected() -> HaloProject {
        var project = commandProject("keyed", .fake)
        project.selectLayer(ball)
        return project
    }
    static func blur(_ radius: Double, on project: inout HaloProject) throws {
        _ = try HaloProject.catalog.run("filter.gaussian-blur", params: .object(["radius": .number(radius)]), on: &project)
    }
    static func render(_ project: HaloProject) throws -> PixelBuffer {
        let comp = try #require(project.selectedComposition)
        return try #require(comp.renderFrame(at: frame)).pixels
    }

    /// Ball's blur changes Ball's edge and nothing farther from Ball than the blur reaches, so the floor's edge
    /// (which a blur of the whole frame would soften) stays as it was.
    @Test func blurDrawsOnItsLayerBeforeTheBlend() throws {
        var project = Self.ballSelected()
        let plain = try Self.render(project)
        try Self.blur(8, on: &project)
        let blurred = try Self.render(project)
        let comp = try #require(project.selectedComposition)
        let box = try #require(LiveFrameDrawing().drawList(comp, at: Self.frame).worldBox(of: Self.ball))
        let s = 1 / Double(HaloComposition.previewScale), reach = 3 * 8 * s + 2
        var changed = 0
        for y in 0..<plain.height {
            for x in 0..<plain.width {
                let a = try plain.pixel(x: x, y: y), b = try blurred.pixel(x: x, y: y)
                guard abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b) + abs(a.a - b.a) > 1e-5 else { continue }
                changed += 1
                let px = Double(x) + 0.5, py = Double(y) + 0.5
                let near = px >= box.x * s - reach && px <= (box.x + box.width) * s + reach
                    && py >= box.y * s - reach && py <= (box.y + box.height) * s + reach
                #expect(near, "pixel \(x),\(y) changed away from Ball")
                if !near { return }
            }
        }
        #expect(changed > 0, "the blur changes Ball's edge")
    }

    @Test func hiddenFilterDoesNotDraw() throws {
        var project = Self.ballSelected()
        let plain = try Self.render(project)
        try Self.blur(8, on: &project)
        _ = try HaloProject.catalog.run("filter.set-hidden", params: .object(["id": .string("gaussian-blur"), "hidden": .bool(true)]),
                                        on: &project)
        #expect(project.selectedLayer?.filters.first?.hidden == true)
        #expect(try Self.render(project) == plain)
    }

    @Test func invertKindDraws() throws {
        var project = Self.ballSelected()
        let plain = try Self.render(project)
        _ = try HaloProject.catalog.run("adjust.invert", params: .object([:]), on: &project)
        #expect(project.selectedLayer?.filters.map(\.id) == ["invert"])
        #expect(try Self.render(project) != plain)
    }

    @Test func roundTripsInTheFile() throws {
        var project = Self.ballSelected()
        try Self.blur(6, on: &project)
        _ = try HaloProject.catalog.run("filter.set-hidden", params: .object(["id": .string("gaussian-blur"), "hidden": .bool(true)]),
                                        on: &project)
        let state = try HaloFileFormat.unwrap(project.fileData())
        let layer = try #require(state.compositions.first?.layers.first { $0.id == Self.ball })
        #expect(layer.filters == [HaloLayerFilter(.filter(.gaussianBlur(radius: 6)), hidden: true)])
    }

    @Test func emptyListWritesNoKey() throws {
        let project = Self.ballSelected()
        let before = try project.fileData()
        #expect(String(decoding: before, as: UTF8.self).contains("\"filters\"") == false)
        var edited = project
        try Self.blur(6, on: &edited)
        #expect(String(decoding: try edited.fileData(), as: UTF8.self).contains("\"filters\""))
        _ = try HaloProject.catalog.run("filter.remove", params: .object(["id": .string("gaussian-blur")]), on: &edited)
        #expect(try edited.fileData() == before, "add then remove leaves the old bytes")
    }

    @Test func secondBlurEditsInPlace() throws {
        var project = Self.ballSelected()
        try Self.blur(6, on: &project)
        _ = try HaloProject.catalog.run("adjust.invert", params: .object([:]), on: &project)
        let steps = project.history.undo.count
        try Self.blur(2, on: &project)
        #expect(project.selectedLayer?.filters == [HaloLayerFilter(.filter(.gaussianBlur(radius: 2))), HaloLayerFilter(.kind(.invert))])
        #expect(project.history.undo.count == steps + 1 && project.undoTitle == "Undo Gaussian Blur")
        project.undo()
        #expect(project.selectedLayer?.filters.first == HaloLayerFilter(.filter(.gaussianBlur(radius: 6))))
    }

    @Test func availabilitySaysWhy() throws {
        let catalog = HaloProject.catalog
        #expect(catalog.availability("filter.gaussian-blur", on: HaloProject(services: .fake)).why == HaloProject.noFilterComposition)
        #expect(catalog.availability("filter.gaussian-blur", on: commandProject("keyed", .fake)).why == HaloProject.noFilterLayer)
        #expect(catalog.availability("adjust.invert", on: Self.ballSelected()).why == nil)
        var null = Self.ballSelected()
        null.newLayer(.null)
        #expect(catalog.availability("filter.gaussian-blur", on: null).why == HaloProject.nullTakesNoFilter)
    }
}
