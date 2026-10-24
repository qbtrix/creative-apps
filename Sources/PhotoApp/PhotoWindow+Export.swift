// PhotoWindow+Export.swift: the export area of a Photo window (PV-8): its
// intents, its route and its hook on the window. Export… opens the Export
// sheet when there is an image (`openSheet`), and `exportChosen` starts the
// model's export run (`PhotoWorkspace.exportRun`) and writes the sheet's choice
// through the file area's `write`, which ends the run, without changing which
// file the window holds; `-PhotoExportTo <folder>` makes it write there directly.
// The sheet itself still sits on PhotoWindow's body. PhotoExportArea is the
// identity until PV-8 keeps its sheet and draft (`exportDraft`) inside it.
// PhotoExportSheetAdapter (export-pack PX-2) is SuiteUI's export sheet on the
// workspace's run, its ids under `photo.export`: Format chips for the formats
// the app writes today and Quality for JPEG, each pick the open run's choice
// (`editExport`). Its Size row stays off until the app's write resizes (PX-4).
import AppKit
import PhotoModel
import SuiteKernel
import SuiteUI
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
        case .openSheet: model.openExport()
        }
    }

    func exportChosen() {
        // The sheet's command with its choices; it starts the one write only while the sheet is open.
        guard let choice = model.exportChoice else { return }
        let (exportFormat, exportQuality) = (choice.format, choice.quality)
        let params: [String: JSONValue] = ["format": .string(exportFormat.rawValue), "quality": .number(exportQuality)]
        guard run("file.export", params, failing: "The image can't be exported."), model.isExportRunning else { return }
        let name = model.fileName(for: exportFormat)
        if let folder = UserDefaults.standard.string(forKey: "PhotoExportTo") {
            write(to: URL(fileURLWithPath: folder).appending(path: name), as: exportFormat, quality: exportQuality, saving: false)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [exportFormat == .png ? .png : .jpeg]
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return model.endExport(.failure(CancellationError())) }
        write(to: url, as: exportFormat, quality: exportQuality, saving: false)
    }
}

/// The export area's state, sheets and dialogs over the window.
struct PhotoExportArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View { content }
}

/// The Export sheet: SuiteExportSheet on the workspace's run; every pick goes to `onPick` as the run's new choice.
struct PhotoExportSheetAdapter: View {
    let model: PhotoWorkspace
    var onPick: @MainActor (ExportOptions) -> Void = { _ in }
    var onExport: @MainActor () -> Void = {}
    var onClose: @MainActor () -> Void = {}

    /// The suite's still formats the app writes today, in the suite's order (HEIC and TIFF come with PX-4).
    nonisolated static let formats = PhotoWorkspace.exportFormats.compactMap { spec in
        ImageFormat(rawValue: spec.id).map { _ in FormatChoice(id: spec.id, name: spec.name, hasQuality: spec.hasQuality) }
    }

    var body: some View {
        SuiteExportSheet(
            ExportSheetRows(model.exportRun, formats: Self.formats, showsSize: false) {
                ExportPick(format: $0.format.rawValue, quality: $0.quality)
            },
            formats: Self.formats,
            idPrefix: "photo.export",
            onFormat: { id in pick { $0.format = ImageFormat(rawValue: id) ?? $0.format } },
            onScale: { _ in },
            onQuality: { q in pick { $0.quality = q } },
            onExport: onExport,
            onClose: onClose
        ) {
            let format = model.exportChoice?.format ?? .png
            InspectorNote(
                format == .png ? "PNG keeps transparent pixels." : "JPEG has no transparency: transparent pixels export white.",
                identifier: "photo.export.note")
        }
    }

    /// The open run's choice with `change` made, sent to `onPick`.
    private func pick(_ change: (inout ExportOptions) -> Void) {
        guard var choice = model.exportChoice else { return }
        change(&choice)
        onPick(choice)
    }
}
