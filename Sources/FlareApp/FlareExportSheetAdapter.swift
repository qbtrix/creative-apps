// FlareExportSheetAdapter.swift: Flare's export run on SuiteUI's export sheet.
// The sheet shows while the Model's run isn't idle (`exportingOptions`), with the kernel
// rows (`ExportSheetRows`) for Flare's three formats and the run's scale as the
// Size row; Flare has no quality. Every control sends a FlareIntent.Export:
// a format pick `setFormat`, Size `setScale`, Export `start`, and Cancel
// `cancel` while the run is under way, else Done or Escape `dismiss`. The
// frame, step and background rows, the warnings, the problem line, Try Again
// and Reveal in Finder wait on the sheet's options slot (#1989).
import FlareModel
import SuiteUI
import SwiftUI

struct FlareExportSheetAdapter: ViewModifier {
    let model: FlareWorkspace
    let perform: @MainActor (FlareIntent) -> Void

    /// The format menu: one choice per ExportFormat, its id the raw value.
    nonisolated static let formats = ExportFormat.allCases.map { FormatChoice(id: $0.rawValue, name: title($0), hasQuality: false) }

    /// A format's name in the menu.
    nonisolated static func title(_ format: ExportFormat) -> String {
        switch format {
        case .svgFrame: "SVG frame"
        case .lottie: "Lottie"
        case .pngSequence: "PNG sequence"
        }
    }

    private var running: Bool {
        if case .running = model.exportState { true } else { false }
    }

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { model.exportingOptions != nil }, set: { if !$0 { close() } })) {
            SuiteExportSheet(
                ExportSheetRows(model.exportState, formats: Self.formats) { ExportPick(format: $0.format.rawValue, scale: $0.scale) },
                formats: Self.formats,
                onFormat: { id in if let format = ExportFormat(rawValue: id) { perform(.export(.setFormat(format))) } },
                onScale: { perform(.export(.setScale($0))) },
                onQuality: { _ in },
                onExport: { perform(.export(.start)) },
                onClose: close)
        }
    }

    /// Cancel stops a run under way; otherwise the sheet closes.
    @MainActor private func close() {
        perform(.export(running ? .cancel : .dismiss))
    }
}
