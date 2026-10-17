// DesignSaveStatus.swift: the save state's two places in a Design window, empty
// until files-history fills them: `subtitle(_:)`, the window subtitle under the
// title (nil for now, so SuiteWindow shows none), and the view itself, the
// status line's `design.status.save` label, which draws nothing yet. The slot
// exists so the feature that fills it edits only this file.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignSaveStatus: View {
    let model: DesignWorkspace

    /// The window subtitle for `model`'s save state; nil until Design tracks unsaved changes.
    static func subtitle(_ model: DesignWorkspace) -> String? { nil }

    var body: some View {
        EmptyView()
            .accessibilityIdentifier(DesignControlID.statusSave)
    }
}
