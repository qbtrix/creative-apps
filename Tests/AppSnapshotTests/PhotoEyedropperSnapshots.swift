// PhotoEyedropperSnapshots.swift (eyedropper PE-4): the Eyedropper's screens
// in Light and Dark. The loupe states draw Photo's canvas as PhotoCanvas does
// (the workspace's tiles in CanvasViewport, PhotoCanvasOverlay over them) with
// the pointer at a fixed document point, since the window keeps the pointer as
// its own state: photo-eyedropper-loupe-{light,dark}.png (SuiteUI's
// SampleLoupe over the sky with the colour under it; hollow until the live
// sampler, PE-6) and photo-eyedropper-loupe-edge-{light,dark}.png (past the
// image's right edge, hollow, "No colour here"). The sample state is the Tool
// Options section with 5 x 5 chosen: photo-eyedropper-sample-{light,dark}.png.
// macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoEyedropperSnapshots {
    /// A 640 x 480 sunset on the fakes with the Eyedropper chosen: a sky gradient and a sun.
    private func sunset() throws -> PhotoWorkspace {
        let (w, h) = (640, 480)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let (dx, dy) = (Double(x - 420), Double(y - 200))
                let sun = dx * dx + dy * dy < 90 * 90
                bytes[i] = sun ? 250 : UInt8(40 + x * 180 / w)
                bytes[i + 1] = sun ? 190 : UInt8(80 + y * 120 / h)
                bytes[i + 2] = sun ? 60 : 200
            }
        }
        var model = PhotoWorkspace(services: .fake)
        try model.open(rgba8: bytes, width: w, height: h, name: "sunset.jpg")
        model.selectTool(.eyedropper)
        return model
    }

    @Test func loupe() throws {
        let model = try sunset()
        let tiles = try photoTiles(model)
        let states = [("loupe", CGPoint(x: 120, y: 90)), ("loupe-edge", CGPoint(x: 660, y: 240))]
        for (state, hover) in states {
            #expect(PhotoSampleLoupe(model: model, zoom: 1, hover: hover).center == hover, "no loupe at \(state)")
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(
                    PhotoEyedropperCanvas(model: model, tiles: tiles, hover: hover),
                    name: "photo-eyedropper-\(state)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
            }
        }
    }

    @Test func sampleOptions() throws {
        var model = try sunset()
        model.setSampleSize(.fiveByFive)
        #expect(model.sampleSize == .fiveByFive)
        for scheme in [ColorScheme.light, .dark] {
            let view = ToolOptionsSection(model: model, perform: { _ in })
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "photo-eyedropper-sample-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

/// PhotoCanvas's picture and overlay at zoom 1 with the pointer held at `hover`.
private struct PhotoEyedropperCanvas: View {
    let model: PhotoWorkspace
    let tiles: CanvasTiles?
    let hover: CGPoint

    var body: some View {
        if let canvas = model.canvas {
            CanvasViewport(
                documentSize: CGSize(width: canvas.width, height: canvas.height), zoom: 1, pointer: model.tool.pointer
            ) {
                if let tiles { EmbeddedCanvasHost { tiles.attach($0) } }
            } overlay: {
                PhotoCanvasOverlay(model: model, zoom: 1, hover: hover)
            }
        }
    }
}
