// DesignSaveStatus.swift: the save state's two places in a Design window, both
// reading the Model's `saveStateText` ("Edited" with unsaved changes, "Saved"
// after a save or open, nothing with no file open): `subtitle(_:)`, the window
// subtitle under the title ("" with no file, so SuiteWindow shows none), and the
// view itself, the status line's `design.status.save`, drawn by SuiteUI's
// EditorSaveStatus (an accent dot while edited). A failed save shows its reason
// in the window's alert and leaves the state at "Edited". The window's edited
// dot waits on a SuiteUI window modifier (#2861), not a copy in this target.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignSaveStatus: View {
    let model: DesignWorkspace

    /// The window subtitle for `model`'s save state: "Edited", "Saved", or "" with no file open.
    static func subtitle(_ model: DesignWorkspace) -> String? { model.saveStateText ?? "" }

    var body: some View {
        if let title = model.saveStateText {
            EditorSaveStatus(
                model.isDirty ? .edited : .saved, title: title,
                help: model.isDirty
                    ? "This file has changes that aren't saved. Choose File > Save to keep them."
                    : "Every change to this file is saved.",
                identifier: DesignControlID.statusSave)
                .suiteControl(id: DesignControlID.statusSave, enabled: true, reason: nil)
        }
    }
}
