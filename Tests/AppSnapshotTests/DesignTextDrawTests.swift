// DesignTextDrawTests.swift: the canvas artwork draws text as styled (style-rows ST-5t, the
// "text drawn as styled" quality row). Title on `cards` with `.fake` services, its style set
// through the Model, drawn alone by DesignArtwork at 200% in a hosted render: its ink at size 32
// is at least 1.8 times as tall as at 16, Bold's ink is wider than Regular's, and Center puts
// the ink's middle within 1 pt of the box's. Ink is every pixel well away from the window
// background, measured in page points. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignTextDrawTests {
    private let zoom = 2.0

    /// Title (node-5) on `cards`, `.fake`, with `change` applied to its style as one step.
    private func title(_ change: (inout DesignTextStyle) -> Void) throws -> DesignNode {
        var model = DesignWorkspace()
        model.useServices(.fake)
        #expect(model.openFixture("cards"))
        model.selectItem("node-5")
        var style = try #require(model.selectedNode).textStyle
        change(&style)
        try model.setStyle(.textStyle(style))
        let node = try #require(model.selectedNode)
        #expect(node.textStyle == style)
        return node
    }

    /// The bounds of `node`'s ink in page points, drawn alone by the canvas artwork at `zoom`.
    private func ink(_ node: DesignNode) throws -> CGRect {
        let artwork = DesignArtwork(painted: [DesignPainted(node: node, backdrop: nil, opacity: 1)], zoom: zoom)
        let image = try #require(render(artwork, scheme: .light))
        let background = try #require(image.colorAt(x: image.pixelsWide - 1, y: image.pixelsHigh - 1)?
            .usingColorSpace(.sRGB))
        var (minX, minY, maxX, maxY) = (Int.max, Int.max, Int.min, Int.min)
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let distance = abs(color.redComponent - background.redComponent)
                    + abs(color.greenComponent - background.greenComponent)
                    + abs(color.blueComponent - background.blueComponent)
                if distance > 0.6 { (minX, minY, maxX, maxY) = (min(minX, x), min(minY, y), max(maxX, x), max(maxY, y)) }
            }
        }
        try #require(minX <= maxX, "\(node.name) drew no ink")
        // One pixel per view point; view points over the zoom are page points.
        return CGRect(x: Double(minX) / zoom, y: Double(minY) / zoom,
                      width: Double(maxX - minX + 1) / zoom, height: Double(maxY - minY + 1) / zoom)
    }

    @Test func size32DrawsAboutTwiceAsTallAs16() throws {
        let small = try ink(title { $0.size = 16 })
        let large = try ink(title { $0.size = 32 })
        #expect(large.height >= 1.8 * small.height, "32 pt ink \(large.height) pt tall, 16 pt \(small.height) pt")
        #expect(large.width > small.width)
    }

    @Test func boldDrawsWiderThanRegular() throws {
        let regular = try ink(title { $0.weight = 400 })
        let bold = try ink(title { $0.weight = 700 })
        #expect(bold.width > regular.width, "Bold \(bold.width) pt wide, Regular \(regular.width) pt")
    }

    @Test func centerPutsTheInkInTheBoxsMiddle() throws {
        let node = try title { $0.alignment = .center }
        let drawn = try ink(node)
        #expect(abs(drawn.midX - node.frame.cgRect.midX) <= 1, "ink middle \(drawn.midX), box middle \(node.frame.cgRect.midX)")
        // Leading keeps it at the box's left, so Center moved it.
        let leading = try ink(title { $0.alignment = .leading })
        #expect(leading.minX < drawn.minX && leading.minX - node.frame.cgRect.minX < 4)
    }

    @Test func theArtworkAndTheEditorShareOneFont() {
        let style = DesignTextStyle(family: DesignTextStyle.default.family, size: 32, weight: 700, alignment: .center)
        let artwork = DesignTextFont.nsFont(style)
        let editor = DesignTextFont.nsFont(style, scale: 0.5)
        #expect(artwork.fontName == editor.fontName && artwork.pointSize == 32 && editor.pointSize == 16)
    }
}
