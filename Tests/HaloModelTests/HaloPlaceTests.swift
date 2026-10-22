// HaloPlaceTests.swift: placed-images MJ-PH, the Model walk. A solid's picture and focus are coded only when
// set, so every saved project re-saves byte-equal, and a duplicate keeps them (PH-1). The place commands wait on PH-6.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloPlaceTests {
    /// The repo's root: three folders up from this file.
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Every saved `.halo` file the tests and real jobs read, as repo paths.
    static func savedProjects() -> [String] {
        let ls = { (dir: String) in (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(dir).path)) ?? [] }
        let folders = ls("Tests/RealJobs/halo").map { "Tests/RealJobs/halo/\($0)/input" } + ["Tests/HaloModelTests/Fixtures"]
        return folders.flatMap { folder in ls(folder).filter { $0.hasSuffix(".halo") }.map { "\(folder)/\($0)" } }.sorted()
    }

    /// A 2 × 1 PNG's bytes stand in for a file: these tests never decode it.
    static let asset = PlacedAsset(id: "a-1", name: "logo.png", format: .png, natural: Size(width: 200, height: 100), data: Data([1, 2, 3]))

    /// A 200 × 100 PNG, a red left half and a blue right half (RJ-H36's logo).
    static let logoPNG = Data(base64Encoded: HaloPlaceRenderTests.logoBase64) ?? Data()

    /// `three-layers` with the layer named `select` selected.
    static func project(select: String) throws -> HaloProject {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("three-layers")))
        project.selectLayer(try #require(project.selectedComposition?.layers.first { $0.name == select }).id)
        return project
    }

    static let frame = Rect(minX: 0, minY: 0, maxX: 1920, maxY: 1080)

    static func place(_ fill: Bool = false) -> JSONValue {
        .object(["name": .string("logo.png"), "base64": .string(logoPNG.base64EncodedString()), "fill": .bool(fill)])
    }

    @Test func everySavedProjectOpensAndSavesByteEqual() throws {
        let paths = Self.savedProjects()
        #expect(paths.count >= 10)
        let files = LiveProjectFiles()
        for path in paths {
            var data = try Data(contentsOf: Self.root.appendingPathComponent(path))
            if data.last == UInt8(ascii: "\n") { data.removeLast() }  // three hand-written jobs end in a newline
            let saved = try files.encode(try files.decode(data))
            #expect(saved == data, "\(path) changed on a re-save")
            #expect(!String(decoding: saved, as: UTF8.self).contains("placed"), "\(path) gained a picture key")
        }
    }

    @Test func aPictureAndItsFocusSaveOnlyWhenSet() throws {
        var layer = HaloLayer(id: "s", name: "Solid", kind: .solid, inFrame: 0, outFrame: 10, color: HaloLayerKind.solid.defaultColor)
        #expect(layer.placedFocus == Point(x: 0.5, y: 0.5))
        layer.placedAsset = Self.asset
        let unfocused = String(decoding: try JSONEncoder().encode(layer), as: UTF8.self)
        #expect(unfocused.contains("\"placedAsset\"") && !unfocused.contains("\"placedFocus\""))
        layer.placedFocus = Point(x: 0.25, y: 0.75)
        let decoded = try JSONDecoder().decode(HaloLayer.self, from: try JSONEncoder().encode(layer))
        #expect(decoded == layer)
        #expect(decoded.placedAsset == Self.asset && decoded.placedFocus == Point(x: 0.25, y: 0.75))
    }

    @Test func aDuplicatedSolidKeepsItsPicture() throws {
        var project = try Self.project(select: "Background")
        let (c, l) = try project.document.selectedLayerIndices()
        project.document.compositions[c].layers[l].placedAsset = Self.asset
        project.document.compositions[c].layers[l].placedFocus = Point(x: 0, y: 1)
        project.duplicateSelectedLayer()
        let copy = try #require(project.selectedLayer)
        #expect(copy.name == "Background copy")
        #expect(copy.placedAsset == Self.asset && copy.placedFocus == Point(x: 0, y: 1))
        let selection = try #require(project.placedSelection)
        #expect(selection.id == copy.id && selection.asset == Self.asset)
        #expect(selection.image == PlacedImage(assetID: "a-1", box: Self.frame, focus: Point(x: 0, y: 1)))
    }

    @Test func theTargetReadsTheCompositionAndTheSelectedSolid() throws {
        let solid = try Self.project(select: "Background"), text = try Self.project(select: "Title")
        #expect(solid.placeCanvas == Self.frame && solid.placeFillBox == Self.frame && solid.placeFormats == [.png, .jpeg, .svg])
        #expect(text.placeFillBox == nil && text.placedSelection == nil)
        #expect(try solid.rasterSize(Self.logoPNG, format: .png) == Size(width: 200, height: 100))
        #expect(HaloProject(services: .fake).placeHelp?.isEmpty == false)
    }

    @Test(.disabled("waits on PH-6")) func placeAddsAClearSolidAtTheFittedBoxOnTopOfTheSelection() throws {
        var project = try Self.project(select: "Badge")
        let id = try HaloProject.catalog.run("place.image", params: Self.place(), on: &project).result
        let layers = try #require(project.selectedComposition?.layers)
        let placed = try #require(layers.first { .string($0.id) == id || .object(["id": .string($0.id)]) == id })
        #expect(layers.map(\.name) == ["Title", "logo", "Badge", "Background", "Rig"])
        #expect(placed.kind == .solid && placed.placedAsset?.natural == Size(width: 200, height: 100))
        #expect(placed.rect == HaloLayerRect(x: 860, y: 490, width: 200, height: 100))
        #expect(project.selectedLayerID == placed.id && project.history.undoTitle == "Undo Place Image")
    }

    @Test(.disabled("waits on PH-6")) func textRefusesFill() throws {
        var project = try Self.project(select: "Title")
        let before = project.document
        #expect(throws: CatalogError.self) { try HaloProject.catalog.run("place.image", params: Self.place(true), on: &project) }
        #expect(project.document == before && project.placeFillBox == nil)
    }

    @Test(.disabled("waits on PH-6")) func focusDragIsOneStep() throws {
        var project = try Self.project(select: "Background")
        _ = try HaloProject.catalog.run("place.image", params: Self.place(true), on: &project)
        let steps = project.history.undo.count
        for i in 1...30 {
            let focus = PlaceIntent.focus(Point(x: Double(i) / 30, y: 0.5), drag: "focus-drag").command
            _ = try HaloProject.catalog.run(focus.id, params: focus.params, on: &project)
        }
        #expect(project.history.undo.count == steps + 1)
        #expect(project.selectedLayer?.placedFocus == Point(x: 1, y: 0.5))
    }

    @Test(.disabled("waits on PH-6")) func undoOfAPlaceRemovesTheSolid() throws {
        var project = try Self.project(select: "Badge")
        let before = project.document
        _ = try HaloProject.catalog.run("place.image", params: Self.place(), on: &project)
        project.undo()
        #expect(project.document == before)
        #expect(project.selectedComposition?.layers.allSatisfy { $0.placedAsset == nil } == true)
    }
}
