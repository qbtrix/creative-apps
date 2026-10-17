// TimelineLanesViewTests.swift: TL-21's AppKit lanes renderer (timeline packet).
// Eight lanes make eight layers, whatever their key count; an update of lanes
// 2 and 5 draws twice, the same lanes again never; a key's pixels are
// TimelineLook's fill in all four appearances. macOS only.
import AppKit
import Foundation
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineLanesViewTests {
    private static let mapping = FrameMapping(duration: 120, frameWidth: 10)
    private static let frames = [10, 40, 70]

    /// Lane `index`: three keys, the one at 40 picked, the last moved by `shift`.
    private static func lane(_ index: Int, shift: Int = 0) -> TimelineLaneDrawing {
        let keys = [TimelineKey(frame: 10, shape: .linear), TimelineKey(frame: 40, shape: .eased),
                    TimelineKey(frame: 70 + shift, shape: .hold)]
        return TimelineLaneDrawing(
            TimelineTrack(id: "lane-\(index)", name: "Lane \(index)", keys: keys, pickedFrames: [40]), mapping: mapping)
    }

    private static let lanes = (0..<8).map { lane($0) }

    private func makeView() -> TimelineLanesView {
        let view = TimelineLanesView(frame: CGRect(x: 0, y: 0, width: 720, height: SuiteSize.timelineLane * 8))
        view.update(Self.lanes)
        return view
    }

    @Test func eightLanesMakeEightLayersTiledTopDown() {
        let view = makeView()
        let frames = view.laneLayers.map(\.frame)
        #expect(frames == TimelineLaneLayers.frames(count: 8, width: 720) && frames.count == 8)
    }

    @Test func anUpdateOfLanesTwoAndFiveDrawsTwice() {
        let view = makeView()
        let first = view.draws
        var new = Self.lanes
        new[2] = Self.lane(2, shift: 1)
        new[5] = Self.lane(5, shift: 2)
        view.update(new)
        let second = view.draws
        view.update(new)
        let third = view.draws
        #expect(first == 8, "the first update draws every lane")
        #expect(second - first == 2 && third == second)
        #expect(view.laneLayers[2].lane == new[2] && view.laneLayers[5].lane == new[5])
    }

    /// `column` indexes SuiteHex.values: dark, light, darkContrast, lightContrast.
    @Test(arguments: [(NSAppearance.Name.darkAqua, 0), (.aqua, 1),
                      (.accessibilityHighContrastDarkAqua, 2), (.accessibilityHighContrastAqua, 3)])
    func theKeyPixelsAreTimelineLooksFill(name: NSAppearance.Name, column: Int) throws {
        let pixels = try SuiteHex.$increasedContrast.withValue(column >= 2) { () throws -> [Int: UInt32] in
            let view = makeView()
            view.appearance = NSAppearance(named: name)
            view.update(Self.lanes)
            return try Self.render(try #require(view.laneLayers.first))
        }
        for frame in Self.frames {
            let want = TimelineLook.keyFill(picked: frame == 40, atPlayhead: false).values[column]
            let got = pixels[frame] ?? 0
            let drift = [16, 8, 0].map { (shift: UInt32) in abs(Int(got >> shift & 0xFF) - Int(want >> shift & 0xFF)) }
            #expect(drift.allSatisfy { $0 <= 1 }, "\(name.rawValue) key \(frame): \(String(got, radix: 16)) vs \(String(want, radix: 16))")
        }
    }

    /// `layer` drawn at 1× into an sRGB bitmap, as 0xRRGGBB at each key's centre.
    private static func render(_ layer: TimelineLaneLayer) throws -> [Int: UInt32] {
        let (width, height) = (Int(layer.bounds.width), Int(layer.bounds.height))
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        layer.draw(in: context)
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let row = height / 2  // the bed is centred, so its middle row is the same flipped or not
        var pixels: [Int: UInt32] = [:]
        for frame in frames where (0..<width).contains(Int(tickX(mapping, frame))) && row > 0 {
            let at = row * context.bytesPerRow + Int(tickX(mapping, frame)) * 4
            pixels[frame] = UInt32(bytes[at]) << 16 | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2])
        }
        return pixels
    }
}
