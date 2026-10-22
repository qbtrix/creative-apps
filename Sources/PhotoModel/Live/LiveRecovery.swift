// Live/LiveRecovery.swift: the live recovery store (D-4b of photo-documents,
// review note 1; history-panel PH-6). Through SuiteModel's RecoveryFolder:
// per window `Recovery/<window>.ora`, the OpenRaster file PhotoZip writes with
// `photo/recovery.json` (name, time) inside, and the folder's `<window>.json`.
// Writes are atomic; a copy that doesn't open is removed and skipped (review
// note 3); the window is percent-encoded, so none escapes the folder. The
// folder's times count from the reference date, an entry's from 1970. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

struct LiveRecovery: RecoveryStoring {
    static let infoPath = "photo/recovery.json"
    static let fileExtension = "ora"

    /// The store's folder; the copies are under "Recovery/" in it.
    let directory: URL

    var unavailableHelp: String? { nil }

    /// The copies, as the window's autosave writes and offers them.
    var folder: RecoveryFolder { RecoveryFolder(store: FileStore(folder: directory.path), ext: Self.fileExtension) }

    /// ~/Library/Application Support/Photo (the copies in its Recovery
    /// folder), from FileManager's application-support folder when it has
    /// one, else the home folder's.
    static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return support.appendingPathComponent("Photo", isDirectory: true)
    }

    func write(_ entry: RecoveryEntry, window: String) throws {
        let data = try Self.container(entry.package, info: Info(documentName: entry.documentName, savedAt: entry.savedAt))
        try folder.write(data, window: Self.encoded(window), name: entry.documentName,
                         at: entry.savedAt - Date.timeIntervalBetween1970AndReferenceDate)
    }

    func leftBehind() throws -> [RecoveryEntry] {
        var entries: [RecoveryEntry] = []
        for item in try folder.leftBehind() {
            guard case let (package, info)? = try? Self.unpack(item.data, archive: LiveArchive()) else {
                try folder.discard(window: item.window)
                continue
            }
            entries.append(RecoveryEntry(
                documentName: info?.documentName ?? item.name,
                savedAt: info?.savedAt ?? item.savedAt + Date.timeIntervalBetween1970AndReferenceDate,
                package: package))
        }
        return entries
    }

    func discard(window: String) throws {
        try folder.discard(window: Self.encoded(window))
    }

    func discardAll() throws { try folder.discardAll() }

    // MARK: Bytes

    /// What `photo/recovery.json` holds: the name, and the time when the
    /// store wrote it (an autosave's bytes leave it to the folder's file).
    struct Info: Codable {
        var documentName: String?
        var savedAt: Double?
    }

    /// `package` with `info` added inside, as one container through `archive`.
    static func container(_ package: PhotoPackage, info: Info, archive: any DocumentArchiving = LiveArchive()) throws -> Data {
        var files = package.files
        files[infoPath] = try JSONEncoder().encode(info)
        return try archive.container(PhotoPackage(files: files))
    }

    /// The package in `data` and the info taken out of it, nil when it has none.
    static func unpack(_ data: Data, archive: any DocumentArchiving) throws -> (PhotoPackage, Info?) {
        var package = try archive.package(fromContainer: data)
        let info = try package.files[infoPath].map { try JSONDecoder().decode(Info.self, from: $0) }
        package.files[infoPath] = nil
        return (package, info)
    }

    // MARK: Files

    /// The window's raw copy, `<window>.ora` under "Recovery/".
    func file(for window: String) -> URL {
        directory.appendingPathComponent("Recovery", isDirectory: true)
            .appendingPathComponent("\(Self.encoded(window)).\(Self.fileExtension)", isDirectory: false)
    }

    /// The window as a file name: every byte outside A-Z, a-z, 0-9, "-" and
    /// "_" as %XX, so "/" and "." never reach the path and two windows never
    /// share one.
    static func encoded(_ window: String) -> String {
        var name = ""
        for byte in window.utf8 {
            let safe = (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A)
                || (byte >= 0x61 && byte <= 0x7A) || byte == 0x2D || byte == 0x5F
            if safe {
                name.unicodeScalars.append(Unicode.Scalar(byte))
            } else {
                let hex = String(byte, radix: 16, uppercase: true)
                name += "%" + (hex.count < 2 ? "0" : "") + hex
            }
        }
        return name.isEmpty ? "%" : name
    }
}
