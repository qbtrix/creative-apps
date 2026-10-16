// PhotoImageFile.swift: opening and exporting image files. The file formats
// themselves (PNG, JPEG, HEIC through ImageIO) live in PhotoApp behind
// PhotoImageCodec, so everything here runs and is tested on Linux with a fake
// codec. Bytes cross that line as DecodedImage: 8-bit sRGB, straight alpha,
// row-major. Opening replaces the image with one "Background" layer and keeps
// the file name; a photo over `maxOpenPixels` is decoded smaller (the codec
// is told the longest side to fit, `decodeLongestSide`), which keeps a layer
// under 256 MB. Exporting flattens the visible layers with the adjustments:
// PNG keeps transparency, JPEG is laid on opaque white first. A failed open
// or export leaves the workspace as it was. Export and Save As offer the
// document's name with the format's extension (`fileName(for:)`); Save As
// renames the document to the file it wrote (`didSave(as:)`). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// Pixels on their way in from or out to a file.
public struct DecodedImage: Sendable, Equatable {
    /// width x height x 4 bytes, sRGB, straight alpha.
    public let rgba8: [UInt8]
    public let width: Int
    public let height: Int

    public init(rgba8: [UInt8], width: Int, height: Int) {
        self.rgba8 = rgba8
        self.width = width
        self.height = height
    }
}

/// The formats Export writes.
public enum ImageFormat: String, CaseIterable, Sendable {
    case png, jpeg

    public var title: String { self == .png ? "PNG" : "JPEG" }
    public var fileExtension: String { self == .png ? "png" : "jpg" }

    /// The format a file name's extension names, or nil ("photo.JPG" is JPEG).
    public init?(fileName: String) {
        let ext = fileName.split(separator: ".").last.map { $0.lowercased() } ?? ""
        switch ext {
        case "png": self = .png
        case "jpg", "jpeg": self = .jpeg
        default: return nil
        }
    }
}

/// Reads and writes image files; PhotoApp's is ImageIO.
public protocol PhotoImageCodec: Sendable {
    /// The image in `data`, no longer on its longest side than `longestSide`
    /// when that is given.
    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage
    /// `image` as a file in `format`; `quality` (0...1) for JPEG.
    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data
}

extension PhotoWorkspace {
    /// The most pixels an opened image keeps: 16 megapixels.
    public static let maxOpenPixels = 16 * 1024 * 1024

    /// The longest side to decode a `width` x `height` file at so it keeps at
    /// most `maxOpenPixels`, or nil when it already fits.
    public static func decodeLongestSide(width: Int, height: Int) -> Int? {
        guard width > 0, height > 0 else { return nil }
        let pixels = Double(width) * Double(height)
        guard pixels > Double(maxOpenPixels) else { return nil }
        let scale = (Double(maxOpenPixels) / pixels).squareRoot()
        return max(Int((Double(max(width, height)) * scale).rounded(.down)), 1)
    }

    /// Opens 8-bit straight-alpha sRGB bytes as a new image named `name`, with
    /// one "Background" layer, default adjustments and an empty history.
    /// Throws `RasterError` for a bad size or byte count; the workspace is
    /// unchanged.
    public mutating func open(rgba8 bytes: [UInt8], width: Int, height: Int, name: String) throws {
        let background = try PixelBuffer(rgba8: bytes, width: width, height: height)
        start(with: TiledPixels(background), name: name)
    }

    /// Opens a file's `data` through `codec`. Throws what the codec or
    /// `open(rgba8:width:height:name:)` throws.
    public mutating func open(_ data: Data, name: String, codec: some PhotoImageCodec, longestSide: Int? = nil) throws {
        let image = try codec.decode(data, longestSide: longestSide)
        try open(rgba8: image.rgba8, width: image.width, height: image.height, name: name)
    }

    /// The flattened image's bytes for `format`: as is for PNG, on opaque
    /// white for JPEG. Throws with no image open.
    public func exportPixels(as format: ImageFormat) throws -> DecodedImage {
        var flat = try composite()
        if format == .jpeg { flat = try flat.onWhite() }
        return DecodedImage(rgba8: try flat.rgba8(), width: flat.width, height: flat.height)
    }

    /// The name Export and Save As offer: the document's name with `format`'s
    /// extension ("beach.HEIC" as PNG is "beach.png"); "Untitled.png" for a new image.
    public func fileName(for format: ImageFormat) -> String {
        let name = documentName ?? "Untitled"
        let base = name.lastIndex(of: ".").map { String(name[..<$0]) } ?? name
        return (base.isEmpty ? name : base) + "." + format.fileExtension
    }

    /// Save As wrote the image to a file named `name`: the window title and
    /// the inspector's image header name it from now on. Not an undo step; ignored with no image open.
    public mutating func didSave(as name: String) {
        guard canvas != nil else { return }
        documentName = name
    }

    /// The flattened image as a `format` file through `codec`, rendered tile by
    /// tile in parallel (the same bytes as `exportPixels`).
    public func export(as format: ImageFormat, quality: Double = 0.9, codec: some PhotoImageCodec) async throws -> Data {
        let frame = try await PhotoRenderer.render(self, onWhite: format == .jpeg)
        let image = DecodedImage(rgba8: frame.rgba8, width: frame.width, height: frame.height)
        return try codec.encode(image, as: format, quality: min(max(quality.isNaN ? 0.9 : quality, 0), 1))
    }
}
