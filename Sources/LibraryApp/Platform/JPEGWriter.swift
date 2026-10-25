// Platform/JPEGWriter.swift: JPEGWriting on the suite's one image adapter,
// SuiteImageIO, and the file system (export EX-5, EX-8, shared-codecs SC-8).
// `write` encodes the DisplayImage, opaque and sRGB-tagged, in the format its
// name's extension says (JPEG, PNG, TIFF or HEIC; JPEG and HEIC at
// quality/100, PNG and TIFF lossless at 8 bits) into memory, then writes the
// bytes with `.withoutOverwriting`, so a name that already exists throws
// `writeFailed` and its file is never touched. `writeSidecar` writes the XMP
// bytes the same way. `writableFormats` is the export formats SuiteImageIO on
// this Mac writes.
import CoreRaster
import Foundation
import LibraryModel
import SuiteModel
import SuiteShell

struct JPEGWriter: JPEGWriting {
    /// The export formats SuiteImageIO on this Mac writes, asked once (the sheet reads it per body).
    static func writableFormats() -> Set<ExportFormat> { writable }

    private static let writable: Set<ExportFormat> = {
        let formats = SuiteImageIO.writable
        return Set(ExportFormat.allCases.filter { format in
            SuiteImageFormat(fileName: "a." + format.fileExtension).map { formats.contains($0) } ?? false
        })
    }()

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
        guard let format = ExportFormat.forFileName(fileName) else {
            throw LibraryError.writeFailed(
                path: path, reason: "Library can only write JPEG, PNG, TIFF or HEIC files, not \(fileName).")
        }
        guard let data = Self.encode(image, as: format, quality: quality) else {
            throw LibraryError.writeFailed(path: path, reason: "Couldn't encode \(fileName) as \(format.rawValue).")
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

    /// `image` as `format` bytes tagged sRGB, every pixel opaque as before; a lossy format at `quality`
    /// (clamped to 0...100) / 100. Nil when it can't be encoded.
    private static func encode(_ image: DisplayImage, as format: ExportFormat, quality: Int) -> Data? {
        var bytes = image.rgba8
        for alpha in stride(from: 3, to: bytes.count, by: 4) { bytes[alpha] = 255 }
        guard let buffer = try? PixelBuffer(rgba8: bytes, width: image.size.width, height: image.size.height),
            let target = target(for: format, quality: Double(min(max(quality, 0), 100)) / 100)
        else { return nil }
        return try? SuiteImageIO.encode(buffer, as: target)
    }

    /// The adapter's Format for `format`. One branch per format, not a switch: two formats in one block are a
    /// list (FormatListRatchetTests).
    private static func target(for format: ExportFormat, quality: Double) -> SuiteImageIO.Format? {
        if format == .jpeg { return .jpeg(quality: quality) }
        if format == .png { return .png }
        if format == .tiff { return .tiff(bitDepth: 8) }
        if format == .heic { return .heic(quality: quality) }
        return nil
    }
}
