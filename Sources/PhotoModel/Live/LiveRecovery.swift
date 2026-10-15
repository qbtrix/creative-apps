// Live/LiveRecovery.swift: the live recovery store (D-4b of photo-documents,
// review note 1). One `<window>.ora` per window in a folder, the OpenRaster
// file PhotoZip writes, with `photo/recovery.json` added inside it for the
// document's name and the time it was saved (the file's date is set from that
// time too, but the entry is what leftBehind reads). Every write is atomic, so
// a crash mid-write leaves the last good file. A file that doesn't open is
// removed and skipped (review note 3). The window string is percent-encoded
// into the file name, so no window escapes the folder. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct LiveRecovery: RecoveryStoring {
    static let infoPath = "photo/recovery.json"
    static let fileExtension = "ora"

    let directory: URL

    var unavailableHelp: String? { nil }

    /// ~/Library/Application Support/Photo/Recovery, from FileManager's
    /// application-support folder when it has one, else the home folder's.
    static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return support.appendingPathComponent("Photo", isDirectory: true)
            .appendingPathComponent("Recovery", isDirectory: true)
    }

    func write(_ entry: RecoveryEntry, window: String) throws {
        var files = entry.package.files
        files[Self.infoPath] = try JSONEncoder().encode(Info(documentName: entry.documentName, savedAt: entry.savedAt))
        let data = try PhotoZip.container(PhotoPackage(files: files))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = file(for: window)
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: entry.savedAt)], ofItemAtPath: url.path)
    }

    func leftBehind() throws -> [RecoveryEntry] {
        var entries: [(name: String, entry: RecoveryEntry)] = []
        for name in try recoveryFiles() {
            let url = directory.appendingPathComponent(name)
            guard let entry = try? Self.entry(at: url) else {
                try? FileManager.default.removeItem(at: url)
                continue
            }
            entries.append((name, entry))
        }
        return entries.sorted { $0.entry.savedAt != $1.entry.savedAt ? $0.entry.savedAt > $1.entry.savedAt : $0.name < $1.name }
            .map(\.entry)
    }

    func discard(window: String) throws {
        let url = file(for: window)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func discardAll() throws {
        for name in try recoveryFiles() {
            try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    // MARK: Files

    /// The window's file: every byte outside A-Z, a-z, 0-9, "-" and "_" as
    /// %XX, so "/" and "." never reach the path and two windows never share one.
    func file(for window: String) -> URL {
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
        if name.isEmpty { name = "%" }
        return directory.appendingPathComponent("\(name).\(Self.fileExtension)", isDirectory: false)
    }

    /// The names of the folder's .ora files; none when the folder is missing.
    private func recoveryFiles() throws -> [String] {
        // macOS Foundation takes an ObjCBool here and Linux Foundation a Bool (Linux has no ObjCBool).
        #if canImport(Darwin)
        var isFolder: ObjCBool = false
        let found = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isFolder) && isFolder.boolValue
        #else
        var isFolder = false
        let found = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isFolder) && isFolder
        #endif
        guard found else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".\(Self.fileExtension)") }
    }

    /// The entry in the file at `url`; its info entry is taken out of the package.
    private static func entry(at url: URL) throws -> RecoveryEntry {
        var package = try PhotoZip.package(fromContainer: try Data(contentsOf: url))
        let info = try package.files[infoPath].map { try JSONDecoder().decode(Info.self, from: $0) }
        package.files[infoPath] = nil
        let savedAt = try info?.savedAt
            ?? ((FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)?
                .timeIntervalSince1970 ?? 0)
        return RecoveryEntry(documentName: info?.documentName, savedAt: savedAt, package: package)
    }

    /// photo/recovery.json.
    private struct Info: Codable {
        var documentName: String?
        var savedAt: Double
    }
}
