// BackupRotation.swift (catalog-backup BK-1 stubs, BK-3 bodies): rolling backups of one support file over the
// suite store's atomic `FileStore`. A backup is a copy of `file` under "Backups/" beside it; at most one an hour
// unless forced (quit); `prune` keeps the newest `keepLast` plus the newest of each of the last `keepDays` days and
// never deletes the newest copy; `restore` backs up the current file first, so a restore is never a loss.
// A copy is named `<whole seconds since 1970>-<file>`, so its date reads back from its name. Days are the 24-hour
// spans back from `now`, so pruning never depends on the time zone. Time is always passed in. Linux-safe.
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

/// One backup copy: its file name under "Backups/", when it was made, and its size in bytes.
public struct BackupEntry: Hashable, Sendable {
    public var name: String, date: Date, bytes: Int
    public init(name: String, date: Date, bytes: Int) {
        (self.name, self.date, self.bytes) = (name, date, bytes)
    }
}

/// The rolling backups of `file` in `store`'s folder.
public struct BackupRotation: Sendable {
    /// The store the file and its backups live in, and the file's name in it ("catalog.json").
    public let store: FileStore, file: String
    /// How many newest copies are always kept, and for how many days the newest copy of each day is kept.
    public let keepLast: Int, keepDays: Int

    public init(store: FileStore, file: String, keepLast: Int = 10, keepDays: Int = 7) {
        (self.store, self.file) = (store, file)
        (self.keepLast, self.keepDays) = (max(1, keepLast), max(0, keepDays))
    }

    /// Why the Library backup commands can't act yet, in the words the user sees. BK-5m removes it.
    public static let unavailable = "Backups arrive with BK-3."

    /// True when an hour has passed since the newest backup, there is none, or the clock went back past it.
    public func shouldBackUp(now: Date) -> Bool {
        guard let newest = list().first else { return true }
        return now.timeIntervalSince(newest.date) >= Self.hour || now < newest.date
    }

    /// Copies the file to "Backups/" when `force` or `shouldBackUp(now:)`, then returns the new copy; nil when
    /// nothing was copied (too soon, or no file yet).
    @discardableResult
    public func backUp(now: Date, force: Bool) throws(SuiteError) -> BackupEntry? {
        guard force || shouldBackUp(now: now), let data = try store.readData(file) else { return nil }
        let seconds = Int(now.timeIntervalSince1970.rounded(.down))
        let name = "\(seconds)-\(file)"
        try store.writeData(Self.folder + name, data)
        return BackupEntry(name: name, date: Date(timeIntervalSince1970: Double(seconds)), bytes: data.count)
    }

    /// Every backup of the file, newest first.
    public func list() -> [BackupEntry] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: path(Self.folder))) ?? []
        let entries = names.compactMap { name -> BackupEntry? in
            guard let date = date(of: name), let bytes = size(path(Self.folder + name)) else { return nil }
            return BackupEntry(name: name, date: date, bytes: bytes)
        }
        return entries.sorted { $0.date != $1.date ? $0.date > $1.date : $0.name > $1.name }
    }

    /// Deletes the backups outside the newest `keepLast` and the newest of each of the last `keepDays` days;
    /// the newest backup is always kept.
    public func prune(now: Date) throws(SuiteError) {
        let entries = list()
        var keep = Set(entries.prefix(keepLast).map(\.name))
        var days = Set<Int>()
        for entry in entries {
            let day = max(0, Int((now.timeIntervalSince(entry.date) / Self.day).rounded(.down)))
            if day < keepDays, days.insert(day).inserted { keep.insert(entry.name) }
        }
        for entry in entries where !keep.contains(entry.name) {
            try remove(path(Self.folder + entry.name))
            try remove(path(Self.folder + entry.name) + ".lock")
        }
    }

    /// Backs up the current file, then replaces it with the backup `name`; an unknown name throws `fileMissing`
    /// and changes nothing.
    public func restore(_ name: String, now: Date) throws(SuiteError) {
        guard date(of: name) != nil, let data = try store.readData(Self.folder + name) else {
            throw .fileMissing(name: name)
        }
        try backUp(now: now, force: true)
        try store.writeData(file, data)
    }

    // MARK: Files

    static let folder = "Backups/", hour: Double = 60 * 60, day: Double = 24 * 60 * 60
    /// What an error about these files names, in the words the user sees.
    static let subject = "a backup"

    private func path(_ name: String) -> String { store.folder.hasSuffix("/") ? store.folder + name : store.folder + "/" + name }

    /// The date in a backup's name, `<seconds>-<file>`; nil for a lock, a temporary file or anything else.
    private func date(of name: String) -> Date? {
        let suffix = "-" + file
        guard !name.contains("/"), name.hasSuffix(suffix), let seconds = Int(name.dropLast(suffix.count)) else { return nil }
        return Date(timeIntervalSince1970: Double(seconds))
    }

    /// The size in bytes of the regular file at `path`; nil when it isn't one.
    private func size(_ path: String) -> Int? {
        var info = stat()
        guard stat(path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return Int(info.st_size)
    }

    /// Deletes the file at `path`; a missing one is fine.
    private func remove(_ path: String) throws(SuiteError) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        guard (try? FileManager.default.removeItem(atPath: path)) != nil else { throw .ioFailed(Self.subject) }
    }
}
