// HaloTextFidelityTests.swift: HF-10's macOS half (text-layers TX-5, #430).
// On `empty` plus a black solid, a white text layer is made through the
// Model (Layer > New > Text, `setText("Hello")`, `setFontSize(96)`) on
// `.live` services with HaloApp's Core Text rasterizer, so its stored box is
// the rasterizer's `measure`. Then:
// - the rendered frame's ink lies inside that box, placed by the layer's
//   matrix, within 1 px (QB-V4);
// - HaloViewerCanvas through ImageRenderer equals `services.rendering.render`
//   of the same draw list at 1920 x 1080 as HF-1 compares solids (GoldenImage
//   at the standard tolerance: no channel over 2/255 on more than 0.5% of
//   pixels), upright and with Rotation keyed to 30.
// Both sides follow viewer-playback's pinned baseline rule (VP-9), so a
// correct rasterizer passes; a canvas-vs-render failure is a bug on
// HaloViewerCanvas.swift, not on this feature.
//
// As in HF-1: the canvas is rendered at the artboard plus SuiteSize.canvasInset
// on each side and cropped; the black solid covers the artboard fill; the
// selection is cleared before drawing, so no SelectionOutline shows. Only
// the ImageRenderer step runs on the main actor (#1155). macOS only.
import CoreRaster
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

// The limit bounds a real hang; an HF-1 case takes ~50 s on CI.
@Suite(.timeLimit(.minutes(10))) struct HaloTextFidelityTests {
    private static let width = 1920, height = 1080
    private static let black = HaloLayerColor(red: 0, green: 0, blue: 0)
    private static let white = HaloLayerColor(red: 1, green: 1, blue: 1)

    @Test func storedBoxIsTheRasterizersMeasure() throws {
        let project = try textProject(rotation: nil)
        let text = try #require(project.selectedComposition?.layers.first?.text)
        let box = HaloTextRasterizer().measure(HaloTextContent(string: "Hello", fontSize: 96))
        #expect(text.string == "Hello")
        #expect(text.fontSize == 96)
        #expect(text.width == box.width)
        #expect(text.height == box.height)
    }

    @Test func renderedInkLiesInsideTheStoredBox() throws {
        let project = try textProject(rotation: nil)
        let list = try #require(project.viewerDrawList)
        let item = try #require(list.items.last)
        #expect(item.kind == .text)
        let stored = try #require(project.selectedComposition?.layers.first?.text)
        #expect(item.bounds.width == stored.width && item.bounds.height == stored.height)
        let render = try Self.render(project, list: list)
        let box = Self.composited(item)
        let ink = try #require(Self.ink(render), "the render drew no text")
        #expect(Double(ink.minX) >= box.minX - 1, "ink starts at x \(ink.minX), box at \(box.minX)")
        #expect(Double(ink.maxX + 1) <= box.maxX + 1, "ink ends at x \(ink.maxX + 1), box at \(box.maxX)")
        #expect(Double(ink.minY) >= box.minY - 1, "ink starts at y \(ink.minY), box at \(box.minY)")
        #expect(Double(ink.maxY + 1) <= box.maxY + 1, "ink ends at y \(ink.maxY + 1), box at \(box.maxY)")
        // "Hello" spans most of its advance box: the text wasn't clipped away.
        #expect(Double(ink.maxX - ink.minX + 1) > (box.maxX - box.minX) / 2)
    }

    @Test func uprightCanvasEqualsRender() async throws {
        try await expectCanvasEqualsRender(try textProject(rotation: nil), name: "text-upright")
    }

    @Test func rotatedCanvasEqualsRender() async throws {
        let project = try textProject(rotation: 30)
        let item = try #require(project.viewerDrawList?.items.last)
        #expect(abs(abs(atan2(item.matrix.b, item.matrix.a) * 180 / Double.pi) - 30) < 1e-6)
        try await expectCanvasEqualsRender(project, name: "text-rotated-30")
    }

    // MARK: The project

    /// `empty` on `.live` services with HaloTextRasterizer: a black solid,
    /// then a white text layer "Hello" at 96 on top, its Rotation keyed to
    /// `rotation` at frame 0 when given. Nothing selected.
    private func textProject(rotation: Double?) throws -> HaloProject {
        let doc = try #require(HaloFixtures.project("empty"))
        var services = HaloServices.live
        services.text = HaloTextRasterizer()
        var project = HaloProject(services: services, document: doc)
        project.newLayer(.solid)
        project.setLayerColor(Self.black)
        project.newLayer(.text)
        project.setLayerColor(Self.white)
        project.setText("Hello")
        project.setFontSize(96)
        if let rotation {
            project.toggleAnimation(.rotation)
            project.setProperty(.rotation, to: rotation)
            #expect(project.propertyRows.first { $0.property == .rotation }?.keyState == .keyedHere)
        }
        #expect(project.refusal == nil)
        let comp = try #require(project.selectedComposition)
        #expect(comp.width == Self.width && comp.height == Self.height)
        #expect(comp.playheadFrame == 0)
        var cleared = project.document
        cleared.selectedLayerID = nil
        let drawn = HaloProject(services: project.services, document: cleared)
        #expect(drawn.selectedLayerID == nil)
        return drawn
    }

    // MARK: Drawing and comparing

    private func expectCanvasEqualsRender(_ project: HaloProject, name: String) async throws {
        let list = try #require(project.viewerDrawList)
        #expect(list.items.count == 2)
        let canvas = try await Self.canvasImage(project)
        let render = try Self.render(project, list: list)
        #expect(Self.ink(render) != nil, "\(name): the render drew no text")
        let result = GoldenImage().compare(canvas, to: render, tolerance: .standard)
        #expect(
            result.passes,
            "\(name): \(result.differing) pixels differ (share \(result.share)); \(Self.firstDifference(canvas, render))")
    }

    /// `services.rendering.render` of `list` with the project's rasterizer,
    /// as 1920 x 1080 8-bit sRGB; no text layer skipped.
    private static func render(_ project: HaloProject, list: HaloDrawList) throws -> RGBAImage {
        let frame = try project.services.rendering.render(list, width: width, height: height, text: project.services.text)
        #expect(frame.skippedLayerCount == 0)
        return RGBAImage(width: width, height: height, bytes: try frame.pixels.rgba8(colorSpace: .sRGB))
    }

    /// HaloViewerCanvas through ImageRenderer, cropped to the 1920 x 1080
    /// artboard, as 8-bit sRGB: the one step that needs the main actor.
    @MainActor
    private static func canvasImage(_ project: HaloProject) throws -> RGBAImage {
        let inset = SuiteSize.canvasInset
        let view = HaloViewerCanvas(model: project, perform: { _ in })
            .frame(width: CGFloat(width) + 2 * inset, height: CGFloat(height) + 2 * inset)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        // Extended linear keeps the canvas in linear light and float, as HF-1 does (#1161).
        renderer.colorMode = .extendedLinear
        let full = try #require(renderer.cgImage, "ImageRenderer drew nothing")
        let artboard = try #require(full.cropping(
            to: CGRect(x: inset, y: inset, width: CGFloat(width), height: CGFloat(height))))
        let canvas = try #require(RGBAImage(cgImage: artboard))
        #expect(canvas.width == width && canvas.height == height)
        return canvas
    }

    /// Where the two first differ by over 2/255 and both RGBA values there.
    private static func firstDifference(_ canvas: RGBAImage, _ render: RGBAImage) -> String {
        guard canvas.width == render.width, canvas.height == render.height,
            canvas.bytes.count == render.bytes.count
        else { return "sizes differ" }
        for i in stride(from: 0, to: canvas.bytes.count - 3, by: 4)
        where (0..<4).contains(where: { abs(Int(canvas.bytes[i + $0]) - Int(render.bytes[i + $0])) > 2 }) {
            let x = (i / 4) % canvas.width, y = (i / 4) / canvas.width
            return "first at (\(x), \(y)): canvas \(Array(canvas.bytes[i..<i + 4])) render \(Array(render.bytes[i..<i + 4]))"
        }
        return "no pixel over 2/255"
    }

    struct Bounds: Equatable {
        var minX: Int, minY: Int, maxX: Int, maxY: Int
    }

    /// The item's line box in composition pixels: its four corners through
    /// its matrix (the affine map the canvas concatenates), as min and max edges.
    private static func composited(_ item: HaloDrawItem) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        let b = item.bounds, m = item.matrix
        let corners = [(b.x, b.y), (b.x + b.width, b.y), (b.x, b.y + b.height), (b.x + b.width, b.y + b.height)]
        let xs = corners.map { m.a * $0.0 + m.c * $0.1 + m.tx }
        let ys = corners.map { m.b * $0.0 + m.d * $0.1 + m.ty }
        return (xs.min() ?? 0, ys.min() ?? 0, xs.max() ?? 0, ys.max() ?? 0)
    }

    /// The box around every pixel visibly off the black solid (a channel
    /// over 2/255, above the compare's noise); nil when there is none.
    private static func ink(_ image: RGBAImage) -> Bounds? {
        var found: Bounds?
        for y in 0..<image.height {
            for x in 0..<image.width {
                let i = (y * image.width + x) * 4
                guard i + 2 < image.bytes.count, (0..<3).contains(where: { image.bytes[i + $0] > 2 }) else { continue }
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
