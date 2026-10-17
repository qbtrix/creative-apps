// TimelineLaneBedTests.swift: what a lane draws stays on its bed (Mac finish
// pass, slice TL-b). A clip block running past the lane's end stops on the
// bed's rounded corner (#1735); a hold tween runs dashed on the keys' centre
// line, not offset below it (#1742); a selected track name's fill is the
// bed's height, inset like the bed (#1744). Pixels from TimelineLanePainter
// and ImageRenderer at 1x in Light. macOS only.
import AppKit
import SwiftUI
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineLaneBedTests {
    private static let mapping = FrameMapping(duration: 120, frameWidth: 10)
    private static let size = CGSize(width: 200, height: SuiteSize.timelineLane)

    @Test func aClipPastTheLaneEndStopsOnTheBedsCorner() throws {
        let track = TimelineTrack(id: "logo", name: "Logo", spans: [0...110])
        let bitmap = try Self.paint(TimelineLaneDrawing(track, mapping: Self.mapping))
        // (199, 5) is inside the block's 24 pt height but outside the bed's 12 pt top-right corner.
        #expect(bitmap.alpha(x: 199, y: 5) == 0, "the clip spills past the bed's rounded end")
        #expect(bitmap.alpha(x: 100, y: 5) > 0, "the clip still fills the bed's middle")
    }

    @Test func aHoldTweenRunsDashedOnTheKeysCentreLine() throws {
        let keys = [TimelineKey(frame: 0, shape: .hold), TimelineKey(frame: 12, shape: .linear),
                    TimelineKey(frame: 18, shape: .linear)]
        let palette = TimelineLanePalette(try #require(NSAppearance(named: .aqua)))
        let bitmap = try Self.paint(TimelineLaneDrawing(
            TimelineTrack(id: "p", name: "P", keys: keys), mapping: Self.mapping), palette: palette)
        let mid = Int(Self.size.height / 2)
        // Between the hold key at x 8 and the next at x 128, clear of both 10 pt keys.
        let held = (20..<116).filter { bitmap.rgb(x: $0, y: mid) == palette.tween }.count
        #expect(held > 30 && held < 70, "the hold tween is dashed on the centre line: \(held) of 96 pixels")
        let line = (140..<180).filter { bitmap.rgb(x: $0, y: mid) == palette.tween }.count
        #expect(line > 10 && line == (140..<180).filter { bitmap.rgb(x: $0, y: mid) != palette.bed }.count,
                "a linear tween is solid: \(line)")
    }

    @Test func aSelectedNameIsTheBedsHeight() throws {
        let button = Button {} label: { Text("Rotation").frame(maxWidth: .infinity, maxHeight: .infinity) }
            .buttonStyle(TimelineNameStyle(selected: true))
            .frame(width: Self.size.width, height: Self.size.height)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: button)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let bitmap = try Bitmap(image)
        let bed = TimelineLaneGeometry.bed(width: Self.size.width, height: Self.size.height)
        #expect(bitmap.alpha(x: 100, y: 0) == 0, "the name's fill reaches above the bed")
        #expect(bitmap.alpha(x: 100, y: Int(Self.size.height) - 1) == 0, "the name's fill reaches below the bed")
        #expect(bitmap.alpha(x: 100, y: Int(bed.minY) + 1) > 0, "the name's fill covers the bed's rows")
        #expect(bitmap.alpha(x: 0, y: Int(bed.minY)) == 0, "the name's fill has the bed's rounded corner")
    }

    private static func paint(_ lane: TimelineLaneDrawing, palette given: TimelineLanePalette? = nil) throws -> Bitmap {
        let palette = try given ?? TimelineLanePalette(#require(NSAppearance(named: .aqua)))
        let context = try Bitmap.context(size)
        // The painter's y runs down, as in a flipped layer.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        TimelineLanePainter.draw(lane, palette: palette, size: size, in: context)
        return try Bitmap(try #require(context.makeImage()))
    }
}

/// An sRGB RGBA bitmap read by x and y from the top.
private struct Bitmap {
    let bytes: [UInt8]
    let width: Int
    let rowBytes: Int

    static func context(_ size: CGSize) throws -> CGContext {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        return try #require(CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    }

    init(_ image: CGImage) throws {
        let context = try Self.context(CGSize(width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try #require(context.data)
        width = image.width
        rowBytes = context.bytesPerRow
        bytes = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: rowBytes * image.height))
    }

    func alpha(x: Int, y: Int) -> UInt8 { bytes[y * rowBytes + x * 4 + 3] }

    func rgb(x: Int, y: Int) -> UInt32 {
        let at = y * rowBytes + x * 4
        return UInt32(bytes[at]) << 16 | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2])
    }
}
