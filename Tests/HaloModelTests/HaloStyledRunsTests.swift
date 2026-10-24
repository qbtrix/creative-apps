// HaloStyledRunsTests.swift (layer-styles HY-7): the runs, the style-free content key and the unstyled pixels.
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
        let (a, b, c, d) = (Self.item("a"), Self.item("b", .shape, style: Self.glow), Self.item("c", style: LayerStyle.none), Self.item("d", .text, style: Self.glow))
        #expect(HaloDrawList(width: 10, height: 8, frame: 0, items: [a, b, c, d]).styledRuns == [.drawn([a]), .styled(b), .drawn([c, d])])
    }

    @Test func contentIgnoresStyleButNotPlacement() {
        let list = HaloDrawList(width: 10, height: 8, frame: 0, items: [])
        let a = list.styleContent(Self.item("a", style: Self.glow))
        #expect(a == list.styleContent(Self.item("a", style: HaloStyleRenderTests.glow(20))))
        #expect(a != list.styleContent(Self.item("a", style: Self.glow, x: 3)))
    }

    @Test func pixelsAreTheUnstyledLayer() throws {
        let frame = try LiveFrameRendering().render(HaloDrawList(width: 10, height: 8, frame: 0, items: [Self.item("a")]), width: 10, height: 8, text: nil)
        #expect(HaloDrawList(width: 10, height: 8, frame: 0, items: []).stylePixels(Self.item("a", style: Self.glow)) == frame.pixels)
    }
}
