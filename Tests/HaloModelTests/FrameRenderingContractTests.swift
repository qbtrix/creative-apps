// FrameRenderingContractTests.swift: what every FrameRendering promises
// (#451, #430), run over each conforming type in `frameRenderings`; the live
// type joins by adding itself there. Also checks FakeTextRasterizer, the text
// these suites draw with. Runs on Linux and macOS.
import CoreRaster
import HaloModel
import Testing

let frameRenderings: [any FrameRendering] = [FakeFrameRendering()]

/// `keyedPair()`'s frame 0 as drawn by the fake: the red solid at (0, 0).
func keyedPairList() -> HaloDrawList { FakeFrameDrawing().drawList(keyedPair(), at: 0) }

@Test(arguments: frameRenderings)
func renderFillsTheLayerAtTheAskedSize(rendering: any FrameRendering) throws {
    let full = try rendering.render(keyedPairList(), width: 400, height: 200, text: nil)
    #expect((full.pixels.width, full.pixels.height, full.frame) == (400, 200, 0))
    #expect(try full.pixels.pixel(x: 50, y: 50).r > 0.5)
    #expect(try full.pixels.pixel(x: 150, y: 50).a == 0)
    let quarter = try rendering.render(keyedPairList(), width: 100, height: 50, text: nil)
    #expect((quarter.pixels.width, quarter.pixels.height) == (100, 50))
    #expect(try quarter.pixels.pixel(x: 12, y: 12).r > 0.5)
    #expect(try quarter.pixels.pixel(x: 40, y: 12).a == 0)
}

@Test(arguments: frameRenderings)
func renderCountsSkippedTextButNeverNulls(rendering: any FrameRendering) throws {
    let base = keyedPairList()
    guard let solid = base.items.first else { Issue.record("no solid drawn"); return }
    func item(_ kind: HaloLayerKind) -> HaloDrawItem {
        HaloDrawItem(
            layerID: "\(kind)", kind: kind, bounds: solid.bounds, matrix: .identity, opacity: 1,
            color: solid.color, blendMode: solid.blendMode, text: kind == .text ? HaloTextContent(string: "Hi") : nil)
    }
    let list = HaloDrawList(width: 400, height: 200, frame: 0, items: [item(.null), solid, item(.text)])
    #expect(try rendering.render(list, width: 400, height: 200, text: nil).skippedLayerCount == 1)
    #expect(try rendering.render(list, width: 400, height: 200, text: FakeTextRasterizer()).skippedLayerCount == 0)
    let nullOnly = HaloDrawList(width: 400, height: 200, frame: 0, items: [item(.null)])
    #expect(try rendering.render(nullOnly, width: 400, height: 200, text: nil).skippedLayerCount == 0)
}

@Test func fakeTextRasterizerMeasuresTheEstimateAndFillsIt() throws {
    let text = HaloTextContent(string: "Hello", fontSize: 72, width: 1, height: 1)
    let box = FakeTextRasterizer().measure(text)
    #expect(abs(box.width - 216) < 1e-9 && box.height == 72 && box.x == 0 && box.y == 0)
    let pixels = try FakeTextRasterizer().rasterize(text, color: HaloLayerColor(red: 0, green: 1, blue: 0))
    #expect((pixels.width, pixels.height) == (216, 72))
    #expect(try pixels.pixel(x: 0, y: 0) == RGBA(r: 0, g: 1, b: 0, a: 1))
}
