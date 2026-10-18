// CanvasPointMarksTests.swift: CanvasPointMark (CanvasMarks+Points.swift)
// keeps its on-screen size at zoom 1 and 4 while its centre follows the zoom,
// in its frame and in the pixels it draws over light and over dark pixels; it
// takes no hit; and it is hidden from accessibility, so the window's tree
// holds no element of its own (#706, #737). macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@Test func thePointMarkKeepsItsSizeAtEveryZoom() {
    let point = CGPoint(x: 20, y: 10)
    let one = CanvasPointMark.frame(point: point, zoom: 1)
    let four = CanvasPointMark.frame(point: point, zoom: 4)
    #expect(one.size == four.size)
    #expect(one.width == SuiteSize.pointMarkRing + SuiteSize.pointMarkPaper)
    #expect(CGPoint(x: one.midX, y: one.midY) == point)
    #expect(CGPoint(x: four.midX, y: four.midY) == CGPoint(x: 80, y: 40))
}

@Test func thePointMarkTakesNoHitAndIsHidden() {
    #expect(!CanvasPointMark.takesHits)
    #expect(CanvasPointMark.hiddenFromAccessibility)
}

/// Over white the black ink shows, over black the white halo does, and the
/// drawn box is the same size at zoom 1 and 4 (the same view point, 50, 50).
@MainActor @Test(arguments: [false, true]) func thePointMarkDrawsTheSameSizeOverAnyPixels(_ dark: Bool) throws {
    var boxes = [CGRect]()
    for (zoom, point) in [(1.0, CGPoint(x: 50, y: 50)), (4.0, CGPoint(x: 12.5, y: 12.5))] {
        let under = dark ? SuiteColor.overlayInk : SuiteColor.overlayPaper
        let view = ZStack { under; CanvasPointMark(point: point, zoom: zoom) }.frame(width: 100, height: 100)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        boxes.append(try #require(markedBox(image, background: dark ? 0 : 255), "nothing drawn at zoom \(zoom)"))
    }
    let side = SuiteSize.pointMarkRing + SuiteSize.pointMarkPaper
    for box in boxes {
        #expect(box.width >= SuiteSize.pointMarkRing && box.width <= side + 1, "\(box)")
        #expect(abs(box.midX - 50) <= 1 && abs(box.midY - 50) <= 1, "\(box)")
    }
    #expect(boxes.count == 2 && abs(boxes[0].width - boxes[1].width) <= 1 && abs(boxes[0].height - boxes[1].height) <= 1)
}

/// The window's accessibility tree over a labelled text and the mark holds
/// the text and nothing the mark adds.
@MainActor @Test func thePointMarkAddsNoAccessibilityElement() {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let size = CGSize(width: 200, height: 120)
    func elements(_ view: some View) -> Int {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return pointMarkNodes(in: window).count
    }
    let bare = elements(Text(verbatim: "Under"))
    let marked = elements(ZStack { Text(verbatim: "Under"); CanvasPointMark(point: CGPoint(x: 20, y: 20), zoom: 2) })
    #expect(bare > 1)
    #expect(marked == bare)
}

@MainActor private func pointMarkNodes(in element: Any) -> [AnyObject] {
    let node = element as AnyObject
    return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { pointMarkNodes(in: $0) }
}

/// The box of pixels whose red channel is far from `background`, or nil.
private func markedBox(_ image: CGImage, background: UInt8) -> CGRect? {
    let width = image.width, height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { return nil }
    var box: CGRect?
    for y in 0..<height {
        for x in 0..<width where abs(Int(bytes[(y * width + x) * 4]) - Int(background)) > 64 {
            let pixel = CGRect(x: x, y: y, width: 1, height: 1)
            box = box?.union(pixel) ?? pixel
        }
    }
    return box
}
