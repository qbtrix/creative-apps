// HaloViewerFidelityTests.swift: HF-1, the viewer canvas equals the render
// (#37, VP-9). A HaloProject on `.live` services, with `drawing` =
// LiveFrameDrawing(placing: FakeLayerPlacing()) and `text` = a test
// rasterizer that fills its measured box (ascent 40, descent 10), is drawn
// two ways at 1920 x 1080: HaloViewerCanvas through ImageRenderer, and
// LiveFrameRendering on the same model's `viewerDrawList`. Both become 8-bit
// sRGB (the render through CoreRaster's rgba8(colorSpace:)) and are compared
// with GoldenImage at the standard tolerance: no channel over 2/255 on more
// than 0.5% of pixels.
//
// What is left out, and why:
// - The canvas sits on CanvasSurface (surround, artboard fill, shadow) inside
//   SuiteSize.canvasInset; the view is rendered at the artboard size plus the
//   inset on each side and the artboard's 1920 x 1080 is cropped out.
// - The render has no artboard fill, so each case puts an opaque full-frame
//   "Backdrop" solid under its layers; the artboard color never shows.
// - Nothing is selected, so no SelectionOutline is drawn.
// - Text: the canvas draws real glyphs and the test rasterizer a filled box,
//   so their pixels inside the line box can't agree. Outside the box the two
//   are compared as above; inside it the canvas's ink must sit in the
//   rasterizer's box with its baseline on the pinned rule (bounds.y + ascent,
//   the rasterizer's height - descent).
//
// The suite is not main-actor bound: only the ImageRenderer step runs on the
// main actor (`canvasImage`). The CoreRaster render, the compare and the pixel
// loops run off it, so these 1920 x 1080 cases don't hold the main actor for
// minutes and starve other @MainActor suites (#1155). macOS only.
import CoreRaster
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@Suite struct HaloViewerFidelityTests {
    private static let width = 1920, height = 1080
    private static let backdropColor = HaloLayerColor(red: 0.12, green: 0.14, blue: 0.18)

    @Test func keyedFrame6() async throws {
        try await expectCanvasEqualsRender(try keyedProject(at: 6), name: "keyed-6")
    }

    @Test func keyedFrame12() async throws {
        try await expectCanvasEqualsRender(try keyedProject(at: 12), name: "keyed-12")
    }

    @Test func multiplySolidOverSolid() async throws {
        let top = HaloLayer(
            id: "comp-1-layer-2", name: "Multiply", kind: .solid, inFrame: 0, outFrame: 24,
            color: HaloLayerColor(red: 0.3, green: 0.6, blue: 0.9), blendMode: .multiply,
            rect: HaloLayerRect(x: 400, y: 300, width: 800, height: 400))
        let under = HaloLayer(
            id: "comp-1-layer-1", name: "Under", kind: .solid, inFrame: 0, outFrame: 24,
            color: HaloLayerColor(red: 0.9, green: 0.8, blue: 0.3))
        let project = try project(layers: [top, under])
        #expect(project.viewerDrawList?.items.last?.blendMode == .multiply)
        try await expectCanvasEqualsRender(project, name: "multiply")
    }

    @Test func textItemSitsOnTheBaselineRule() async throws {
        let rasterizer = BoxTextRasterizer()
        // The size whose system-font ascent is the rasterizer's 40, so both
        // put the baseline 40 pixels under the line box's top.
        let fontSize = Double(40 * 100 / HaloCanvasFit.ascent(fontSize: 100))
        var content = HaloTextContent(string: "HHHH", fontSize: fontSize)
        let box = rasterizer.measure(content)
        content.width = box.width
        content.height = box.height
        var title = HaloLayer(
            id: "comp-1-layer-2", name: "Title", kind: .text, inFrame: 0, outFrame: 24, color: HaloLayerColor(red: 1, green: 1, blue: 1))
        title.text = content
        let project = try project(layers: [title], rasterizer: rasterizer)
        let list = try #require(project.viewerDrawList)
        let item = try #require(list.items.last)
        #expect(item.kind == .text)
        let b = item.bounds
        let (canvas, render) = try await images(project, list: list, rasterizer: rasterizer)

        // The render: exactly the rasterizer's box at bounds.origin.
        let inBox = { (x: Int, y: Int) in
            Double(x) >= b.x && Double(x) < b.x + b.width && Double(y) >= b.y && Double(y) < b.y + b.height
        }
        let renderInk = Self.ink(render)
        #expect(renderInk == Self.Bounds(minX: Int(b.x), minY: Int(b.y), maxX: Int(b.x + b.width) - 1, maxY: Int(b.y + b.height) - 1))

        // The canvas: ink inside the box (1 px for antialiasing), its bottom
        // row on the baseline, bounds.y + 40, within a pixel.
        let canvasInk = try #require(Self.ink(canvas), "the canvas drew no text")
        #expect(Double(canvasInk.minX) >= b.x - 1 && Double(canvasInk.maxX) <= b.x + b.width)
        #expect(Double(canvasInk.minY) >= b.y - 1 && Double(canvasInk.maxY) <= b.y + b.height)
        let baseline = b.y + BoxTextRasterizer.ascent
        #expect(abs(Double(canvasInk.maxY + 1) - baseline) <= 1, "ink ends at \(canvasInk.maxY + 1), baseline \(baseline)")

        // Outside the box (and its antialiased rim) the two agree.
        var maskedCanvas = canvas
        for y in 0..<Self.height {
            for x in 0..<Self.width where inBox(x, y) || inBox(x + 1, y) || inBox(x - 1, y) || inBox(x, y + 1) || inBox(x, y - 1) {
                let i = (y * Self.width + x) * 4
                for c in 0..<4 { maskedCanvas.bytes[i + c] = render.bytes[i + c] }
            }
        }
        Self.expectMatch(maskedCanvas, render, name: "text")
    }

    // MARK: Cases

    /// The `keyed` fixture at `frame`, with the backdrop under Floor and Ball.
    private func keyedProject(at frame: Int) throws -> HaloProject {
        let doc = try #require(HaloFixtures.project("keyed"))
        let comp = try #require(doc.compositions.first)
        var project = try project(layers: comp.layers, from: comp)
        project.scrub(to: frame)
        #expect(project.selectedComposition?.playheadFrame == frame)
        return project
    }

    /// One 1920 x 1080 composition of `layers` (top first) over the backdrop,
    /// on the injected services, with nothing selected.
    private func project(
        layers: [HaloLayer], from source: HaloComposition? = nil, rasterizer: BoxTextRasterizer = BoxTextRasterizer()
    ) throws -> HaloProject {
        let backdrop = HaloLayer(
            id: "comp-1-layer-99", name: "Backdrop", kind: .solid, inFrame: 0, outFrame: 1_000, color: Self.backdropColor)
        let comp = HaloComposition(
            id: source?.id ?? "comp-1", name: source?.name ?? "Fidelity", width: Self.width, height: Self.height,
            framesPerSecond: source?.framesPerSecond ?? 24, durationFrames: source?.durationFrames ?? 24,
            layers: layers + [backdrop])
        var services = HaloServices.live
        services.drawing = LiveFrameDrawing(placing: FakeLayerPlacing())
        services.text = rasterizer
        let doc = HaloDocumentState(
            compositions: [comp], selectedCompositionID: comp.id, selectedLayerID: nil,
            nextCompositionNumber: 2, nextLayerNumber: 100)
        let project = HaloProject(services: services, document: doc)
        #expect(project.selectedLayerID == nil)
        return project
    }

    // MARK: Drawing and comparing

    private func expectCanvasEqualsRender(_ project: HaloProject, name: String) async throws {
        let list = try #require(project.viewerDrawList)
        #expect(!list.items.isEmpty)
        let (canvas, render) = try await images(project, list: list, rasterizer: BoxTextRasterizer())
        Self.expectMatch(canvas, render, name: name)
    }

    /// The canvas through ImageRenderer, cropped to the artboard, and the
    /// render of `list`, both 1920 x 1080 8-bit sRGB. Only the canvas step
    /// takes the main actor.
    private func images(
        _ project: HaloProject, list: HaloDrawList, rasterizer: BoxTextRasterizer
    ) async throws -> (canvas: RGBAImage, render: RGBAImage) {
        let canvas = try await Self.canvasImage(project)
        let frame = try LiveFrameRendering().render(list, width: Self.width, height: Self.height, text: rasterizer)
        #expect(frame.skippedLayerCount == 0)
        let render = RGBAImage(width: Self.width, height: Self.height, bytes: try frame.pixels.rgba8(colorSpace: .sRGB))
        return (canvas, render)
    }

    /// HaloViewerCanvas through ImageRenderer, cropped to the 1920 x 1080
    /// artboard, as 8-bit sRGB: the one step that needs the main actor.
    @MainActor
    private static func canvasImage(_ project: HaloProject) throws -> RGBAImage {
        let inset = SuiteSize.canvasInset
        let view = HaloViewerCanvas(model: project, perform: { _ in })
            .frame(width: CGFloat(Self.width) + 2 * inset, height: CGFloat(Self.height) + 2 * inset)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let full = try #require(renderer.cgImage, "ImageRenderer drew nothing")
        let artboard = try #require(full.cropping(
            to: CGRect(x: inset, y: inset, width: CGFloat(Self.width), height: CGFloat(Self.height))))
        let canvas = try #require(RGBAImage(cgImage: artboard))
        #expect(canvas.width == Self.width && canvas.height == Self.height)
        return canvas
    }

    private static func expectMatch(
        _ canvas: RGBAImage, _ render: RGBAImage, name: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let result = GoldenImage().compare(canvas, to: render, tolerance: .standard)
        #expect(result.passes, "\(name): \(result.differing) pixels differ (share \(result.share))", sourceLocation: sourceLocation)
    }

    struct Bounds: Equatable {
        var minX: Int, minY: Int, maxX: Int, maxY: Int
    }

    /// The box around every pixel far (over 64/255 in a channel) from the
    /// backdrop; nil when there is none.
    private static func ink(_ image: RGBAImage) -> Bounds? {
        let back = [backdropColor.red, backdropColor.green, backdropColor.blue].map { Int(($0 * 255).rounded()) }
        var found: Bounds?
        for y in 0..<image.height {
            for x in 0..<image.width {
                let i = (y * image.width + x) * 4
                guard (0..<3).contains(where: { abs(Int(image.bytes[i + $0]) - back[$0]) > 64 }) else { continue }
                if var f = found {
                    f.minX = min(f.minX, x); f.maxX = max(f.maxX, x); f.minY = min(f.minY, y); f.maxY = max(f.maxY, y)
                    found = f
                } else {
                    found = Bounds(minX: x, minY: y, maxX: x, maxY: y)
                }
            }
        }
        return found
    }
}

/// A test TextRasterizing: its line box is one em a character wide (an even
/// whole number of pixels, so it centers on a pixel edge) and ascent 40 +
/// descent 10 tall, and it fills all of it with the layer's color.
private struct BoxTextRasterizer: TextRasterizing {
    static let ascent = 40.0
    static let descent = 10.0

    func measure(_ text: HaloTextContent) -> HaloLayerRect {
        let wide = (text.fontSize * Double(max(text.string.count, 1)) / 2).rounded(.up) * 2
        return HaloLayerRect(x: 0, y: 0, width: max(wide, 2), height: Self.ascent + Self.descent)
    }

    func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        let box = measure(text)
        let srgb = [color.red, color.green, color.blue, 1].map { UInt8((min(max($0, 0), 1) * 255).rounded()) }
        let fill = try PixelBuffer(rgba8: srgb, width: 1, height: 1, colorSpace: .sRGB).pixel(x: 0, y: 0)
        return try PixelBuffer(width: Int(box.width), height: Int(box.height), fill: fill)
    }
}
