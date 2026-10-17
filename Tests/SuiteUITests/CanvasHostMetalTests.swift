// CanvasHostMetalTests.swift: the canvas host's Metal path (canvas-host CH-10):
// `.gpu` with a device installs a `CAMetalLayer` with a colour space, `.cpu`,
// `.automatic` or a nil device keep the tile layers, and switching keeps the
// overlay on top. macOS only; the GPU cases need a Metal device.
import AppKit
import Metal
import QuartzCore
import Testing

@testable import SuiteUI

@MainActor
@Suite(.serialized) struct CanvasHostMetalTests {
    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func gpuWithADeviceInstallsAMetalLayerWithAColourSpace() throws {
        let canvas = loadedHost()
        canvas.useRendering(.gpu, device: MTLCreateSystemDefaultDevice(), presenter: ClearingMetalPresenter())
        let metal = try #require(canvas.metalLayer)
        #expect(metal.colorspace != nil)
        #expect(metal.device != nil)
        #expect(canvas.container.isHidden)
        #expect(overlayOnTop(canvas))
    }

    @Test func gpuWithNoDeviceKeepsTheTileLayers() {
        let canvas = loadedHost()
        canvas.useRendering(.gpu, device: nil, presenter: ClearingMetalPresenter())
        #expect(canvas.metalLayer == nil)
        #expect(!canvas.container.isHidden)
        #expect(canvas.container.sublayers?.count == 20)
        #expect(overlayOnTop(canvas))
    }

    @Test func cpuAndAutomaticKeepTheTileLayers() {
        let canvas = loadedHost()
        let device = MTLCreateSystemDefaultDevice()
        for choice in [RenderingChoice.cpu, .automatic] {
            canvas.useRendering(choice, device: device, presenter: ClearingMetalPresenter())
            #expect(canvas.metalLayer == nil, "\(choice) installed a Metal layer")
            #expect(!canvas.container.isHidden)
            #expect(canvas.container.sublayers?.count == 20)
        }
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
    func switchingBackAndForthKeepsTheOverlay() throws {
        let canvas = loadedHost()
        let preference = FakeRenderingPreference(choice: .cpu)
        let watch = canvas.follow(preference, device: MTLCreateSystemDefaultDevice(), presenter: ClearingMetalPresenter())
        defer { watch.cancel() }
        #expect(canvas.metalLayer == nil)
        for _ in 0..<2 {
            preference.set(.gpu)
            let metal = try #require(canvas.metalLayer)
            #expect(metal.colorspace != nil)
            #expect(canvas.container.isHidden)
            #expect(overlayOnTop(canvas))
            preference.set(.cpu)
            #expect(canvas.metalLayer == nil)
            #expect(!canvas.container.isHidden)
            #expect(overlayOnTop(canvas))
        }
        let metalLayers = canvas.layer?.sublayers?.filter { $0 is CAMetalLayer }.count
        #expect(metalLayers == 0)
    }
}

/// A 960 x 600 host showing the fake document's 20 tiles, laid out.
@MainActor private func loadedHost() -> CanvasHostView {
    let canvas = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 960, height: 600))
    canvas.show(FakeCanvasContent())
    canvas.layoutSubtreeIfNeeded()
    return canvas
}

/// The overlay is still the host layer's top sublayer, named as the journeys expect.
@MainActor private func overlayOnTop(_ canvas: CanvasHostView) -> Bool {
    canvas.overlay.superlayer === canvas.layer && canvas.layer?.sublayers?.last === canvas.overlay
        && canvas.overlay.name == RenderingControlID.overlay
}
