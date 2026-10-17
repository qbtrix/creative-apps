// FileStore.swift: the suite store's files (docs/blueprints/suite.md, 2.6).
// A revisioned file is the JSON envelope {"revision": n, "value": ...}; a
// missing file reads as (nil, 0). Every write happens under an exclusive
// flock on `<name>.lock` and lands by writing a temporary file and renaming
// it over the name, so a reader never sees a partial file. `readData` and
// `writeData` move raw bytes with no envelope (hand-off files). A name must
// stay inside the folder. `update` moves a damaged file aside to
// `<name>.damaged-<uuid>` and starts over from `empty`. Errors name what the
// file holds in plain words, never its path. Glibc on Linux, Darwin on
// macOS; nothing else platform-specific.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Revisioned JSON files and raw files in one support folder.
public struct FileStore: Sendable {
    /// The support folder every name is relative to.
    public let folder: String

    public init(folder: String) {
        self.folder = folder
    }

    /// The value in `name` and its revision; a missing file is (nil, 0).
    public func read<T: Codable & Sendable>(_ name: String, as: T.Type) throws(SuiteError) -> (value: T?, revision: Int) {
        guard let data = try readData(name) else { return (nil, 0) }
        guard let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: data),
              envelope.revision >= 0, envelope.revision < Int.max else { throw .damaged(Self.subject(name)) }
        return (envelope.value, envelope.revision)
    }

    /// Writes `value` as revision `revision + 1`, but only when the file is
    /// still at `revision`; otherwise throws `staleRevision` and leaves it.
    @discardableResult
    public func write<T: Codable & Sendable>(_ name: String, _ value: T, expecting revision: Int) throws(SuiteError) -> Int {
        try locked(name) { () throws(SuiteError) -> Int in
            let current = try read(name, as: T.self).revision
            guard current == revision else { throw .staleRevision }
            try replace(name, with: encode(Envelope(revision: revision + 1, value: value), name: name))
            return revision + 1
        }
    }

    /// Under the lock: reads, merges into the current value (or `empty`),
    /// writes the result as the next revision and returns it. A damaged
    /// file is moved aside and the merge starts from `empty` at revision 0.
    @discardableResult
    public func update<T: Codable & Sendable>(_ name: String, empty: T, merge: (T) -> T) throws(SuiteError) -> (value: T, revision: Int) {
        try locked(name) { () throws(SuiteError) -> (value: T, revision: Int) in
            let (old, revision) = try readOrMoveAside(name, as: T.self)
            let new = merge(old ?? empty)
            try replace(name, with: encode(Envelope(revision: revision + 1, value: new), name: name))
            return (new, revision + 1)
        }
    }

    /// The raw bytes of `name`, or nil when it doesn't exist.
    public func readData(_ name: String) throws(SuiteError) -> Data? {
        let path = try self.path(name)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        guard let data = FileManager.default.contents(atPath: path) else { throw .readFailed(Self.subject(name)) }
        return data
    }

    /// What `name` holds, in the words an error message shows the user.
    static func subject(_ name: String) -> String {
        switch name {
        case "recents.json": "your recent work list"
        case "preferences.json": "your suite settings"
        case "assets/index.json": "your shared assets list"
        default:
            if name.hasPrefix("handoffs/") { HandOffCodec.subject }
            else if name.hasPrefix("thumbnails/") { "a thumbnail" }
            else { "a suite file" }
        }
    }

    /// Replaces `name` with exactly `data`, atomically and under the lock.
    public func writeData(_ name: String, _ data: Data) throws(SuiteError) {
        try locked(name) { () throws(SuiteError) in try replace(name, with: data) }
    }

    // MARK: Files

    private struct Envelope<T: Codable>: Codable {
        var revision: Int
        var value: T
    }

    /// The full path of `name`; a name that is empty, absolute or has an
    /// empty, `.` or `..` component would leave the folder and is damaged.
    private func path(_ name: String) throws(SuiteError) -> String {
        let parts = name.split(separator: "/", omittingEmptySubsequences: false)
        guard !name.isEmpty, !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw .damaged(Self.subject(name))
        }
        return folder.hasSuffix("/") ? folder + name : folder + "/" + name
    }

    /// `read`, but a damaged file is renamed to `<name>.damaged-<uuid>` and
    /// reads as missing, so one bad file never blocks every later write.
    private func readOrMoveAside<T: Codable & Sendable>(_ name: String, as: T.Type) throws(SuiteError) -> (value: T?, revision: Int) {
        do {
            return try read(name, as: T.self)
        } catch .damaged {
            let target = try path(name)
            guard rename(target, target + ".damaged-\(UUID().uuidString)") == 0 else { throw .ioFailed(Self.subject(name)) }
            return (nil, 0)
        }
    }

    private func encode<T: Codable>(_ envelope: Envelope<T>, name: String) throws(SuiteError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do { return try encoder.encode(envelope) } catch { throw .ioFailed(Self.subject(name)) }
    }

    private func makeParent(of path: String, name: String) throws(SuiteError) {
        let url = URL(fileURLWithPath: path).deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw .ioFailed(Self.subject(name))
        }
    }

    /// Writes a temporary file beside `name`, flushes it to disk, then
    /// renames it over `name`, so a power cut never leaves an empty file.
    private func replace(_ name: String, with data: Data) throws(SuiteError) {
        let target = try path(name)
        let url = URL(fileURLWithPath: target)
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)").path
        do {
            try data.write(to: URL(fileURLWithPath: temp))
        } catch {
            try? FileManager.default.removeItem(atPath: temp)
            throw .ioFailed(Self.subject(name))
        }
        guard Self.flush(temp), rename(temp, target) == 0 else {
            try? FileManager.default.removeItem(atPath: temp)
            throw .ioFailed(Self.subject(name))
        }
    }

    /// fsyncs the file at `path`; false when it can't be opened or synced.
    private static func flush(_ path: String) -> Bool {
        let fd = open(path, O_RDONLY | O_CLOEXEC)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return fsync(fd) == 0
    }

    /// Runs `body` holding an exclusive flock on `<name>.lock`.
    private func locked<R>(_ name: String, _ body: () throws(SuiteError) -> R) throws(SuiteError) -> R {
        let lockPath = try path(name) + ".lock"
        try makeParent(of: lockPath, name: name)
        let fd = open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard fd >= 0 else { throw .ioFailed(Self.subject(name)) }
        defer { close(fd) }
        var status = flock(fd, LOCK_EX)
        while status != 0 && errno == EINTR { status = flock(fd, LOCK_EX) }
        guard status == 0 else { throw .ioFailed(Self.subject(name)) }
        defer { _ = flock(fd, LOCK_UN) }
        return try body()
    }
}
