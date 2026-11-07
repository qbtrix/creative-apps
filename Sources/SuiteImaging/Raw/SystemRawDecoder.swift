// SystemRawDecoder.swift: the macOS decoder over Core Image's documented
// `CIRAWFilter` (shared-raw SR-4). It opens the file with
// `CIRAWFilter(imageURL:)` or `CIRAWFilter(imageData:identifierHint:)` (the
// hint is the extension's type), reads the camera from `properties`
// ("{TIFF}" Model, else Make), develops with `boostAmount` 0 (linear),
// `baselineExposure` 0 (SuiteRaw applies the file's), exposure 0 and
// highlight recovery where the camera supports it, turns the result upright
// itself and renders into extended-range linear sRGB floats, alpha 1, with one
// shared default `CIContext()`. The embedded preview is turned upright the
// same way and scaled down to `longestSide`, never up. It imports no ImageIO
// and no Metal (ImageIOImportRatchetTests, ImagingBoundaryTests). Linux builds
// without it. Mutations: SuiteImaging.SystemRawDecoder.
#if canImport(CoreImage)
import CoreImage
import CoreRaster
import UniformTypeIdentifiers

public struct SystemRawDecoder: RawDecoding {
    public init() {}

    /// One context for every render: Core Image's default, which picks its own device.
    static let context = CIContext()

    /// An opened file: its format, the filter with nothing developed yet, and the file's orientation.
    struct Opened {
        var format: RawFormat
        var filter: CIRAWFilter
        var orientation: CGImagePropertyOrientation
    }

    public func info(_ source: RawSource) throws(RawRefusal) -> RawFileInfo {
        let opened = try Self.open(source)
        let filter = opened.filter
        let tiff = filter.properties["{TIFF}"] as? [String: Any]
        let model = tiff?["Model"] as? String
        let camera = model ?? (tiff?["Make"] as? String) ?? "this camera"
        let baseline = Double(filter.baselineExposure)
        let supported = model.map { CIRAWFilter.supportedCameraModels.contains($0) } ?? false
        Self.configure(filter, scale: 1, draft: false)
        let image = filter.outputImage.map { Self.upright($0, opened.orientation) }
        let preview = filter.previewImage.map { Self.upright($0, opened.orientation) }
        let size = image.flatMap { Self.size($0) }
        return RawFileInfo(
            format: opened.format, camera: camera,
            developable: (supported || opened.format.fileExtension == "DNG") && size != nil,
            size: size ?? RawSize(width: 0, height: 0), previewSize: preview.flatMap { Self.size($0) },
            baselineStops: baseline.isFinite ? baseline : 0)
    }

    public func embeddedPreview(_ source: RawSource, longestSide: Int) throws(RawRefusal) -> PixelBuffer {
        let opened = try Self.open(source)
        guard let stored = opened.filter.previewImage else { throw .unreadable(opened.format) }
        let image = Self.upright(stored, opened.orientation)
        guard let size = Self.size(image) else { throw .unreadable(opened.format) }
        let factor = min(1, Double(max(1, longestSide)) / Double(size.longSide))
        let scaled = factor < 1 ? image.transformed(by: CGAffineTransform(scaleX: factor, y: factor)) : image
        return try Self.render(scaled, format: opened.format)
    }

    public func develop(_ source: RawSource, scale: Double, draft: Bool) throws(RawRefusal) -> PixelBuffer {
        let opened = try Self.open(source)
        Self.configure(opened.filter, scale: scale, draft: draft)
        guard let image = opened.filter.outputImage else {
            let tiff = opened.filter.properties["{TIFF}"] as? [String: Any]
            let camera = (tiff?["Model"] as? String) ?? (tiff?["Make"] as? String) ?? "this camera"
            throw .undevelopable(camera: camera)
        }
        return try Self.render(Self.upright(image, opened.orientation), format: opened.format)
    }

    /// The filter for `source`, or `.unreadable` when Core Image can't open it.
    static func open(_ source: RawSource) throws(RawRefusal) -> Opened {
        let name = source.fileName
        let ext = name.lastIndex(of: ".").map { String(name[name.index(after: $0)...]) } ?? ""
        let format = RawFormat(checkedExtension: ext)
        let made: CIRAWFilter?
        switch source {
        case .file(let url): made = CIRAWFilter(imageURL: url)
        case .bytes(let data, _): made = CIRAWFilter(imageData: data, identifierHint: UTType(filenameExtension: ext)?.identifier)
        }
        guard let filter = made else { throw .unreadable(format) }
        // The decoder turns the picture upright itself, so the filter's own turn is undone first.
        let orientation = filter.orientation
        filter.orientation = .up
        return Opened(format: format, filter: filter, orientation: orientation)
    }

    /// Linear, no baseline (SuiteRaw applies it), highlights recovered where the camera allows.
    static func configure(_ filter: CIRAWFilter, scale: Double, draft: Bool) {
        filter.boostAmount = 0
        filter.baselineExposure = 0
        filter.exposure = 0
        filter.isHighlightRecoveryEnabled = filter.isHighlightRecoverySupported
        filter.scaleFactor = Float(scale.isFinite ? min(1, max(0, scale)) : 1)
        filter.isDraftModeEnabled = draft
    }

    static func upright(_ image: CIImage, _ orientation: CGImagePropertyOrientation) -> CIImage {
        image.oriented(orientation)
    }

    /// The image's size in whole pixels, or nil when it is empty or unbounded.
    static func size(_ image: CIImage) -> RawSize? {
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite, extent.width >= 1, extent.height >= 1,
              extent.width <= CGFloat(PixelBuffer.maxPixels), extent.height <= CGFloat(PixelBuffer.maxPixels) else { return nil }
        return RawSize(width: Int(extent.width.rounded()), height: Int(extent.height.rounded()))
    }

    /// `image` rendered into a buffer: extended-range linear sRGB, Float32, alpha 1.
    static func render(_ image: CIImage, format: RawFormat) throws(RawRefusal) -> PixelBuffer {
        guard let size = Self.size(image) else { throw .unreadable(format) }
        let pixels: Int
        do { pixels = try PixelBuffer.validatedSize(width: size.width, height: size.height) } catch {
            throw .tooLarge(pixels: size.width.multipliedReportingOverflow(by: size.height).partialValue)
        }
        guard let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else { throw .unreadable(format) }
        let origin = image.extent.origin
        let placed = image.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
        let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        var floats = [Float](repeating: 0, count: pixels * 4)
        floats.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            context.render(placed, toBitmap: base, rowBytes: size.width * 16, bounds: bounds,
                           format: .RGBAf, colorSpace: space)
        }
        do {
            var buffer = try PixelBuffer(width: size.width, height: size.height)
            func finite(_ value: Float) -> Float { value.isFinite ? value : 0 }
            for y in 0..<size.height {
                for x in 0..<size.width {
                    let i = (y * size.width + x) * 4
                    try buffer.setPixel(x: x, y: y, RGBA(r: finite(floats[i]), g: finite(floats[i + 1]), b: finite(floats[i + 2]), a: 1))
                }
            }
            return buffer
        } catch {
            throw .unreadable(format)
        }
    }
}
#endif
