// Platform/JPEGWriter.swift: JPEGWriting on ImageIO and the file system
// (export EX-5). `write` encodes the DisplayImage as an sRGB-tagged JPEG at
// quality/100 into memory, then writes the bytes with `.withoutOverwriting`,
// so a name that already exists throws `writeFailed` and its file is never
// touched. `writeSidecar` writes the XMP bytes the same way. Only JPEG names
// are written until EX-8 adds the other formats.
import CoreGraphics
import Foundation
import ImageIO
import LibraryModel
import UniformTypeIdentifiers

struct JPEGWriter: JPEGWriting {
    /// The formats this writer can encode on this Mac (EX-8 widens it).
    static func writableFormats() -> Set<ExportFormat> { [.jpeg] }

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
        guard ExportFormat.forFileName(fileName) == .jpeg else {
            throw LibraryError.writeFailed(path: path, reason: "Library can only write JPEG files to \(fileName).")
        }
        guard let data = Self.jpeg(image, quality: quality) else {
            throw LibraryError.writeFailed(path: path, reason: "Couldn't encode \(fileName) as JPEG.")
        }
        try Self.writeNew(data, to: path, fileName: fileName)
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

    /// `image` as JPEG bytes tagged sRGB, at `quality` (clamped to 0...100) / 100.
    private static func jpeg(_ image: DisplayImage, quality: Int) -> Data? {
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
            output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Double(min(max(quality, 0), 100)) / 100
        ]
        CGImageDestinationAddImage(destination, picture, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
