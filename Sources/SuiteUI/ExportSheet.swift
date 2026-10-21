// ExportSheet.swift: SuiteExportSheet (EK-30), drawn over ExportSheetRows, a
// readout of the kernel's ExportRun: Format chips, Size (unless the host draws
// its own scale) and (when the format takes one) Quality rows, 8 pt apart, then the host's own options rows (the slot, #1989),
// a progress bar while running, the finished or failed line after, and the
// actions that state offers (ExportSheetAction). Every control's identifier
// hangs off the host's prefix (ExportSheetIDs, "suite.export" by default) and
// registers in `suite.controls`. It holds no state; every edit goes to the
// host, which moves its run.
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

    /// The actions this state offers, in drawing order: Try Again on a failed run and Reveal on a finished one
    /// when the host handles them, the close button (Cancel until a line shows, then Done), and Export.
    public func actions(canTryAgain: Bool, canReveal: Bool) -> [ExportSheetAction] {
        var shown: [ExportSheetAction] = []
        if case .failed = line, canTryAgain { shown.append(.tryAgain) }
        if case .finished = line, canReveal { shown.append(.reveal) }
        return shown + [line == nil ? .cancel : .dismiss, .start]
    }

    /// `showsSize: false` leaves out the Size row, for a host that draws its own scale control.
    public init<Options: Hashable & Sendable>(
        _ run: ExportRun<Options>, formats: [FormatChoice], showsSize: Bool = true, pick: (Options) -> ExportPick
    ) {
        func shown(_ options: Options) -> [Row] {
            let p = pick(options)
            let quality = formats.first { $0.id == p.format }?.hasQuality ?? false
            return [.format(p.format)] + (showsSize ? [.size(p.scale)] : []) + (quality ? [.quality(p.quality)] : [])
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

/// A button the sheet may show.
public enum ExportSheetAction: String, CaseIterable, Hashable, Sendable {
    case tryAgain, reveal, cancel, dismiss, start
}

/// The sheet's control identifiers under one prefix: `<prefix>.format.<format id>`, `<prefix>.<action>`.
public struct ExportSheetIDs: Hashable, Sendable {
    public let prefix: String
    public init(_ prefix: String = "suite.export") { self.prefix = prefix }
    public var formats: String { prefix + ".format" }
    public var progress: String { prefix + ".progress" }
    public var start: String { id(.start) }
    public func format(_ id: String) -> String { "\(formats).\(id)" }
    public func id(_ action: ExportSheetAction) -> String { "\(prefix).\(action.rawValue)" }
}

public struct SuiteExportSheet<Options: View>: View {
    let readout: ExportSheetRows, formats: [FormatChoice], ids: ExportSheetIDs, options: Options
    let onFormat: @MainActor (String) -> Void, onScale: @MainActor (Double) -> Void, onQuality: @MainActor (Double) -> Void
    let onExport: @MainActor () -> Void, onClose: @MainActor () -> Void
    let onTryAgain: (@MainActor () -> Void)?, onReveal: (@MainActor () -> Void)?

    /// `options` are the host's rows, drawn under the sheet's own and disabled with them; Try Again and Reveal
    /// show only when the host handles them.
    public init(
        _ readout: ExportSheetRows, formats: [FormatChoice], idPrefix: String = "suite.export",
        onFormat: @escaping @MainActor (String) -> Void, onScale: @escaping @MainActor (Double) -> Void,
        onQuality: @escaping @MainActor (Double) -> Void, onExport: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void, onTryAgain: (@MainActor () -> Void)? = nil,
        onReveal: (@MainActor () -> Void)? = nil, @ViewBuilder options: () -> Options
    ) {
        (self.readout, self.formats, self.ids, self.options) = (readout, formats, ExportSheetIDs(idPrefix), options())
        (self.onFormat, self.onScale, self.onQuality) = (onFormat, onScale, onQuality)
        (self.onExport, self.onClose, self.onTryAgain, self.onReveal) = (onExport, onClose, onTryAgain, onReveal)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text("Export").font(SuiteFont.title)
            VStack(spacing: SuiteSpacing.s) {
                ForEach(Array(readout.rows.enumerated()), id: \.offset) { row($0.element) }
                options
            }
            .disabled(!readout.editable)
            if let p = readout.progress { BusyNote(p.text, identifier: ids.progress, fraction: (p.done, p.total)) }
            switch readout.line {
            case .finished(let text): Label(text, systemImage: "checkmark.circle").foregroundStyle(SuiteColor.stateSuccess)
            case .failed(let text): Label(text, systemImage: "exclamationmark.circle").foregroundStyle(SuiteColor.stateError)
            case nil: EmptyView()
            }
            HStack {
                Spacer()
                ForEach(readout.actions(canTryAgain: onTryAgain != nil, canReveal: onReveal != nil), id: \.self, content: button)
            }
        }
        .padding(SuiteSpacing.xl).frame(width: SuiteSize.contentMinimum.width)
    }

    @ViewBuilder private func button(_ action: ExportSheetAction) -> some View {
        switch action {
        case .tryAgain: Button("Try Again") { onTryAgain?() }.suiteControl(id: ids.id(action), enabled: true, reason: nil)
        case .reveal: Button("Reveal in Finder") { onReveal?() }.suiteControl(id: ids.id(action), enabled: true, reason: nil)
        case .cancel, .dismiss:
            Button(action == .cancel ? "Cancel" : "Done", action: onClose)
                .keyboardShortcut(.cancelAction).suiteControl(id: ids.id(action), enabled: true, reason: nil)
        case .start:
            let help = readout.editable ? nil : "The export is already under way or done."
            Button("Export", action: onExport)
                .keyboardShortcut(.defaultAction).disabled(help != nil).help(help ?? "Export with these settings")
                .suiteControl(id: ids.start, enabled: help == nil, reason: help, role: "primary")
        }
    }

    @ViewBuilder private func row(_ row: ExportSheetRows.Row) -> some View {
        switch row {
        case .format(let id):
            VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                Text("Format").font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
                ChoiceChips(
                    options: formats.map { InspectorOption(id: $0.id, title: $0.name, identifier: ids.format($0.id)) },
                    selected: id, onSelect: onFormat)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Format")
                    .suiteControl(id: ids.formats, enabled: readout.editable, reason: readout.editable ? nil : "The export is under way or done.")
            }
        case .size(let scale): StudioScrubRow(label: "Size", value: scale, range: 0.25...4, step: 0.25, onChange: onScale)
        case .quality(let q): StudioScrubRow(label: "Quality", value: q, range: 0...1, step: 0.05, onChange: onQuality)
        }
    }
}

extension SuiteExportSheet where Options == EmptyView {
    /// A sheet with no host rows.
    public init(
        _ readout: ExportSheetRows, formats: [FormatChoice], idPrefix: String = "suite.export",
        onFormat: @escaping @MainActor (String) -> Void, onScale: @escaping @MainActor (Double) -> Void,
        onQuality: @escaping @MainActor (Double) -> Void, onExport: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void, onTryAgain: (@MainActor () -> Void)? = nil,
        onReveal: (@MainActor () -> Void)? = nil
    ) {
        self.init(
            readout, formats: formats, idPrefix: idPrefix, onFormat: onFormat, onScale: onScale, onQuality: onQuality,
            onExport: onExport, onClose: onClose, onTryAgain: onTryAgain, onReveal: onReveal) { EmptyView() }
    }
}
