// BackupRotation.swift (catalog-backup BK-1 stubs, BK-3 bodies): rolling backups of one support file over the
// suite store's atomic `FileStore`. A backup is a copy of `file` under "Backups/" beside it; at most one an hour
// unless forced (quit); `prune` keeps the newest `keepLast` plus the newest of each of the last `keepDays` days and
// never deletes the newest copy; `restore` backs up the current file first, so a restore is never a loss.
// BK-1: the shape only. Nothing is copied, `list` is empty and `restore` refuses with `unavailable`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
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

    /// Why the rotation can't act yet, in the words the user sees. BK-3 removes it.
    public static let unavailable = "Backups arrive with BK-3."

    /// True when an hour has passed since the newest backup, or there is none. BK-1: never.
    public func shouldBackUp(now: Date) -> Bool { false }

    /// Copies the file to "Backups/" when `force` or `shouldBackUp(now:)`, then returns the new copy; nil when
    /// nothing was copied (too soon, or no file yet). BK-1: copies nothing.
    @discardableResult
    public func backUp(now: Date, force: Bool) throws(SuiteError) -> BackupEntry? { nil }

    /// Every backup of the file, newest first. BK-1: none.
    public func list() -> [BackupEntry] { [] }

    /// Deletes the backups outside the newest `keepLast` and the newest of each of the last `keepDays` days.
    /// BK-1: deletes nothing.
    public func prune(now: Date) throws(SuiteError) {}

    /// Backs up the current file, then replaces it with the backup `name`; an unknown name throws `fileMissing`.
    /// BK-1: refuses with `unavailable`.
    public func restore(_ name: String, now: Date) throws(SuiteError) {
        throw .notAvailable(Self.unavailable)
    }
}
