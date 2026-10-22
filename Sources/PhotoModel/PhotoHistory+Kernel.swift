// PhotoHistory+Kernel.swift: Photo as SuiteKernel's HistoryJumping document
// (history-panel PH-1), so SuiteUI's HistoryPanel and the catalog's
// `history.read` and `history.jump` read and move Photo's history. The listing
// is the kernel's, based on PhotoHistory's "Open" or "New Image", with the
// saved step Photo keeps (`savedStepID`, nil for a restored autosave never
// saved) in place of the kernel's own, which Photo never sets. The jump
// (PH-5) ends the open run (a slider drag in progress), then moves through
// the kernel's History.jump, applying each step's PhotoEdit in order: a jump
// of ten swaps ten steps' tiles or stacks, never a replay from "Open", and
// records no step. Mid-stroke it is ignored, as Undo is. Linux-safe.
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
    /// ending the open run, even when the image is already there.
    public mutating func jumpHistory(to index: Int) throws {
        endAdjust()
        jumpToHistoryStep(index)
    }
}
