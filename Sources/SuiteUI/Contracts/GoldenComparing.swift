// GoldenComparing.swift: UC19, the golden image compare contract and
// FakeGoldenComparing (byte equality, share 1 on any change, no diff image).
// Foundation only; verbatim from blueprint section 5.3. The live conformance
// sits in Tests/AppSnapshotTests/GoldenImage.swift (SH-9).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct RGBAImage: Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var bytes: [UInt8]   // width × height × 4, row-major, 8-bit sRGB
    public init(width: Int, height: Int, bytes: [UInt8]) { self.width = width; self.height = height; self.bytes = bytes }
}

public struct GoldenTolerance: Hashable, Sendable {
    public var channel: UInt8        // largest per-channel difference that still counts as equal
    public var maxShare: Double      // largest share of differing pixels that still passes
    public init(channel: UInt8 = 2, maxShare: Double = 0.005) { self.channel = channel; self.maxShare = maxShare }
    public static let standard = GoldenTolerance()
}

public struct GoldenResult: Hashable, Sendable {
    public var passes: Bool
    public var differing: Int
    public var share: Double
    public var diff: RGBAImage?      // differing pixels in magenta over a grey copy; nil when they match exactly
    public init(passes: Bool, differing: Int, share: Double, diff: RGBAImage?) {
        self.passes = passes; self.differing = differing; self.share = share; self.diff = diff
    }
}

public protocol GoldenComparing: Sendable {
    /// Different dimensions, or a malformed buffer, always fail with share 1.
    func compare(_ actual: RGBAImage, to baseline: RGBAImage, tolerance: GoldenTolerance) -> GoldenResult
}

/// Byte-for-byte equality, no diff image.
public struct FakeGoldenComparing: GoldenComparing {
    public init() {}
    public func compare(_ actual: RGBAImage, to baseline: RGBAImage, tolerance: GoldenTolerance) -> GoldenResult {
        actual == baseline ? GoldenResult(passes: true, differing: 0, share: 0, diff: nil)
                           : GoldenResult(passes: false, differing: max(actual.width * actual.height, 1), share: 1, diff: nil)
    }
}
