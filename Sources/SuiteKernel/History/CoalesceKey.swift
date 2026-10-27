// CoalesceKey.swift: the one key a run of edits records under in `History`, so
// one drag is one undo step the same way in every app, the CLI and the MCP
// server. A key is the property, the target ids (in any order) and the drag
// token; a gesture mints its token on its first sample and keeps it until it
// ends. Every `+Kernel` adapter and `Nudge.runKey` build their keys here.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The history key a run of edits folds under, and the drag token a gesture carries.
public enum CoalesceKey {
    /// The key for edits to `property` on `targets` under drag `token`: the same
    /// property on the same targets under the same token folds into one step;
    /// any other property, target set or token starts a new one. Target order
    /// doesn't matter. With no token the run lasts until the history's `endRun()`.
    public static func key(_ property: String, on targets: [String] = [], drag token: String? = nil) -> String {
        let run = property + "\u{1E}" + targets.sorted().joined(separator: "\u{1F}")
        return token.map { run + "\u{1E}" + $0 } ?? run
    }

    /// The open gesture's token, or a fresh one on its first sample.
    public static func token(_ open: String?) -> String {
        open ?? UUID().uuidString
    }
}
