// PhotoRecentMenu.swift: what File > Open Recent shows and where a pick goes
// (photo-documents, PJ-1/PJ-2). With a focused window its own list shows and
// a pick opens in that window; with none (the last window closed) the list
// saved for the next launch shows and a pick goes to the open queue, which
// opens it in a new window. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// File > Open Recent's files and where picking one, or Clear Menu, acts.
public struct PhotoRecentMenu: Sendable, Equatable {
    /// Where the menu's picks and Clear Menu act.
    public enum Target: Sendable, Equatable {
        /// The focused window opens the file and clears its list.
        case focusedWindow
        /// No window: the file opens in a new window; Clear Menu clears the saved list.
        case noWindow
    }

    /// The files, newest first.
    public let files: [URL]
    public let target: Target

    /// The focused window's list when a window publishes one, else `stored`.
    public init(focused: [URL]?, stored: [URL]) {
        if let focused {
            files = focused
            target = .focusedWindow
        } else {
            files = stored
            target = .noWindow
        }
    }

    /// Clear Menu runs only with files to clear.
    public var canClear: Bool { !files.isEmpty }
}
