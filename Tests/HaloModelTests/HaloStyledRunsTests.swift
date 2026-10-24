// HaloStyledRunsTests.swift: what the viewer hands the GPU layer view
// (layer-styles HY-7). A draw list splits into runs the Canvas draws and
// styled solids and shapes the GPU view draws, in order; a styled layer's
// content key ignores its style, so a scrub keeps its raster; its pixels are
// what the frame renderer draws for it unstyled. Linux and macOS.
import CoreRaster
@testable import HaloModel
import SuiteImaging
import Testing

@Suite struct HaloStyledRunsTests {
    static func item(_ id: String, _ kind: HaloLayerKind = .solid, style: LayerStyle? = nil, x: Double = 2) -> HaloDrawItem {
        HaloDrawItem(layerID: id, kind: kind, bounds: HaloLayerRect(x: x, y: 2, width: 4, height: 3), matrix: .identity,
                     opacity: 1, color: HaloLayerColor(red: 1, green: 0, blue: 0), blendMode: .normal, style: style)
    }

    static let glow = HaloStyleRenderTests.glow(10)

    @Test func runsKeepOrderAndSplitAtStyledLayers() {
        let list = HaloDrawList(width: 10, height: 8, frame: 0, items: [
            Self.item("a"), Self.item("b", .shape, style: Self.glow), Self.item("c", style: LayerStyle.none),
            Self.item("d", .text, style: Self.glow),
        ])
        #expect(list.styledRuns == [
            .drawn([list.items[0]]), .styled(list.items[1]), .drawn([list.items[2], list.items[3]]),
        ])
    }

    @Test func contentIgnoresStyleButNotPlacement() {
        let list = HaloDrawList(width: 10, height: 8, frame: 0, items: [])
        let a = list.styleContent(Self.item("a", style: Self.glow))
        #expect(a == list.styleContent(Self.item("a", style: HaloStyleRenderTests.glow(20))))
        #expect(a != list.styleContent(Self.item("a", style: Self.glow, x: 3)))
    }

    @Test func pixelsAreTheUnstyledLayer() throws {
        let item = Self.item("a", style: Self.glow)
        let list = HaloDrawList(width: 10, height: 8, frame: 0, items: [item])
        let unstyled = HaloDrawList(width: 10, height: 8, frame: 0, items: [Self.item("a")])
        let frame = try LiveFrameRendering().render(unstyled, width: 10, height: 8, text: nil)
        #expect(list.stylePixels(item) == frame.pixels)
    }
}
