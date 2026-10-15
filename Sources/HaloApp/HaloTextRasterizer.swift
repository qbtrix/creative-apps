// HaloTextRasterizer.swift: the W0 stub of Halo's text rasterizer, which
// HaloLaunch sets as `services.text` so the Model reaches it from the app.
// It measures with HaloTextContent's estimate (0.6 em a character, one em
// tall), so a new text layer gets a box, and drawing throws `.notBuilt`.
// text-layers (#430) replaces this file whole with the CoreText one.
import CoreRaster
import HaloModel

struct HaloTextRasterizer: TextRasterizing {
    func measure(_ text: HaloTextContent) -> HaloLayerRect {
        let estimate = HaloTextContent(string: text.string, fontSize: text.fontSize)
        return HaloLayerRect(x: 0, y: 0, width: estimate.width, height: estimate.height)
    }

    func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        throw HaloEditError.notBuilt("Text drawing")
    }
}
