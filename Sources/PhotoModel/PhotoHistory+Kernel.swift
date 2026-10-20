// PhotoHistory+Kernel.swift: Photo as SuiteKernel's HistoryJumping document
// (history-panel PH-1), so SuiteUI's HistoryPanel and the catalog's
// `history.read` and `history.jump` read and move Photo's history. The listing
// is the kernel's, based on PhotoHistory's "Open" or "New Image", with the
// saved step Photo keeps (`savedStepID`, nil for a restored autosave never
// saved) in place of the kernel's own, which Photo never sets. The jump is a
// stub until PH-5 writes its body. Linux-safe.
import SuiteKernel

extension PhotoWorkspace: HistoryJumping {
    /// The history as the History tab lists it: the base, every step oldest
    /// first, how many are applied and which count was last saved.
    public var historyListing: HistoryListing {
        var kernel = history.kernel
        kernel.savedStepID = savedStepID ?? Self.neverSavedToken
        return kernel.listing(base: history.baseName)
    }

    /// Undoes or redoes until `index` steps are applied, recording no step and
    /// ending the open run. A stub: history-panel PH-5 writes the body.
    public mutating func jumpHistory(to index: Int) throws {}
}
