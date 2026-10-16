// SuiteError.swift: every suite failure and the one sentence the UI shows
// for it (docs/blueprints/suite.md, 5.4). Foundation free, Linux-safe,
// Sendable.

/// Every suite failure, each with the sentence the UI shows.
public enum SuiteError: Error, Equatable, Sendable {
    case appMissing(SuiteApp)
    case fileMissing(name: String)
    case unsupportedFile(name: String)
    case nothingToPaste
    case cannotPaste(app: SuiteApp, kind: String)
    case staleRevision
    case damaged(String)
    case notAvailable(String)
    case cancelled
    case timedOut
    case updateNotVerified
    case ioFailed(String)
    case noOtherReader(typeName: String)
    case originalMissing(name: String)
    case linkMissing
    case updatePostponed(SuiteApp)

    public var message: String {
        switch self {
        case .appMissing(let a): "\(a.displayName) is missing from AfterGlow. Reinstall AfterGlow to get it back."
        case .fileMissing(let n): "\(n) was moved or deleted."
        case .unsupportedFile(let n): "AfterGlow can't open \u{201C}\(n)\u{201D}. It isn't a suite document or an image."
        case .nothingToPaste: "Nothing to paste."
        case .cannotPaste(let a, let k): "\(a.displayName) can't paste \(k) yet."
        case .staleRevision: "Another app changed this at the same time. Try again."
        case .damaged(let d): "This file is damaged: \(d)."
        case .notAvailable(let r): r
        case .cancelled: "Cancelled."
        case .timedOut: "This took too long. Try again."
        case .updateNotVerified: "This update couldn't be verified, so it wasn't installed."
        case .ioFailed(let d): "Couldn't save: \(d)."
        case .noOtherReader(let t): "No other app opens \(t) files."
        case .originalMissing(let n): "The original of \(n) is missing. Locate it in Library first."
        case .linkMissing: "Linked asset is missing; using the last copy."
        case .updatePostponed(let a): "Update postponed: \(a.displayName) has unsaved changes."
        }
    }
}
