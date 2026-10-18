// DesignSaveStatus.swift: the save state's two places in a Design window, both
// reading the Model's `saveStateText` ("Edited" with unsaved changes, "Saved"
// after a save or open, nothing with no file open): `subtitle(_:)`, the window
// subtitle under the title ("" with no file, so SuiteWindow shows none), and the
// view itself, the status line's `design.status.save` label, plain text until
// the styled save status (EditorSaveStatus, #339) lands in SuiteUI. The window's
// edited dot waits on a SuiteUI window modifier (#2861), not a copy in this target.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignSaveStatus: View {
    let model: DesignWorkspace

    /// The window subtitle for `model`'s save state: "Edited", "Saved", or "" with no file open.
    static func subtitle(_ model: DesignWorkspace) -> String? { model.saveStateText ?? "" }

    var body: some View {
        if let state = model.saveStateText {
            Text(state)
                .suiteControl(id: DesignControlID.statusSave, enabled: true, reason: nil)
        }
    }
}
