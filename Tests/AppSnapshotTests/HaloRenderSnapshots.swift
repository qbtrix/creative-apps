// HaloRenderSnapshots.swift: Render Frame in the viewer (render-out RO-5,
// #451). HaloViewer on `keyed` with the fake services at frame 12, after
// `renderCurrentFrame()`: the rendered frame (Ball over Floor) fills the
// artboard with no note. After a scrub to 13 the same frame shows with
// "Rendered frame is out of date." under the artboard, every drawn row of the
// note below the image's last row. HaloFrameImage turns
// the frame into an sRGB, straight-alpha image of the frame's size. Light and
// Dark. Writes halo-rendered-frame-*.png and halo-rendered-frame-stale-*.png.
// macOS only.
import AppKit
import CoreGraphics
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloRenderSnapshots {
    /// `keyed` on the fakes (HaloViewer's own default would be the live
    /// services), rendered at frame 12.
    private func rendered() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        project.scrub(to: 12)
        project.renderCurrentFrame()
        return project
    }

    @Test func frameImageIsStraightAlphaSRGBAtTheFrameSize() throws {
        let frame = try #require(try rendered().shownRenderedFrame)
        let image = try #require(HaloFrameImage.cgImage(frame))
        #expect(image.width == 480 && image.height == 270)
        #expect(image.bitsPerComponent == 8 && image.bitsPerPixel == 32 && image.bytesPerRow == 480 * 4)
        #expect(image.alphaInfo == .last)
        #expect(image.colorSpace?.name as String? == CGColorSpace.sRGB as String)
    }

    @Test func renderedFrame() throws {
        let project = try rendered()
        #expect(project.renderedFrameSummary == "Rendered frame 12 at 480 × 270")
        #expect(project.renderedFrameNote == nil)
        try snapshot(HaloViewer(model: project), name: "halo-rendered-frame-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-rendered-frame-dark", scheme: .dark)
    }

    @Test func staleRenderedFrame() throws {
        var project = try rendered()
        project.scrub(to: 13)
        #expect(project.renderedFrameStale)
        #expect(project.renderedFrameSummary == "Rendered frame 12 at 480 × 270")
        #expect(project.renderedFrameNote == "Rendered frame is out of date.")
        try snapshot(HaloViewer(model: project), name: "halo-rendered-frame-stale-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-rendered-frame-stale-dark", scheme: .dark)
    }

    /// The note sits under the artboard, not over its bottom edge: every pixel
    /// the note adds lies below the image's last row, in light and dark.
    @Test func staleNoteSitsUnderTheArtboard() throws {
        let frame = try #require(try rendered().shownRenderedFrame)
        let artboard = CGSize(width: 1920, height: 1080)
        for scheme in [ColorScheme.light, .dark] {
            let bare = try #require(render(
                HaloRenderedImage(frame: frame, artboard: artboard, summary: "", note: nil), scheme: scheme))
            let noted = try #require(render(
                HaloRenderedImage(frame: frame, artboard: artboard, summary: "", note: "Rendered frame is out of date."),
                scheme: scheme))
            let background = bare.colorAt(x: 0, y: 0)
            let mid = bare.pixelsWide / 2
            let imageBottom = try #require(
                (0..<bare.pixelsHigh).last { bare.colorAt(x: mid, y: $0) != background }, "no image drawn")
            let changed = (0..<bare.pixelsHigh).filter { y in
                stride(from: 0, to: bare.pixelsWide, by: 2).contains { bare.colorAt(x: $0, y: y) != noted.colorAt(x: $0, y: y) }
            }
            let top = try #require(changed.first, "the note drew nothing (\(scheme.name))")
            #expect(top > imageBottom, "the note starts at row \(top), over the image ending at \(imageBottom) (\(scheme.name))")
        }
    }
}
