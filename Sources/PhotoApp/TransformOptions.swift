// TransformOptions.swift: the move and transform tool's own options in the
// inspector (transform PT-2): SuiteUI's TransformRows on the selected layer's
// box (the draft's while Free Transform is up), then Free Transform, or Apply
// over Cancel while a draft is up, each full width and SuiteSpacing.xs apart.
// The rows and flips send SuiteKernel's TransformIntent, run as catalog
// commands by the window; disabled, each says why (no pixel layer, or the
// transform service's help). Apply carries no Return shortcut and Cancel no
// Escape, so a field being typed in keeps its keys; Return and Escape on the
// canvas commit and cancel through `.confirm` and `.dismiss`. Values in,
// intents out. Mid-scrub the rows read the window's live transform
// (LiveTransformCopy+Kernel.swift) when there is one.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct TransformOptions: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    @Environment(\.photoLiveTransform) private var live

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            TransformRows(
                selection: (live?.shown ?? model).transformSelection, help: model.transformHelp, flipHelp: model.flipHelp
            ) {
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
