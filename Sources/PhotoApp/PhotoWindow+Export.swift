// PhotoWindow+Export.swift: the export area of a Photo window (PV-8): its
// intents, its route and its hook on the window. Export… opens the Export
// sheet when there is an image (`openSheet`), and `exportChosen` writes the
// sheet's choice through the file area's `write` without changing which file
// the window holds; `-PhotoExportTo <folder>` makes it write there directly.
// The sheet itself still sits on PhotoWindow's body. PhotoExportArea is the
// identity until PV-8 keeps its sheet and draft (`exportDraft`) inside it.
import AppKit
import PhotoModel
import SwiftUI
import UniformTypeIdentifiers

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

    func exportChosen() {
        isExporting = false
        let name = model.fileName(for: exportFormat)
        if let folder = UserDefaults.standard.string(forKey: "PhotoExportTo") {
            write(to: URL(fileURLWithPath: folder).appending(path: name), as: exportFormat, quality: exportQuality, saving: false)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [exportFormat == .png ? .png : .jpeg]
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url, as: exportFormat, quality: exportQuality, saving: false)
    }
}

/// The export area's state, sheets and dialogs over the window.
struct PhotoExportArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}
