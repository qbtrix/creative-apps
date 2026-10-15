// PhotoWindow+Export.swift: the export area of a Photo window (PV-8): its
// intents, its route and its hook on the window. Export… opens the Export
// sheet when there is an image (`openSheet`); the sheet itself and the write
// still live in PhotoWindow until they move here. PhotoExportArea is the
// identity until PV-8 keeps its sheet and draft (`exportDraft`) inside it.
import PhotoModel
import SwiftUI

/// What the export area can be asked to do.
enum ExportIntent {
    /// Export…: opens the Export sheet, with an image only.
    case openSheet
}

extension PhotoWindow {
    func performExport(_ intent: ExportIntent) {
        switch intent {
        case .openSheet: isExporting = model.canvas != nil
        }
    }
}

/// The export area's state, sheets and dialogs over the window.
struct PhotoExportArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}
