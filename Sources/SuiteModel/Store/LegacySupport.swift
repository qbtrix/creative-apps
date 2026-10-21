// LegacySupport.swift: what to do with one file an earlier build left outside
// the suite root (adopt-kernel-autosave AK-2). The plan never
// overwrites and never deletes: a file at the new place always wins and the
// old one is left for the person. The caller does the move. Pure, Linux-safe.

/// The move-once rule for files from an earlier build's support folder.
public enum LegacySupport {
    /// One old file's fate: move it, keep both untouched, or nothing to do.
    public enum Step: Hashable, Sendable { case move(from: String, to: String), keepBoth(old: String), nothing }

    /// What to do with one old file: move it when the new place is empty; when both exist, keep both and touch
    /// neither (the newer place wins, the old file is left for the person); nothing when there is no old file.
    public static func plan(old: String, new: String, exists: (String) -> Bool) -> Step {
        guard exists(old) else { return .nothing }
        if exists(new) { return .keepBoth(old: old) }
        return .move(from: old, to: new)
    }
}
