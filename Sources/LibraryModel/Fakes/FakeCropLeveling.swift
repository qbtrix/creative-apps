// Fakes/FakeCropLeveling.swift: `FakeCrop`'s Auto. Any image that isn't one
// flat color levels by 2.5 degrees; a flat one has no horizon (nil).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

extension FakeCrop: CropLeveling {
    public func levelAngle(_ image: PixelBuffer) throws -> Double? {
        let bytes = try image.rgba8(colorSpace: .sRGB)
        guard bytes.count >= 4 else { return nil }
        let first = bytes[0..<4]
        for start in stride(from: 4, to: bytes.count - 3, by: 4) where bytes[start..<(start + 4)] != first {
            return 2.5
        }
        return nil
    }
}
