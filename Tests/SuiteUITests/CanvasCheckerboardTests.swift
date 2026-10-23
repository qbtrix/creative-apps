// CanvasCheckerboardTests.swift: the canvas checkerboard is one layer with a
// pattern background, never a drawing the artboard's size. A viewport over an
// 8K document at 100 % shows it as a layer whose background is the checker
// pattern and which keeps no backing store, so a pan or a zoom draws nothing
// on the CPU; the layer takes no clicks. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite(.serialized) struct CanvasCheckerboardTests {
    @Test func thePatternRepeatsBothTones() throws {
        let light = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), dark = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        let color = try #require(CanvasCheckerboard.pattern(light: light, dark: dark))
        #expect(color.pattern != nil)
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        layer.backgroundColor = color
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        layer.render(in: context)
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let red = { (x: Int, y: Int) in bytes[(y * 32 + x) * 4] }
        // One square in from the corner the tone flips, and it repeats a tile further on.
        #expect(Set([red(2, 2), red(10, 2)]) == [0, 255])
        #expect(red(2, 2) == red(18, 2) && red(2, 2) == red(10, 10))
    }

    @Test func aViewportShowsItAsAPatternLayerWithNoBackingStore() async throws {
        let viewport = CanvasViewport(documentSize: CGSize(width: 7680, height: 4320), zoom: 1) { Color.clear } overlay: {
            EmptyView()
        }
        let host = NSHostingView(rootView: viewport)
        host.frame = CGRect(x: 0, y: 0, width: 1280, height: 820)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        var found: [NSView] = []
        func walk(_ view: NSView) {
            if view.layer?.backgroundColor?.pattern != nil { found.append(view) }
            view.subviews.forEach(walk)
        }
        walk(host)
        let board = try #require(found.first, "no checkerboard layer")
        #expect(board.frame.width >= 7680)
        #expect(board.layer?.contents == nil, "the checkerboard drew into a backing store")
        #expect(board.hitTest(CGPoint(x: 10, y: 10)) == nil)
        window.close()
    }
}
