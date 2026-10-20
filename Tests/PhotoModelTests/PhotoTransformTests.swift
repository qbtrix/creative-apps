// PhotoTransformTests.swift: Photo's Free Transform and flips through the
// kernel's TransformTarget (transform PT-1 writes them, PT-5 turns them on).
// MJ-PT, the Model walk of the feature's journey, is `freeTransformWalk`;
// RJ-P17, the real job, is `freeTransformRealJob`, run here on PhotoHeadless
// since the CLI's harness can't decode its pixels yet. Runs on Linux and macOS.
import CoreRaster
import Foundation
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoTransformTests {
    /// A 64 x 48 image under a 20 x 10 "logo" layer pasted about `center`;
    /// every pixel of the logo differs from its mirror, so a flip shows.
    private func logoOnPhoto(_ services: PhotoServices = .live, center: Mask.Point = Mask.Point(x: 32, y: 24))
        throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: services)
        try workspace.newCanvas(width: 64, height: 48)
        var bytes: [UInt8] = []
        for y in 0..<10 { for x in 0..<20 { bytes += [UInt8(x * 12), UInt8(y * 25), 40, 255] } }
        let logo = DecodedImage(rgba8: bytes, width: 20, height: 10)
        workspace.paste(ClipboardImage(image: logo, source: PixelRect(x: 8, y: 6, width: 20, height: 10)),
                        viewCenter: center)
        return workspace
    }

    /// A transform service that refuses, as a locked layer does.
    private struct LockedTransform: LayerTransforming {
        var unavailableHelp: String? { "The layer is locked." }
        let base = FakeTransform()
        func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle? {
            base.handle(at: point, in: draft, tolerance: tolerance)
        }
        func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point, to point: Mask.Point,
                     modifiers: DragModifiers) -> TransformDraft {
            base.dragged(draft, handle: handle, from: start, to: point, modifiers: modifiers)
        }
        func corners(of draft: TransformDraft) -> [Mask.Point] { base.corners(of: draft) }
        func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels {
            try base.applied(draft, to: content)
        }
        func flipped(_ content: PlacedPixels, _ axis: PhotoModel.FlipAxis) throws -> PlacedPixels { try base.flipped(content, axis) }
    }

    /// The selected layer's pixels, flattened.
    private func layerPixels(_ workspace: PhotoWorkspace) throws -> PixelBuffer {
        let id = try #require(workspace.selectedLayerID)
        return try #require(workspace.pixels[id]).flattened()
    }

    /// Whether `a` and `b` are the same box within `tolerance` on every side.
    private func near(_ a: Rect, _ b: Rect, _ tolerance: Double = 1) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.maxX - b.maxX) <= tolerance && abs(a.maxY - b.maxY) <= tolerance
    }

    @Test func aLayerWithoutPixelsRefusesWithItsHelp() throws {
        var workspace = try logoOnPhoto(.fake)
        workspace.addAdjustmentLayer(.exposure)
        #expect(workspace.selectedLayer?.kind != .pixels)
        #expect(workspace.transformHelp == "Select a pixel layer to transform.")
        #expect(workspace.transformSelection == nil)
        #expect(throws: PhotoRefusal("Select a pixel layer to transform.")) { try workspace.beginTransform() }
        #expect(workspace.transformDraft == nil)
    }

    @Test func cancelDropsTheDraftAndRecordsNothing() throws {
        var workspace = try logoOnPhoto(.fake)
        let steps = workspace.historySteps
        let logo = try #require(workspace.selectedLayer)
        let (x, y) = (logo.offsetX, logo.offsetY)
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.layerID == logo.id)
        #expect(workspace.transformDraft?.box == PixelRect(x: x, y: y, width: 20, height: 10))
        let box = Rect(minX: Double(x), minY: Double(y), maxX: Double(x + 20), maxY: Double(y + 10))
        #expect(workspace.transformSelection == TransformBox(box: box))
        workspace.cancelTransform()
        #expect(workspace.transformDraft == nil)
        #expect(workspace.historySteps == steps)
    }

    @Test func aScaleAndATurnAreOneDraftStepEach() throws {
        var workspace = try logoOnPhoto()
        let before = try layerPixels(workspace), steps = workspace.historySteps.count
        try workspace.beginTransform()
        let box = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.scaled(box, sx: 0.5, sy: 0.5, about: .topLeft), name: "Scale", drag: nil)
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.historySteps.last == "Scale")
        let scaled = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.rotated(scaled, by: 15), name: "Rotate", drag: nil)
        #expect(workspace.historySteps.count == steps + 2)
        #expect(workspace.transformSelection?.degrees == 15)
        let half = Rect(minX: box.box.minX, minY: box.box.minY, maxX: box.box.minX + 10, maxY: box.box.minY + 5)
        #expect(near(try #require(workspace.transformSelection).box, half, 1e-9))
        #expect(try layerPixels(workspace) == before, "a draft previews; the pixels wait for the commit")
        workspace.undo()
        #expect(workspace.transformSelection?.degrees == 0, "undo walks back through the draft")
    }

    @Test func oneStepPerGesture() throws {
        var workspace = try logoOnPhoto()
        try workspace.beginTransform()
        let steps = workspace.historySteps.count
        for degrees in stride(from: 1.0, through: 30, by: 1) {
            let box = try #require(workspace.transformSelection)
            try workspace.setTransform(TransformRules.rotated(box, by: 1), name: "Rotate", drag: "handle-1")
            #expect(workspace.transformSelection?.degrees == degrees)
        }
        #expect(workspace.historySteps.count == steps + 1)
        try workspace.commitTransform()
        #expect(workspace.historySteps.count == steps + 2)
        let flipped = TransformRules.flipped(try #require(workspace.transformSelection), .horizontal)
        try workspace.setTransform(flipped, name: "Flip Horizontal", drag: nil)
        #expect(workspace.historySteps.count == steps + 3)
    }

    @Test func commitIsOneFreeTransformStep() throws {
        var workspace = try logoOnPhoto()
        try workspace.beginTransform()
        let box = try #require(workspace.transformSelection)
        let turned = TransformRules.rotated(TransformRules.scaled(box, sx: 0.5, sy: 0.5, about: .topLeft), by: 15)
        try workspace.setTransform(turned, name: "Transform", drag: nil)
        let steps = workspace.historySteps.count
        try workspace.commitTransform()
        #expect(workspace.transformDraft == nil)
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.historySteps.last == "Free Transform")
        let layer = try #require(workspace.selectedLayer), pixels = try layerPixels(workspace)
        let placed = Rect(minX: Double(layer.offsetX), minY: Double(layer.offsetY),
                          maxX: Double(layer.offsetX + pixels.width), maxY: Double(layer.offsetY + pixels.height))
        #expect(near(placed, TransformRules.bounds(of: turned)), "the layer lands on the turned box's bounds")
    }

    @Test func theIdentityCommitsNothing() throws {
        var workspace = try logoOnPhoto()
        let before = try layerPixels(workspace), steps = workspace.historySteps
        try workspace.beginTransform()
        try workspace.commitTransform()
        #expect(workspace.transformDraft == nil)
        #expect(workspace.historySteps == steps)
        #expect(try layerPixels(workspace) == before)
    }

    @Test func aFlipIsOneStepAndKeepsTheLayersBounds() throws {
        var workspace = try logoOnPhoto(center: Mask.Point(x: 20, y: 16)) // off the canvas's centre lines
        let before = try layerPixels(workspace), steps = workspace.historySteps.count
        let layer = try #require(workspace.selectedLayer)
        let box = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.flipped(box, .horizontal), name: "Flip Horizontal", drag: nil)
        #expect(workspace.transformDraft == nil, "a flip applies at once, never a draft")
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.historySteps.last == "Flip Horizontal")
        #expect(workspace.selectedLayer?.offsetX == layer.offsetX && workspace.selectedLayer?.offsetY == layer.offsetY,
                "the layer mirrors in place, not about the canvas")
        let once = try layerPixels(workspace)
        #expect(once != before && once.width == before.width && once.height == before.height)
        let again = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.flipped(again, .horizontal), name: "Flip Horizontal", drag: nil)
        #expect(try layerPixels(workspace) == before, "twice gives the layer back")
    }

    @Test func cancelAfterDraftStepsKeepsThePixels() throws {
        var workspace = try logoOnPhoto()
        let before = try layerPixels(workspace)
        try workspace.beginTransform()
        let box = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.rotated(box, by: 30), name: "Rotate", drag: nil)
        let steps = workspace.historySteps.count
        workspace.cancelTransform()
        #expect(workspace.transformDraft == nil)
        #expect(workspace.historySteps.count <= steps, "cancel records nothing")
        #expect(try layerPixels(workspace) == before)
    }

    @Test func aLockedLayerRefusesWithItsHelp() throws {
        var services = PhotoServices.fake
        services.transform = LockedTransform()
        var workspace = try logoOnPhoto(services)
        let steps = workspace.historySteps, logo = try #require(workspace.selectedLayer)
        let locked = PhotoRefusal("The layer is locked.")
        #expect(workspace.transformHelp == "The layer is locked.")
        let box = try #require(workspace.transformSelection)
        #expect(throws: locked) { try workspace.setTransform(TransformRules.rotated(box, by: 15), name: "Rotate", drag: nil) }
        #expect(throws: locked) {
            try workspace.setTransform(TransformRules.flipped(box, .horizontal), name: "Flip Horizontal", drag: nil)
        }
        #expect(throws: locked) { try workspace.beginTransform() }
        #expect(workspace.transformDraft == nil)
        #expect(workspace.historySteps == steps)
        #expect(workspace.selectedLayer == logo)
        #expect(PhotoWorkspace.catalog.availability("transform.rotate", on: workspace) == .unavailable("The layer is locked."))
    }

    @Test func aFlipWaitsForFreeTransformToFinish() throws {
        var workspace = try logoOnPhoto()
        try workspace.beginTransform()
        let steps = workspace.historySteps, box = try #require(workspace.transformSelection)
        let help = try #require(workspace.flipHelp)
        #expect(throws: PhotoRefusal(help)) {
            try workspace.setTransform(TransformRules.flipped(box, .vertical), name: "Flip Vertical", drag: nil)
        }
        #expect(workspace.historySteps == steps)
        workspace.cancelTransform()
        #expect(workspace.flipHelp == nil)
    }

    @Test func theCatalogRunsFreeTransform() throws {
        var workspace = try logoOnPhoto()
        let steps = workspace.historySteps.count
        #expect(PhotoWorkspace.catalog.availability("transform.commit", on: workspace) != .available)
        _ = try PhotoWorkspace.catalog.run("transform.begin", params: .object([:]), on: &workspace)
        #expect(workspace.transformDraft != nil)
        _ = try PhotoWorkspace.catalog.run("transform.rotate", params: .object(["degrees": .number(15)]), on: &workspace)
        _ = try PhotoWorkspace.catalog.run("transform.commit", params: .object([:]), on: &workspace)
        #expect(workspace.transformDraft == nil)
        #expect(workspace.historySteps.suffix(2) == ["Rotate", "Free Transform"])
        _ = try PhotoWorkspace.catalog.run("transform.begin", params: .object([:]), on: &workspace)
        _ = try PhotoWorkspace.catalog.run("transform.cancel", params: .object([:]), on: &workspace)
        #expect(workspace.transformDraft == nil)
        #expect(workspace.historySteps.count == steps + 2)
    }

    /// RJ-P17: the job's own script on its .ora (a 400 x 200 logo over a
    /// photo): the logo lands on the turned 200 x 100 box's bounds, the flip
    /// keeps its left edge, and the export matches the expected PNG.
    @Test func freeTransformRealJob() throws {
        struct Script: Decodable { var steps: [CommandEnvelope]; var atomic: Bool }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RealJobs/photo/free-transform")
        let file = { (path: String) in try Data(contentsOf: folder.appendingPathComponent(path)) }
        let script = try JSONDecoder().decode(Script.self, from: file("free-transform.jobs.json"))
        var doc = try PhotoHeadless.open(file("input/logo-on-photo.ora"), name: "logo-on-photo.ora")
        let before = try #require(doc.workspace.selectedLayer)
        #expect(before.offsetX == 60 && before.offsetY == 40)
        let report = PhotoHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
        #expect(report.stoppedAt == nil, "\(report.steps.compactMap(\.error))")
        let logo = try #require(doc.workspace.selectedLayer), size = try #require(doc.workspace.pixels[logo.id])
        let turned = TransformBox(box: Rect(minX: 60, minY: 40, maxX: 260, maxY: 140), degrees: 15)
        let bounds = TransformRules.bounds(of: turned)
        let placed = Rect(minX: Double(logo.offsetX), minY: Double(logo.offsetY),
                          maxX: Double(logo.offsetX + size.width), maxY: Double(logo.offsetY + size.height))
        #expect(logo.id == before.id)
        #expect(near(placed, bounds), "the logo is the turned box's bounds and the flip keeps its left edge")
        let exported = try #require(doc.export("png", options: .object([:])).first)
        let got = try PhotoHeadless.codec.decode(exported.data, longestSide: nil)
        let want = try PhotoHeadless.codec.decode(file("expected/logo-on-photo.png"), longestSide: nil)
        #expect(got.width == want.width && got.height == want.height)
        #expect(got.rgba8.count == want.rgba8.count
            && zip(got.rgba8, want.rgba8).allSatisfy { abs(Int($0) - Int($1)) <= 2 }, "the export matches within 2")
    }

    /// MJ-PT: select the logo, Free Transform, scale from a corner, turn 15°,
    /// commit, flip; one step each and the logo stays where it was.
    @Test func freeTransformWalk() throws {
        var workspace = try logoOnPhoto()
        let steps = workspace.historySteps.count
        try workspace.beginTransform()
        let box = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.scaled(box, sx: 0.5, sy: 0.5, about: .topLeft), name: "Scale", drag: nil)
        let scaled = try #require(workspace.transformSelection)
        try workspace.setTransform(TransformRules.rotated(scaled, by: 15), name: "Rotate", drag: nil)
        let turned = try #require(workspace.transformSelection)
        try workspace.commitTransform()
        #expect(workspace.historySteps.last == "Free Transform")
        let bounds = TransformRules.bounds(of: turned)
        let committed = try #require(workspace.transformSelection)
        #expect(near(committed.box, bounds), "the committed layer is the turned box's bounds")
        try workspace.setTransform(TransformRules.flipped(committed, .horizontal), name: "Flip Horizontal", drag: nil)
        #expect(workspace.historySteps.last == "Flip Horizontal")
        #expect(near(try #require(workspace.transformSelection).box, bounds), "the flip keeps its left edge")
        #expect(workspace.historySteps.count == steps + 4)
    }
}
