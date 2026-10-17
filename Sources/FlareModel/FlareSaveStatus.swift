// FlareSaveStatus.swift: the window's save status (docs/blueprints/flare/features/layers-files.md, LF-5).
// "Not saved" while the last save failed (`saveFailed` set `saveError`), nil once a save succeeds (`didSave`)
// or another document lands; the window shows it in the error color beside the failed save's alert.
extension FlareWorkspace {
    /// "Not saved" after a failed save; nil when no save has failed since the last one that succeeded.
    public var saveStatus: String? {
        saveError == nil ? nil : "Not saved"
    }
}
