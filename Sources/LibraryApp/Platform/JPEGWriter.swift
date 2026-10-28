// Platform/JPEGWriter.swift: JPEGWriting on ImageIO and the file system
// (export EX-5, EX-8). `write` encodes the DisplayImage, sRGB-tagged, in the
// format its name's extension says (JPEG, PNG, TIFF or HEIC; JPEG and HEIC at
// quality/100, PNG and TIFF lossless) into memory, then writes the bytes with
// `.withoutOverwriting`, so a name that already exists throws `writeFailed`
// and its file is never touched. `writeSidecar` writes the XMP bytes the same
// way. `writableFormats` is the four formats ImageIO on this Mac can encode.
// export-pack LX-4: the `metadataFrom:dropping:` write passes the encoded
// bytes, the original's bytes and the policy's dropped properties through
// `metadata` (the suite's `services.metadata`) via `CarriedMetadata.still`
// before writing; an unreadable original copies nothing.
import CoreGraphics
import Foundation
import ImageIO
import LibraryModel
import SuiteModel
import UniformTypeIdentifiers

struct JPEGWriter: JPEGWriting {
    /// Copies the original's metadata onto each export, minus the policy's drops (`SuiteServices.metadata`).
    let metadata: any MetadataCarrying

    init(metadata: any MetadataCarrying = FakeMetadata()) { self.metadata = metadata }

    /// The export formats ImageIO on this Mac can encode, asked once (the sheet reads it per body).
    static func writableFormats() -> Set<ExportFormat> { writable }

    private static let writable: Set<ExportFormat> = {
        let types = Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])
        return Set(ExportFormat.allCases.filter { types.contains(uniformType(for: $0).identifier) })
    }()

    /// The uniform type ImageIO encodes `format` as.
    private static func uniformType(for format: ExportFormat) -> UTType {
        switch format {
        case .jpeg: .jpeg
        case .png: .png
        case .tiff: .tiff
        case .heic: .heic
        }
    }

    func existingNames(in folder: String) async throws -> Set<String> {
        do {
            return Set(try FileManager.default.contentsOfDirectory(atPath: folder))
        } catch {
            throw LibraryError.writeFailed(
                path: folder, reason: "Library can't read \(Self.displayName(folder)). Check that you have access to it.")
        }
    }

    func write(_ image: DisplayImage, quality: Int, folder: String, fileName: String) async throws {
        let path = Self.path(folder, fileName)
        try Self.writeNew(try Self.encoded(image, quality: quality, path: path, fileName: fileName), to: path, fileName: fileName)
    }

    /// The same write, with the metadata of the file at `source` minus `dropping` carried onto the encoded bytes.
    func write(_ image: DisplayImage, quality: Int, folder: String, fileName: String,
               metadataFrom source: String?, dropping: Set<String>) async throws {
        let path = Self.path(folder, fileName)
        let data = try Self.encoded(image, quality: quality, path: path, fileName: fileName)
        let carried = CarriedMetadata.still(data, from: source, dropping: dropping, carrier: metadata)
        try Self.writeNew(carried, to: path, fileName: fileName)
    }

    /// `image` encoded in the format `fileName`'s extension names; throws `writeFailed` for any other name or
    /// when this Mac can't encode it.
    private static func encoded(_ image: DisplayImage, quality: Int, path: String, fileName: String) throws -> Data {
        guard let format = ExportFormat.forFileName(fileName) else {
            throw LibraryError.writeFailed(
                path: path, reason: "Library can only write JPEG, PNG, TIFF or HEIC files, not \(fileName).")
        }
        guard let data = encode(image, as: format, quality: quality) else {
            throw LibraryError.writeFailed(path: path, reason: "Couldn't encode \(fileName) as \(format.rawValue).")
        }
        return data
    }

    /// Writes an XMP sidecar's bytes to `folder`/`fileName`, never overwriting.
    func writeSidecar(_ data: Data, folder: String, fileName: String) async throws {
        try Self.writeNew(data, to: Self.path(folder, fileName), fileName: fileName)
    }

    private static func path(_ folder: String, _ fileName: String) -> String {
        URL(fileURLWithPath: folder).appendingPathComponent(fileName).path
    }

    private static func displayName(_ folder: String) -> String {
        URL(fileURLWithPath: folder).lastPathComponent
    }

    /// Writes `data` to a new file at `path`; throws `writeFailed` when the
    /// file exists or can't be written.
    private static func writeNew(_ data: Data, to path: String, fileName: String) throws {
        guard !FileManager.default.fileExists(atPath: path) else {
            throw LibraryError.writeFailed(path: path, reason: "\(fileName) already exists.")
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .withoutOverwriting)
        } catch {
            let exists = FileManager.default.fileExists(atPath: path)
            throw LibraryError.writeFailed(
                path: path, reason: exists ? "\(fileName) already exists." : "Couldn't write \(fileName).")
        }
    }

    /// `image` as `format` bytes tagged sRGB; a lossy format at `quality`
    /// (clamped to 0...100) / 100. Nil when this Mac can't encode `format`.
    private static func encode(_ image: DisplayImage, as format: ExportFormat, quality: Int) -> Data? {
        let (width, height) = (image.size.width, image.size.height)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: Data(image.rgba8) as CFData),
            let picture = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData, Self.uniformType(for: format).identifier as CFString, 1, nil)
        else { return nil }
        let options: [CFString: Any] = format.usesQuality
            ? [kCGImageDestinationLossyCompressionQuality: Double(min(max(quality, 0), 100)) / 100] : [:]
        CGImageDestinationAddImage(destination, picture, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
