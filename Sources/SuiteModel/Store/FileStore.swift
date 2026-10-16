// FileStore.swift: the suite store's files (docs/blueprints/suite.md, 2.6).
// A revisioned file is the JSON envelope {"revision": n, "value": ...}; a
// missing file reads as (nil, 0). Every write happens under an exclusive
// flock on `<name>.lock` and lands by writing a temporary file and renaming
// it over the name, so a reader never sees a partial file. `readData` and
// `writeData` move raw bytes with no envelope (hand-off files). Glibc on
// Linux, Darwin on macOS; nothing else platform-specific.
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
        do {
            let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
            return (envelope.value, envelope.revision)
        } catch {
            throw .damaged(name)
        }
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
    /// writes the result as the next revision and returns it.
    @discardableResult
    public func update<T: Codable & Sendable>(_ name: String, empty: T, merge: (T) -> T) throws(SuiteError) -> (value: T, revision: Int) {
        try locked(name) { () throws(SuiteError) -> (value: T, revision: Int) in
            let (old, revision) = try read(name, as: T.self)
            let new = merge(old ?? empty)
            try replace(name, with: encode(Envelope(revision: revision + 1, value: new), name: name))
            return (new, revision + 1)
        }
    }

    /// The raw bytes of `name`, or nil when it doesn't exist.
    public func readData(_ name: String) throws(SuiteError) -> Data? {
        let path = self.path(name)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        guard let data = FileManager.default.contents(atPath: path) else { throw .ioFailed(name) }
        return data
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

    private func path(_ name: String) -> String {
        folder.hasSuffix("/") ? folder + name : folder + "/" + name
    }

    private func encode<T: Codable>(_ envelope: Envelope<T>, name: String) throws(SuiteError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do { return try encoder.encode(envelope) } catch { throw .ioFailed(name) }
    }

    private func makeParent(of path: String) throws(SuiteError) {
        let url = URL(fileURLWithPath: path).deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw .ioFailed(url.path)
        }
    }

    /// Writes a temporary file beside `name`, then renames it over `name`.
    private func replace(_ name: String, with data: Data) throws(SuiteError) {
        let target = path(name)
        let url = URL(fileURLWithPath: target)
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)").path
        do {
            try data.write(to: URL(fileURLWithPath: temp))
        } catch {
            try? FileManager.default.removeItem(atPath: temp)
            throw .ioFailed(name)
        }
        guard rename(temp, target) == 0 else {
            try? FileManager.default.removeItem(atPath: temp)
            throw .ioFailed(name)
        }
    }

    /// Runs `body` holding an exclusive flock on `<name>.lock`.
    private func locked<R>(_ name: String, _ body: () throws(SuiteError) -> R) throws(SuiteError) -> R {
        let lockPath = path(name) + ".lock"
        try makeParent(of: lockPath)
        let fd = open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard fd >= 0 else { throw .ioFailed(name) }
        defer { close(fd) }
        var status = flock(fd, LOCK_EX)
        while status != 0 && errno == EINTR { status = flock(fd, LOCK_EX) }
        guard status == 0 else { throw .ioFailed(name) }
        defer { _ = flock(fd, LOCK_UN) }
        return try body()
    }
}
