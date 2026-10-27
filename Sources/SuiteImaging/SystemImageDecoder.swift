// SystemImageDecoder.swift: reads the image files the PNG and JPEG readers don't (HEIC, HEIF, TIFF, a PSD's
// composite) with Core Image's `CIImage(data:options:)`, for Photo's headless document and the CLI on macOS. It
// applies the file's orientation, scales down with Lanczos when asked for a longest side (never up), and renders
// straight-alpha 8-bit sRGB rows, top row first, through one shared `CIContext`. It imports no ImageIO
// (ImageIOImportRatchetTests). On Linux `extensions` is empty and `decode` returns nil, so callers stay Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(CoreImage)
import CoreImage
#endif

public enum SystemImageDecoder {
    /// The extensions `decode` reads on this platform; empty on Linux.
    #if canImport(CoreImage)
    public static let extensions: Set<String> = ["heic", "heif", "tif", "tiff", "psd"]
    #else
    public static let extensions: Set<String> = []
    #endif

    /// `data` as width x height x 4 straight-alpha sRGB bytes, at most `longestSide` on its longer side; nil when this
    /// platform has no reader or the bytes don't decode.
    public static func decode(_ data: Data, longestSide: Int?) -> (rgba8: [UInt8], width: Int, height: Int)? {
        #if canImport(CoreImage)
        guard var image = CIImage(data: data, options: [.applyOrientationProperty: true]), !image.extent.isInfinite,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let longest = max(image.extent.width, image.extent.height)
        if let side = longestSide, side > 0, CGFloat(side) < longest {
            image = image.applyingFilter("CILanczosScaleTransform",
                                         parameters: [kCIInputScaleKey: CGFloat(side) / longest, kCIInputAspectRatioKey: 1])
        }
        let width = Int(image.extent.width.rounded(.down)), height = Int(image.extent.height.rounded(.down))
        guard width > 0, height > 0 else { return nil }
        let bounds = CGRect(x: image.extent.minX, y: image.extent.minY, width: CGFloat(width), height: CGFloat(height))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        context.render(image.unpremultiplyingAlpha(), toBitmap: &bytes, rowBytes: width * 4, bounds: bounds,
                       format: .RGBA8, colorSpace: space)
        return (bytes, width, height)
        #else
        return nil
        #endif
    }

    #if canImport(CoreImage)
    /// One context for every decode: building one per call costs more than the decode of a small file.
    private static let context = CIContext()
    #endif
}
