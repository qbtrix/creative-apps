// Platform/ImageIODecoder.swift: PhotoDecoding on the suite's one image
// adapter, SuiteImageIO, and the file system (import IM-4, shared-codecs
// SC-8). `scan` walks a folder, subfolders included, skipping hidden files
// and package contents, and reads each image-named file's metadata only
// (`SuiteImageIO.info`): its pixel size after the Exif orientation, its
// capture date (Exif DateTimeOriginal with its offset when present, else the
// file's creation date), and its Exif and TIFF dictionaries for the Model's
// `CameraDetails(exif:tiff:)` to read (metadata-more MD-7). A file the Mac
// can't read is a failure, never a throw.
// `decode` reads the file through `SuiteImageIO.decode`, upright and no
// bigger than asked, and hands it over as sRGB straight-alpha RGBA8.
import CoreRaster
import Foundation
import LibraryModel
import SuiteShell

struct ImageIODecoder: PhotoDecoding {
    func scan(folder: String) async throws -> FolderScan { try Self.walk(folder) }

    /// The scan itself, synchronous: a directory enumerator can't be iterated
    /// from an async context.
    private static func walk(_ folder: String) throws -> FolderScan {
        let root = URL(fileURLWithPath: folder)
        let manager = FileManager.default
        let name = root.lastPathComponent
        // The enumerator reports an unreadable root only through its error
        // handler, so list it once first: that throws when it can't be read.
        guard (try? manager.contentsOfDirectory(atPath: folder)) != nil else {
            throw LibraryError.unreadableFolder(name)
        }
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey]
        guard let entries = manager.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true })
        else { throw LibraryError.unreadableFolder(name) }
        var candidates: [ImportCandidate] = []
        var failures: [FileFailure] = []
        for case let url as URL in entries {
            guard let kind = PhotoFileKind.kind(forFileName: url.lastPathComponent),
                let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true
            else { continue }
            guard let info = try? SuiteImageIO.info(url) else {
                failures.append(FileFailure(path: url.path, reason: LibraryError.notAnImage(url.path).message))
                continue
            }
            let date = info.captureDate ?? values.creationDate ?? Date(timeIntervalSince1970: 0)
            // The tag reading lives in the Model, keyed by the tags' plain names.
            let camera = CameraDetails(exif: info.exif, tiff: info.tiff)
            candidates.append(ImportCandidate(
                path: url.path, captureDate: date, pixelSize: PixelSize(width: info.width, height: info.height),
                kind: kind, camera: camera))
        }
        return FolderScan(candidates: candidates, failures: failures)
    }

    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage {
        guard FileManager.default.fileExists(atPath: path) else { throw LibraryError.missingFile(path) }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            // SuiteImageIO never enlarges, so a limit past the long side is the full size.
            let buffer = try SuiteImageIO.decode(data, longestSide: maxLongSide.map { max($0, 1) })
            let size = PixelSize(width: buffer.width, height: buffer.height)
            if let image = DisplayImage(size: size, rgba8: try buffer.rgba8()) { return image }
        } catch {}
        throw LibraryError.notAnImage(path)
    }
}
