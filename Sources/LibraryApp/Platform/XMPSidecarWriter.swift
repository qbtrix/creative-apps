// Platform/XMPSidecarWriter.swift: SidecarWriting on the file system
// (metadata-more MD-17). `write` only ever writes the `.xmp` path it is
// given: a name that isn't `.xmp`, or is an image file, throws before any
// file is opened, and so does a sidecar already there that
// `XMPSidecar.isWrittenByLibrary` says another app wrote (its bytes stay as
// they were). The write lands atomically, as CatalogStore's does: Foundation
// writes an auxiliary file and renames it over the sidecar, so a reader never
// sees half a packet. No photo file is opened for writing. Foundation only.
import Foundation
import LibraryModel

struct XMPSidecarWriter: SidecarWriting {
    func read(sidecar path: String) async throws -> Data? {
        do {
            return try Self.contents(of: path)
        } catch {
            throw LibraryError.invalid("Library can't read \(Self.name(of: path)). Check that you have access to it.")
        }
    }

    func write(_ data: Data, sidecar path: String) async throws {
        let name = Self.name(of: path)
        guard name.lowercased().hasSuffix(".xmp"), PhotoFileKind.kind(forFileName: name) == nil else {
            throw LibraryError.writeFailed(path: path, reason: "\(name) isn't a sidecar file.")
        }
        let existing: Data?
        do {
            existing = try Self.contents(of: path)
        } catch {
            throw LibraryError.writeFailed(path: path, reason: "Library can't read \(name), so it left it unchanged.")
        }
        if let existing, !XMPSidecar.isWrittenByLibrary(existing) {
            throw LibraryError.writeFailed(
                path: path, reason: "\(name) was written by another app; Library left it unchanged.")
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            throw LibraryError.writeFailed(path: path, reason: Self.reason(for: error, name: name))
        }
    }

    /// The file's bytes; nil when there is no file at `path`. Reads rather
    /// than asking whether the file exists first, so there is no race.
    private static func contents(of path: String) throws -> Data? {
        do {
            return try Data(contentsOf: URL(fileURLWithPath: path))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    private static func name(of path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// The plain words for a failed write.
    private static func reason(for error: Error, name: String) -> String {
        switch (error as? CocoaError)?.code {
        case .fileWriteOutOfSpace?: "The disk is full."
        case .fileWriteNoPermission?, .fileWriteVolumeReadOnly?: "Library doesn't have permission to save \(name)."
        default: "Couldn't write \(name)."
        }
    }
}
