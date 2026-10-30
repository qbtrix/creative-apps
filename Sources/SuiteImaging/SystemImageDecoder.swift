// SystemImageDecoder.swift: reads image files with Core Image's `CIImage(data:options:)`, for Photo's headless
// document and the CLI on macOS: the files the PNG and JPEG readers don't (HEIC, HEIF, TIFF, a PSD's composite),
// colour matched to sRGB, and PNGs `asStored` (no colour management, float working format, so an 8-bit pixel with
// any alpha above 0 comes back as the file holds it), which is many times faster than the pure-Swift PNG reader on
// a camera-size layer. It applies the file's orientation, scales down with Lanczos when asked for a longest side
// (never up) to whole pixels, and renders straight-alpha 8-bit rows, top row first. `size(of:)` reads the pixel
// size without decoding. It imports no ImageIO (ImageIOImportRatchetTests). On Linux `extensions` is empty and
// `decode` and `size` return nil, so callers stay Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(CoreImage)
import CoreImage
#endif
import SuiteModel

public enum SystemImageDecoder {
    /// The extensions `decode` reads on this platform; empty on Linux.
    #if canImport(CoreImage)
    public static let extensions = Set(
        SuiteImageFormat.heic.extensions
            + SuiteImageFormat.heif.extensions
            + SuiteImageFormat.tiff.extensions
            + ["psd"])
    #else
    public static let extensions: Set<String> = []
    #endif

    /// `data` as width x height x 4 straight-alpha bytes, at most `longestSide` on its longer side: sRGB, or the
    /// file's own values when `asStored`; nil when this platform has no reader or the bytes don't decode.
    public static func decode(_ data: Data, longestSide: Int?,
                              asStored: Bool = false) -> (rgba8: [UInt8], width: Int, height: Int)? {
        #if canImport(CoreImage)
        var options: [CIImageOption: Any] = [.applyOrientationProperty: true]
        if asStored { options[.colorSpace] = NSNull() }
        // nil renders in the context's output space: none for `asStored`.
        let space = asStored ? nil : CGColorSpace(name: CGColorSpace.sRGB)
        guard var image = CIImage(data: data, options: options), !image.extent.isInfinite,
              asStored || space != nil else { return nil }
        let longest = max(image.extent.width, image.extent.height)
        if let side = longestSide, side > 0, CGFloat(side) < longest {
            let scale = CGFloat(side) / longest, source = image.extent
            // Lanczos spreads past the scaled rect and fades the edges, so scale the clamped image, crop the
            // scaled rect, and stretch that to whole pixels at the origin so no edge row is lost or clear.
            let nominal = CGRect(x: source.minX * scale, y: source.minY * scale,
                                 width: source.width * scale, height: source.height * scale)
            let (w, h) = (max(nominal.width.rounded(), 1), max(nominal.height.rounded(), 1))
            image = image.clampedToExtent()
                .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
                .cropped(to: nominal)
                .transformed(by: CGAffineTransform(translationX: -nominal.minX, y: -nominal.minY))
                .transformed(by: CGAffineTransform(scaleX: w / nominal.width, y: h / nominal.height))
                .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        }
        let width = Int(image.extent.width.rounded(.down)), height = Int(image.extent.height.rounded(.down))
        guard width > 0, height > 0 else { return nil }
        let bounds = CGRect(x: image.extent.minX, y: image.extent.minY, width: CGFloat(width), height: CGFloat(height))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        (asStored ? storedContext : context).render(image.unpremultiplyingAlpha(), toBitmap: &bytes, rowBytes: width * 4,
                                                    bounds: bounds, format: .RGBA8, colorSpace: space)
        return (bytes, width, height)
        #else
        return nil
        #endif
    }

    /// The pixel size `decode` would give at full size (orientation applied), read from the header; nil when this
    /// platform has no reader or the bytes aren't an image it knows.
    public static func size(of data: Data) -> (width: Int, height: Int)? {
        #if canImport(CoreImage)
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]), !image.extent.isInfinite,
              image.extent.width >= 1, image.extent.height >= 1 else { return nil }
        return (Int(image.extent.width.rounded(.down)), Int(image.extent.height.rounded(.down)))
        #else
        return nil
        #endif
    }

    #if canImport(CoreImage)
    /// One context for every decode: building one per call costs more than the decode of a small file.
    private static let context = CIContext()
    /// The `asStored` context: no colour management, and premultiplying in 32-bit float, so it is undone exactly.
    private static let storedContext = CIContext(options: [
        .workingColorSpace: NSNull(), .outputColorSpace: NSNull(), .workingFormat: CIFormat.RGBAf,
    ])
    #endif
}
