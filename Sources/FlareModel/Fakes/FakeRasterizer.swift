// FakeRasterizer.swift: FrameRasterizing without CoreGraphics (docs/blueprints/flare.md, 6.3). Every frame is the same
// valid 1 × 1 transparent PNG, whatever the list, scale or background, so export runs on Linux and in the fake app.
// A movie frame is the list's background, flat at the asked size (clear when transparent), filled by doubling so a
// full-size GIF run stays cheap in a debug build.
// FlareApp's `StageRasterizer` (LA-1) draws the real pixels.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

public struct FakeRasterizer: FrameRasterizing {
    /// The PNG every call returns: signature, IHDR (1 × 1, 8-bit RGBA), one IDAT row of zeros, IEND.
    public static let png = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00,
        0x02, 0x00, 0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ])

    public init() {}

    public func png(_: StageDrawList, scale _: Double, transparent _: Bool) throws -> Data { Self.png }

    public func frame(_ list: StageDrawList, width: Int, height: Int, transparent: Bool) throws -> MediaFrame {
        let c = list.background
        let pixel = [c.r, c.g, c.b, transparent ? 0 : c.a].map { UInt8((min(max($0, 0), 1) * 255).rounded()) }
        let (count, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, count > 0 else { return try MediaFrame(width: width, height: height, rgba: []) }
        // Doubled, not joined per pixel: a 550 x 400 GIF frame joined 220k small arrays, ~0.3 s a frame in debug (#5271).
        var rgba = pixel
        rgba.reserveCapacity(count * 4)
        while rgba.count < count * 4 { rgba.append(contentsOf: rgba.prefix(count * 4 - rgba.count)) }
        return try MediaFrame(width: width, height: height, rgba: rgba)
    }
}
