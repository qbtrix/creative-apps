// DesignTransformPaintTests.swift (transform DT-3): the canvas paints a turned or mirrored node where the
// kernel puts it. A red 200 × 100 rectangle at (100, 100) turned 90°, drawn alone by DesignArtwork at 100%,
// is red just inside each corner `TransformRules.corners` gives and above its unturned box, and not where only
// the unturned box would be. A red-to-blue gradient mirrored across paints blue at its left edge. The
// selection box of the same turned node draws a handle at the turned top-left corner and none at the
// unturned one, and its rotate knob turned with it. Two layers turned together from the knob above their box
// (#4224), each outline turned about its own centre: design-transform-turned-several-{light,dark}.png. macOS only.
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignTransformPaintTests {
    static let red = FillColor(r: 1, g: 0, b: 0), blue = FillColor(r: 0, g: 0, b: 1)
    static let frame = DesignRect(x: 100, y: 100, width: 200, height: 100)

    private func turned(_ degrees: Double) -> DesignNode {
        var node = DesignNode(id: "r", name: "R", kind: .rectangle, frame: Self.frame, fill: DesignColor(255, 0, 0))
        node.rotation = degrees
        return node
    }

    private func draw(_ node: DesignNode) throws -> NSBitmapImageRep {
        let artwork = DesignArtwork(painted: [DesignPainted(node: node, backdrop: nil, opacity: 1)], zoom: 1)
        return try #require(render(artwork, scheme: .light))
    }

    private func rgb(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) throws -> (Double, Double, Double) {
        let color = try #require(image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return (color.redComponent, color.greenComponent, color.blueComponent)
    }

    private func isRed(_ c: (Double, Double, Double)) -> Bool { c.0 > 0.85 && c.1 < 0.15 && c.2 < 0.15 }
    private func isBlue(_ c: (Double, Double, Double)) -> Bool { c.0 < 0.15 && c.1 < 0.15 && c.2 > 0.85 }

    @Test func aTurnedNodePaintsAtTheKernelsCorners() throws {
        let node = turned(90)
        let image = try draw(node)
        let corners = TransformRules.corners(of: node.transformBox)
        #expect(corners.count == 4)
        for corner in corners {
            // 6 points in from the corner, towards the centre (200, 150).
            let x = corner.x + (200 - corner.x > 0 ? 6 : -6), y = corner.y + (150 - corner.y > 0 ? 6 : -6)
            let c = try rgb(image, Int(x), Int(y))
            #expect(isRed(c), "inside the turned corner \(corner), got \(c)")
        }
        let above = try rgb(image, 200, 60), unturnedEnd = try rgb(image, 110, 150)
        #expect(isRed(above), "the turned box reaches above its frame, got \(above)")
        #expect(!isRed(unturnedEnd), "the unturned box's left end is bare, got \(unturnedEnd)")
    }

    @Test func aMirroredGradientRunsTheOtherWay() throws {
        var node = turned(0)
        let stops = [GradientStop(offset: 0, color: Self.red), GradientStop(offset: 1, color: Self.blue)]
        node.gradient = Fill.linear(stops: stops, start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
        node.flipX = true
        let image = try draw(node)
        let left = try rgb(image, 102, 150), right = try rgb(image, 297, 150)
        #expect(isBlue(left), "the mirror puts the last stop on the left, got \(left)")
        #expect(isRed(right), "and the first on the right, got \(right)")
    }

    @Test func theHandlesTurnWithTheNode() throws {
        let node = turned(90)
        let box = DesignSelectionBox(rect: node.frame, zoom: 1, handles: true, degrees: node.rotation)
        let image = try #require(render(box, scheme: .light))
        let corner = try #require(TransformRules.corners(of: node.transformBox).first)
        func accentPixels(near x: Double, _ y: Double) throws -> Int {
            var count = 0
            for py in Int(y) - 6...Int(y) + 6 {
                for px in Int(x) - 6...Int(x) + 6 {
                    let c = try rgb(image, px, py)
                    if c.2 - c.0 > 0.4 { count += 1 }
                }
            }
            return count
        }
        #expect(try accentPixels(near: corner.x, corner.y) > 0, "a handle at the turned top-left \(corner)")
        #expect(try accentPixels(near: 100, 100) == 0, "no handle at the unturned top-left")
    }

    @Test func theKnobTurnsWithTheNode() throws {
        // Upright the knob sits 2 handles (16) above the top's middle, (200, 84); 90° clockwise about
        // (200, 150) puts it at (266, 150), right of the turned box (x 150 to 250).
        let node = turned(90)
        func accent(_ box: DesignSelectionBox) throws -> Int {
            let image = try #require(render(box, scheme: .light))
            var count = 0
            for py in 144...156 { for px in 260...272 where try rgb(image, px, py).2 - rgb(image, px, py).0 > 0.4 { count += 1 } }
            return count
        }
        #expect(try accent(DesignSelectionBox(rect: node.frame, zoom: 1, degrees: 90, knob: true)) > 0)
        #expect(try accent(DesignSelectionBox(rect: node.frame, zoom: 1, degrees: 90)) == 0, "no knob without `knob`")
    }

    @Test func severalLayersTurnedFromTheirKnob() throws {
        var model = DesignWorkspace()
        model.newFile()
        try model.addNode(.rectangle, frame: DesignRect(x: 200, y: 200, width: 300, height: 150), in: "node-1")
        try model.addNode(.rectangle, frame: DesignRect(x: 600, y: 300, width: 150, height: 250), in: "node-1")
        model.selectItem("node-2")
        model.toggleSelection("node-3")
        // The box runs from 200, 200 to 750, 550; its knob sits 12 above the top's middle, at 475, 188.
        model.drag(from: DesignPoint(x: 475, y: 188), to: DesignPoint(x: 600, y: 200))
        model.endDrag()
        try #require(model.selectedNodeIDs == ["node-2", "node-3"])
        #expect(model.selectedNodes.allSatisfy { $0.rotation > 0 })
        #expect(model.undoActionName == "Undo Rotate")
        try shootCanvas(model, "design-transform-turned-several")
    }
}
