// RecoveryRestore.swift (#4015): how a Restore from the recovery alert ended. A copy that opened is the window's
// document now, so the next save deletes its file; one that threw stays on disk for the next launch, and the
// window says why instead of showing an empty document.

/// The end of a Restore: what happens to the copy's file and what the window shows.
public enum RecoveryRestore: Hashable, Sendable {
    /// The window holds the copy's document; the next save deletes the copy.
    case restored
    /// The copy didn't open; it stays on disk and `message` says why.
    case failed(message: String)

    /// The outcome for `name`'s copy: restored when `failure` is nil, else failed, naming the document and the
    /// reason (`failure`, which may be empty).
    public init(name: String, failure: String?) {
        guard let failure else {
            self = .restored
            return
        }
        let reason = failure.isEmpty ? "" : " \(failure)"
        self = .failed(message: "\u{201C}\(name)\u{201D} couldn\u{2019}t be restored.\(reason) Its autosaved copy is kept.")
    }

    /// Whether the window's next save deletes the copy's file.
    public var deletesCopyOnSave: Bool { self == .restored }

    /// What the window shows; nil when the restore worked.
    public var message: String? {
        if case .failed(let message) = self { message } else { nil }
    }
}
