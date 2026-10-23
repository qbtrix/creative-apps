// FrameParity.swift (lottie-player-check LP-3, #3792): the rules LottiePlayerParityTests holds a reference player's
// frame to. Two frames match when at most 2% of their pixels differ by more than 8 levels in any channel; a loop is
// clean when its last frame doesn't match frame 0, so it doesn't repeat a frame. Frames are raw RGBA, width × height
// × 4 bytes, row-major. A zero-size frame or a buffer of the wrong length never matches. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum FrameParity {
    /// The largest channel difference that still counts as the same pixel.
    public static let levels = 8
    /// The largest share of differing pixels that still counts as the same frame.
    public static let maxShare = 0.02

    /// The share of the `width` × `height` pixels in which some channel differs by more than `levels`; 1 when the
    /// size is zero or either buffer isn't `width` × `height` × 4 bytes long.
    public static func mismatch(_ a: [UInt8], _ b: [UInt8], width: Int, height: Int,
                                levels: Int = FrameParity.levels) -> Double {
        guard let pixels = pixelCount(width, height), a.count == pixels * 4, b.count == pixels * 4 else { return 1 }
        var differing = 0
        for p in 0..<pixels {
            let i = p * 4
            for c in i..<(i + 4) where abs(Int(a[c]) - Int(b[c])) > levels {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(pixels)
    }

    /// Whether `a` and `b` are the same frame: at most `maxShare` of their pixels differ by more than `levels`.
    public static func matches(_ a: [UInt8], _ b: [UInt8], width: Int, height: Int) -> Bool {
        mismatch(a, b, width: width, height: height) <= maxShare
    }

    /// Whether a loop's `last` frame is not `first` again; false for a frame that can't be compared.
    public static func loopIsClean(first: [UInt8], last: [UInt8], width: Int, height: Int) -> Bool {
        guard let pixels = pixelCount(width, height), first.count == pixels * 4, last.count == pixels * 4 else {
            return false
        }
        return !matches(first, last, width: width, height: height)
    }

    /// width × height, or nil when either isn't positive or the byte count would overflow.
    private static func pixelCount(_ width: Int, _ height: Int) -> Int? {
        guard width > 0, height > 0 else { return nil }
        let (count, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, count <= Int.max / 4 else { return nil }
        return count
    }
}
