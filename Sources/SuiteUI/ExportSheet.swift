// ExportSheet.swift: SuiteExportSheet (EK-30), drawn over ExportSheetRows, a
// readout of the kernel's ExportRun: Format, Size and (when the format takes
// one) Quality rows, a progress bar while running, the finished or failed line
// after. It holds no state; every edit goes to the host, which moves its run.
import SuiteKernel
import SwiftUI

/// One format the sheet offers, and whether it takes a quality.
public struct FormatChoice: Hashable, Sendable, Identifiable {
    public let id: String, name: String, hasQuality: Bool
    public init(id: String, name: String, hasQuality: Bool) { (self.id, self.name, self.hasQuality) = (id, name, hasQuality) }
}

/// Export options as the sheet reads them: format id, scale and quality 0...1.
public struct ExportPick: Hashable, Sendable {
    public var format: String, scale: Double, quality: Double
    public init(format: String, scale: Double = 1, quality: Double = 0.9) { (self.format, self.scale, self.quality) = (format, scale, quality) }
}

/// A running export's steps, done clamped to 0...total and total at least 1.
public struct ExportProgress: Hashable, Sendable {
    public let done: Int, total: Int
    public init(done: Int, total: Int) { (self.total, self.done) = (max(total, 1), min(max(done, 0), max(total, 1))) }
    public var text: String { "Exporting \(done) of \(total)" }
}

/// What the sheet shows for a run; only editing is `editable`.
public struct ExportSheetRows: Hashable, Sendable {
    public enum Row: Hashable, Sendable { case format(String), size(Double), quality(Double) }
    public enum Line: Hashable, Sendable { case finished(String), failed(String) }
    public let rows: [Row], editable: Bool, progress: ExportProgress?, line: Line?

    public init<Options: Hashable & Sendable>(_ run: ExportRun<Options>, formats: [FormatChoice], pick: (Options) -> ExportPick) {
        func shown(_ options: Options) -> [Row] {
            let p = pick(options)
            let quality = formats.first { $0.id == p.format }?.hasQuality ?? false
            return [.format(p.format), .size(p.scale)] + (quality ? [.quality(p.quality)] : [])
        }
        var progress: ExportProgress?, line: Line?, editable = false
        switch run {
        case .idle: rows = []
        case .editing(let o): rows = shown(o); editable = true
        case .running(let o, let done, let total): rows = shown(o); progress = ExportProgress(done: done, total: total)
        case .finished(let o, let files): rows = shown(o); line = .finished("Exported " + files.joined(separator: ", "))
        case .failed(let o, let error): rows = shown(o); line = .failed(error)
        }
        (self.progress, self.line, self.editable) = (progress, line, editable)
    }
}

public struct SuiteExportSheet: View {
    let readout: ExportSheetRows, formats: [FormatChoice]
    let onFormat: @MainActor (String) -> Void, onScale: @MainActor (Double) -> Void, onQuality: @MainActor (Double) -> Void
    let onExport: @MainActor () -> Void, onClose: @MainActor () -> Void

    public init(
        _ readout: ExportSheetRows, formats: [FormatChoice], onFormat: @escaping @MainActor (String) -> Void,
        onScale: @escaping @MainActor (Double) -> Void, onQuality: @escaping @MainActor (Double) -> Void,
        onExport: @escaping @MainActor () -> Void, onClose: @escaping @MainActor () -> Void
    ) {
        (self.readout, self.formats, self.onFormat) = (readout, formats, onFormat)
        (self.onScale, self.onQuality, self.onExport, self.onClose) = (onScale, onQuality, onExport, onClose)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text("Export").font(SuiteFont.title)
            VStack(spacing: SuiteSpacing.xs) { ForEach(Array(readout.rows.enumerated()), id: \.offset) { row($0.element) } }.disabled(!readout.editable)
            if let p = readout.progress { BusyNote(p.text, identifier: "suite.export.progress", fraction: (p.done, p.total)) }
            switch readout.line {
            case .finished(let text): Label(text, systemImage: "checkmark.circle").foregroundStyle(SuiteColor.stateSuccess)
            case .failed(let text): Label(text, systemImage: "exclamationmark.circle").foregroundStyle(SuiteColor.stateError)
            case nil: EmptyView()
            }
            HStack {
                Spacer()
                Button(readout.line == nil ? "Cancel" : "Done", action: onClose)
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier("suite.export.close")
                Button("Export", action: onExport)
                    .keyboardShortcut(.defaultAction).disabled(!readout.editable)
                    .help(readout.editable ? "Export with these settings" : "The export is already under way or done.")
                    .accessibilityIdentifier("suite.export.start")
            }
        }
        .padding(SuiteSpacing.xl).frame(width: SuiteSize.contentMinimum.width)
    }

    @ViewBuilder private func row(_ row: ExportSheetRows.Row) -> some View {
        switch row {
        case .format(let id):
            InspectorPickerRow(
                "Format", options: formats.map { InspectorOption(id: $0.id, title: $0.name) }, selection: id, onChange: onFormat)
        case .size(let scale): StudioScrubRow(label: "Size", value: scale, range: 0.25...4, step: 0.25, onChange: onScale)
        case .quality(let q): StudioScrubRow(label: "Quality", value: q, range: 0...1, step: 0.05, onChange: onQuality)
        }
    }
}
