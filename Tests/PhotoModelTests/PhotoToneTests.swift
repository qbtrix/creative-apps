// PhotoToneTests.swift (tone-controls PT-1; PT-3 and PT-4 turn on the rest):
// the image's and an adjustment layer's `tone` section and the workspace as a
// ToneTarget. On now: the section starts neutral, `.tone` sets it, a neutral
// section is left out of the stored form, and the adapter reads the selected
// adjustment layer's tone, else the image's. MJ-PT's walk (one undo step per
// command, a layer's tone stays on the layer) waits on the bodies. PT-3
// (PhotoToneRenderTests): tone's steps run before every section, export runs
// the unsharp pass first, a tone step on the live route is one write per
// region, and Blur still sends a region to the dispatcher route; the cases
// that need ToneRules' bodies wait on TC-5 (#4880). Mutations (PT-3):
// PhotoModel.PhotoAdjust+Imaging (`.toneFirst`, `.sharpenOnCanvas`),
// PhotoModel.PhotoRender (`.exportMatchesCanvas`); (PT-4):
// PhotoModel.PhotoTone+Kernel (`.layerTone`). Runs on Linux and macOS.
import CoreRaster
import CoreRender
import Foundation
import SuiteImaging
import Testing

@testable import PhotoModel

/// An open 8 x 8 white image on `.fake`.
private func image() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace(services: .fake)
    try workspace.newCanvas(width: 8, height: 8)
    return workspace
}

private let warm = ToneSettings.neutral.setting(.temperature, to: 30)

@Suite struct PhotoToneTests {
    @Test func sectionStartsNeutralAndToneEditSetsIt() {
        var settings = AdjustmentSettings()
        #expect(settings.tone == .neutral && settings.isIdentity)
        settings.apply(.tone(warm))
        #expect(settings.tone == warm && !settings.isIdentity)
        settings.apply(.tone(.neutral))
        #expect(settings.isIdentity)
    }

    @Test func storedFormOmitsANeutralToneAndKeepsAnother() throws {
        let plain = try JSONEncoder().encode(AdjustmentSettings())
        #expect(!String(decoding: plain, as: UTF8.self).contains("\"tone\""))
        #expect(try JSONDecoder().decode(AdjustmentSettings.self, from: plain).tone == .neutral)
        var settings = AdjustmentSettings()
        settings.apply(.tone(warm))
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AdjustmentSettings.self, from: data) == settings)
    }

    @Test func noImageHasNoToneAndSaysWhy() {
        let workspace = PhotoWorkspace(services: .fake)
        #expect(workspace.toneSettings == nil)
        #expect(workspace.toneHelp == "Open an image first.")
    }

    @Test func readsTheImageElseTheSelectedAdjustmentLayer() throws {
        var workspace = try image()
        #expect(workspace.toneSettings == .neutral)
        workspace.adjust(.tone(warm))
        #expect(workspace.toneSettings == warm)
        workspace.addAdjustmentLayer(.levels)
        #expect(workspace.toneSettings == .neutral)
        workspace.selectLayer(try #require(workspace.layers.last).id)
        #expect(workspace.toneSettings == warm)
    }

    @Test func aToneEditOnTheImageIsOneNamedStep() throws {
        var workspace = try image()
        workspace.adjust(.tone(warm))
        workspace.adjust(.tone(warm.setting(.temperature, to: 40)))
        #expect(workspace.historySteps.count == 2 && workspace.undoActionName == "Undo Tone")
        workspace.undo()
        #expect(workspace.adjustments.tone == .neutral)
    }
}

struct PhotoToneTargetTests {
    /// MJ-PT step 2: one `setTone` under a drag token is one step named for it.
    @Test func dragIsOneStep() throws {
        var workspace = try image()
        for value in stride(from: -1.0, through: -25, by: -1) {
            try workspace.setTone(.neutral.setting(.temperature, to: value), name: "Temperature", drag: "d1")
        }
        #expect(workspace.historySteps.count == 2 && workspace.undoActionName == "Undo Temperature")
        workspace.undo()
        #expect(workspace.toneSettings == .neutral)
    }

    /// MJ-PT step 4: a layer's tone goes to the layer; the image's stays.
    @Test func layerTone() throws {
        var workspace = try image()
        workspace.addAdjustmentLayer(.levels)
        try workspace.setTone(.neutral.setting(.contrast, to: 20), name: "Contrast", drag: nil)
        #expect(workspace.adjustments.tone == .neutral)
        #expect(workspace.toneSettings?.value(.contrast) == 20)
        #expect(workspace.historySteps.count == 3)
    }

    /// MJ-PT step 3: Auto reads the image without recording a step.
    @Test func autoSuggestionReadsTheImage() throws {
        let workspace = try image()
        let auto = try workspace.autoToneSuggestion()
        #expect(auto.inWhite > auto.inBlack && workspace.historySteps.count == 1)
    }
}

/// A canvas-sized picture the live route writes regions into, its tone program applied on the way as the
/// display write applies it; counts the writes.
private final class LiveSink: @unchecked Sendable {
    let backend: CPUBackend
    let width: Int
    private let lock = NSLock()
    private(set) var bytes: [UInt8]
    private(set) var toned = 0, plain = 0

    /// `backend` is the route's own: the surfaces it writes are that backend's.
    init(_ canvas: CanvasSize, on backend: CPUBackend) {
        self.backend = backend
        width = canvas.width
        bytes = [UInt8](repeating: 0, count: canvas.width * canvas.height * 4)
    }

    var target: PhotoDisplayTarget {
        PhotoDisplayTarget(
            write: { [self] surface, rect in try put(surface, rect, toned: false) },
            writeToned: { [self] surface, rect, tone in
                let adjusted = try backend.adjusted(surface, tone: tone)
                defer { backend.release(adjusted) }
                try put(adjusted, rect, toned: true)
            })
    }

    private func put(_ surface: RenderSurface, _ rect: PixelRect, toned: Bool) throws {
        let shown = PhotoRenderer.premultiplied(try backend.display(surface, colorSpace: .sRGB))
        lock.lock()
        defer { lock.unlock() }
        if toned { self.toned += 1 } else { plain += 1 }
        for row in 0..<rect.height {
            let at = ((rect.y + row) * width + rect.x) * 4
            bytes.replaceSubrange(at..<(at + rect.width * 4), with: shown[(row * rect.width * 4)...].prefix(rect.width * 4))
        }
    }
}

@Suite struct PhotoToneRenderTests {
    /// A 600 x 400 picture (six tiles) of one colour with a darker block in it, so it has edges.
    static func picture(red: UInt8 = 200, green: UInt8 = 180, blue: UInt8 = 150) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 600, height: 400)
        fill(&workspace, (red, green, blue), Mask.Point(x: 0, y: 0), Mask.Point(x: 600, y: 400))
        fill(&workspace, (red / 2, green / 2, blue / 2), Mask.Point(x: 150, y: 100), Mask.Point(x: 420, y: 300))
        return workspace
    }

    static func fill(_ workspace: inout PhotoWorkspace, _ rgb: (UInt8, UInt8, UInt8), _ a: Mask.Point, _ b: Mask.Point) {
        workspace.setToolOption(.color(red: rgb.0, green: rgb.1, blue: rgb.2))
        workspace.selectTool(.marquee)
        workspace.drag(from: a, to: a)
        workspace.drag(from: a, to: b)
        workspace.endDrag()
        workspace.fillSelection()
        workspace.deselect()
    }

    /// The resident route and a sink on its backend.
    fileprivate static func route(_ canvas: CanvasSize) -> (PhotoRenderRoute, ResidentSurfaces, LiveSink) {
        let gpu = CPUBackend(name: "stand-in")
        let resident = ResidentSurfaces(backend: gpu)
        return (PhotoRenderRoute(preferred: gpu, resident: resident), resident, LiveSink(canvas, on: gpu))
    }

    /// Settings with every section but Blur off its identity.
    static func sections() -> AdjustmentSettings {
        var settings = AdjustmentSettings()
        for edit: AdjustmentEdit in [.exposure(0.3), .gamma(1.4), .hue(20), .saturation(-15),
                                     .curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.65), CurvePoint(x: 1, y: 1)])] {
            settings.apply(edit)
        }
        return settings
    }

    /// `.toneFirst`: tone's steps run before exposure, levels, curves and hue/saturation, on every path
    /// that reads `imagingSteps` (export, the dispatcher route, adjustment layers, Curves' input).
    @Test func toneRunsBeforeEverySection() {
        let settings = Self.sections(), tone: [ToneAdjustment] = [.exposure(stops: -0.5)]
        let sections = settings.imagingSteps(tone: [])
        #expect(sections.count == 4)
        #expect(settings.imagingSteps(tone: tone) == tone + sections)
        #expect(settings.imagingSteps([.exposure, .levels], tone: tone).first == tone.first)
        #expect(settings.imagingSteps == settings.toneSteps + sections)
    }

    /// `.exportMatchesCanvas`: export sharpens the base first, then runs tone and the sections, the order
    /// the canvas draws in (the unsharp pass over the base before the display write).
    @Test func exportSharpensFirst() throws {
        var edge = try PixelBuffer(width: 16, height: 16, fill: RGBA(r: 0.2, g: 0.2, b: 0.2, a: 1))
        for y in 0..<16 { for x in 8..<16 { try edge.setPixel(x: x, y: y, RGBA(r: 0.8, g: 0.7, b: 0.6, a: 1)) } }
        let settings = Self.sections(), unsharp = (amount: 0.8, sigma: 1.0, threshold: 0.0)
        let sharpened = try edge.unsharpMask(amount: unsharp.amount, sigma: unsharp.sigma, threshold: unsharp.threshold)
        let canvasOrder = try settings.runImaging(settings.imagingSteps, on: sharpened)
        let afterTone = try settings.runImaging(settings.imagingSteps, on: edge)
            .unsharpMask(amount: unsharp.amount, sigma: unsharp.sigma, threshold: unsharp.threshold)
        #expect(canvasOrder != afterTone, "the fixture tells the two orders apart")
        #expect(try settings.applied(to: edge, sharpening: unsharp) == canvasOrder)
        #expect(try settings.applied(to: edge, sharpening: nil) == settings.runImaging(settings.imagingSteps, on: edge))
    }

    /// MJ-PT step 2: a tone step on the live route is one write per region over the kept composite: no
    /// upload, no composite, nothing through the plain write.
    @Test func stepIsOneWrite() async throws {
        var workspace = try Self.picture()
        let canvas = try #require(workspace.canvas)
        let (route, resident, sink) = Self.route(canvas)
        let first = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        let (uploads, made, regions) = (resident.uploads, route.composites.made, sink.toned)
        #expect(regions > 0 && sink.plain == 0)
        workspace.adjust(.tone(warm))
        #expect(workspace.liveStack() != nil)
        _ = try await PhotoRenderer.update(workspace, since: first.revision, route: route, target: sink.target)
        #expect(resident.uploads == uploads, "a tone step uploaded layer tiles")
        #expect(route.composites.made == made, "a tone step composited the layers again")
        #expect(sink.toned == 2 * regions && sink.plain == 0, "a tone step is one display write per region")
    }

    /// Blur reads neighbours: with a tone section set, a region still takes the dispatcher route.
    @Test func blurStillFallsBack() async throws {
        var workspace = try Self.picture()
        // Sharpen reads further than Blur here, and an edge sits 3 px above the seam at y 256 between
        // the two rows of tiles (each row is one region), so a region that reads only Blur's margin
        // shows the seam.
        Self.fill(&workspace, (40, 40, 40), Mask.Point(x: 0, y: 230), Mask.Point(x: 600, y: 253))
        workspace.adjust(.tone(warm.setting(.sharpenAmount, to: 80).setting(.sharpenRadius, to: 3)))
        workspace.adjust(.blurSigma(0.3))
        #expect(workspace.liveStack() == nil)
        let canvas = try #require(workspace.canvas)
        let (route, _, sink) = Self.route(canvas)
        _ = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(sink.toned == 0 && sink.plain > 0)
        let export = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        #expect((zip(sink.bytes, export).map { abs(Int($0) - Int($1)) }.max() ?? 0) <= 2, "the dispatcher route sharpens as export does")
    }

    /// RJ-P12: Temperature -30 on a grey card under a mild tungsten cast reads neutral, |R - B| <= 3/255. The
    /// cast is the one -30 removes: white balance moves red and blue 0.15 stop each way in linear light, so
    /// the card is about 0.3 stop warm (sRGB 124/118/112, linear R/B 1.23).
    @Test func temperatureCoolsTungstenToNeutral() async throws {
        var workspace = try Self.picture(red: 124, green: 118, blue: 112)
        workspace.adjust(.tone(.neutral.setting(.temperature, to: -30)))
        let pixel = (100 * 600 + 50) * 4, bytes = try await PhotoRenderer.render(workspace).rgba8
        #expect(abs(Int(bytes[pixel]) - Int(bytes[pixel + 2])) <= 3)
    }

    /// `.sharpenOnCanvas`: with Sharpen on, the live canvas is export's picture within 2 display levels.
    @Test func liveMatchesExportWithSharpenOn() async throws {
        var workspace = try Self.picture()
        workspace.adjust(.tone(warm.setting(.sharpenAmount, to: 80).setting(.sharpenRadius, to: 0.8)))
        #expect(workspace.adjustments.unsharp != nil)
        let canvas = try #require(workspace.canvas)
        let (route, _, sink) = Self.route(canvas)
        _ = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(sink.toned > 0)
        let export = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        #expect((zip(sink.bytes, export).map { abs(Int($0) - Int($1)) }.max() ?? 0) <= 2)
    }

    /// Export sharpens after every layer: an adjustment layer on top runs before the unsharp pass on the live
    /// route too, not folded into the write after it.
    @Test func liveMatchesExportWithSharpenUnderALayer() async throws {
        var workspace = try Self.picture()
        workspace.adjust(.tone(warm.setting(.sharpenAmount, to: 80).setting(.sharpenRadius, to: 0.8)))
        workspace.addAdjustmentLayer(.levels)
        try workspace.setTone(.neutral.setting(.contrast, to: 40), name: "Contrast", drag: nil)
        #expect(workspace.liveStack()?.steps.count == 1)
        let canvas = try #require(workspace.canvas)
        let (route, _, sink) = Self.route(canvas)
        _ = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        #expect(sink.toned > 0 && sink.plain == 0)
        let export = PhotoRenderer.premultiplied(try await PhotoRenderer.render(workspace).rgba8)
        #expect((zip(sink.bytes, export).map { abs(Int($0) - Int($1)) }.max() ?? 0) <= 2)
    }

    /// With Sharpen on, a tone step still draws over the kept, sharpened composite: no composite again.
    @Test func sharpenStepKeepsTheComposite() async throws {
        var workspace = try Self.picture()
        let sharp = warm.setting(.sharpenAmount, to: 80)
        workspace.adjust(.tone(sharp))
        let canvas = try #require(workspace.canvas)
        let (route, _, sink) = Self.route(canvas)
        let first = try await PhotoRenderer.update(workspace, since: nil, route: route, target: sink.target)
        let made = route.composites.made
        workspace.adjust(.tone(sharp.setting(.temperature, to: 40)))
        _ = try await PhotoRenderer.update(workspace, since: first.revision, route: route, target: sink.target)
        #expect(route.composites.made == made, "a tone step composited the layers again")
        workspace.adjust(.tone(sharp.setting(.sharpenAmount, to: 40)))
        _ = try await PhotoRenderer.update(workspace, since: first.revision, route: route, target: sink.target)
        #expect(route.composites.made > made, "a new Sharpen amount kept the old sharpening")
    }
}
