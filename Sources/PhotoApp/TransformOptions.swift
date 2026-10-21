// TransformOptions.swift: the move and transform tool's own options in the
// inspector (transform PT-2): SuiteUI's TransformRows on the selected layer's
// box (the draft's while Free Transform is up), then Free Transform, or Apply
// over Cancel while a draft is up, each full width and SuiteSpacing.xs apart.
// The rows and flips send SuiteKernel's TransformIntent, run as catalog
// commands by the window; disabled, each says why (no pixel layer, or the
// transform service's help). Apply carries no Return shortcut and Cancel no
// Escape, so a field being typed in keeps its keys; Return and Escape on the
// canvas commit and cancel through `.confirm` and `.dismiss`. While a scrub or
// drag lasts the rows show the window's LiveDraftBox's box (#4247), read here
// only. Values in, intents out.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct TransformOptions: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    /// The window's live Free Transform copy (LiveDraftBox.swift); its box wins while one is live.
    @Environment(\.photoDraftBox) private var draftBox

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            TransformRows(selection: draftBox?.selection ?? model.transformSelection, help: model.transformHelp, flipHelp: model.flipHelp) {
                perform(.transform(.kernel($0)))
            }
            if model.transformDraft == nil {
                InspectorAction(ToolbarAction(
                    "Free Transform", systemImage: "arrow.up.left.and.arrow.down.right",
                    unavailableHelp: model.transformHelp, identifier: "photo.transform.begin"
                ) { perform(.transform(.begin)) })
            } else {
                InspectorAction(ToolbarAction(
                    "Apply Transform", systemImage: "checkmark", unavailableHelp: model.transformHelp,
                    identifier: "photo.transform.commit"
                ) { perform(.transform(.commit)) })
                InspectorAction(ToolbarAction(
                    "Cancel", systemImage: "xmark", identifier: "photo.transform.cancel"
                ) { perform(.transform(.cancel)) })
            }
        }
    }
}
