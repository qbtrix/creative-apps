// ExportSheet.swift: SuiteExportSheet (EK-30), drawn over ExportSheetRows, a
// readout of the kernel's ExportRun: Format chips (one row of equal chips up
// to four formats, else rows of three: formatColumns), Size (a multiplier, "1.00×"; unless the host draws
// its own scale), (when the format takes one) Quality and (when the host passes
// a policy) Metadata rows, 8 pt apart, then the host's own options rows (the slot, #1989),
// a progress bar while running, the finished or failed line after, and the
// actions that state offers (ExportSheetAction). Every control's identifier
// hangs off the host's prefix (ExportSheetIDs, "suite.export" by default) and
// registers in `suite.controls`. When the progress row appears it marks
// `progress-shown` on the prefix's series in the window's `suite.perf`
// (HB-U5, QB-L9). It holds no state; every edit goes to the host, which
// moves its run. A pick with a `size` (export-pack XP-3, XP-4) shows the Size
// row: Scale | Pixels | Long edge chips (Scale only for a vector format), the
// mode's fields (Pixels: width, height and a Keep Ratio box, the ratio lock,
// which is the size's `stretch` turned around) and a readout of the pixels
// ExportRules will write, or its refusal. A pick with a `metadata` policy shows
// the Metadata menu, unless the format carries none (SVG). The size
// arithmetic is ExportSheetRows' statics over ExportRules; the sheet sends
// each new size and policy through `onSize` and `onMetadata`.
import SuiteKernel
import SwiftUI

/// One format the sheet offers, and whether it takes a quality.
public struct FormatChoice: Hashable, Sendable, Identifiable {
    public let id: String, name: String, hasQuality: Bool
    public init(id: String, name: String, hasQuality: Bool) { (self.id, self.name, self.hasQuality) = (id, name, hasQuality) }
}

/// Export options as the sheet reads them: format id, scale, quality 0...1, the metadata policy
/// (export-pack; nil: the host offers none) and the kernel's size (nil: the Scale row as before).
public struct ExportPick: Hashable, Sendable {
    public var format: String, scale: Double, quality: Double
    public var metadata: ExportMetadata? = nil
    public var size: SuiteExportSize? = nil
    public init(
        format: String, scale: Double = 1, quality: Double = 0.9, metadata: ExportMetadata? = nil, size: SuiteExportSize? = nil
    ) {
        (self.format, self.scale, self.quality, self.metadata, self.size) = (format, scale, quality, metadata, size)
    }
}

/// A running export's steps, done clamped to 0...total and total at least 1.
public struct ExportProgress: Hashable, Sendable {
    public let done: Int, total: Int
    public init(done: Int, total: Int) { (self.total, self.done) = (max(total, 1), min(max(done, 0), max(total, 1))) }
    public var text: String { "Exporting \(done) of \(total)" }
}

/// What the sheet shows for a run; only editing is `editable`.
public struct ExportSheetRows: Hashable, Sendable {
    public enum Row: Hashable, Sendable {
        case format(String), size(Double), quality(Double)
        /// The kernel's size on an artwork `source` pixels big at 1x (XP-3 placeholder; XP-4 the modes).
        case pixels(SuiteExportSize, source: Int, Int)
        case metadata(ExportMetadata)
        /// The unit its value reads with: Size is a multiplier ("1.00×"), Quality a plain 0...1.
        public var unit: String { if case .size = self { "×" } else { "" } }
    }
    public enum Line: Hashable, Sendable { case finished(String), failed(String) }
    /// The modes the Size chips offer, in drawing order.
    public enum SizeMode: String, CaseIterable, Hashable, Sendable {
        case scale, pixels, longEdge
        public var title: String { self == .scale ? "Scale" : self == .pixels ? "Pixels" : "Long edge" }
    }
    public let rows: [Row], editable: Bool, progress: ExportProgress?, line: Line?
    /// What the Size chips offer for the pick's format: Scale only for a vector one, otherwise every mode.
    public let sizeModes: [SizeMode]

    /// The actions this state offers, in drawing order: Try Again on a failed run and Reveal on a finished one
    /// when the host handles them, the close button (Cancel until a line shows, then Done), and Export.
    public func actions(canTryAgain: Bool, canReveal: Bool) -> [ExportSheetAction] {
        var shown: [ExportSheetAction] = []
        if case .failed = line, canTryAgain { shown.append(.tryAgain) }
        if case .finished = line, canReveal { shown.append(.reveal) }
        return shown + [line == nil ? .cancel : .dismiss, .start]
    }

    /// Why Export can't start, or nil when it can: the run is past editing, or the Size row's readout is a refusal.
    public var startBlock: String? {
        guard editable else { return "The export is already under way or done." }
        for case .pixels(let size, let w, let h) in rows {
            let shown = Self.readout(size, source: (w, h))
            if shown.refused { return shown.text }
        }
        return nil
    }

    /// Columns for the Format chips: up to four formats fill one row (no empty column, no orphan chip), more wrap by three.
    public static func formatColumns(_ count: Int) -> Int { count <= 4 ? max(count, 1) : 3 }

    /// The Size placeholder's text: "1080 × 1350 px", "Long edge 2048 px", "2x of 1000 × 1250 px".
    public static func sizeText(_ size: SuiteExportSize, source width: Int, _ height: Int) -> String {
        switch size {
        case .scale(let s): "\(s.formatted(.number.precision(.fractionLength(0...2))))x of \(width) × \(height) px"
        case .pixels(let w, let h, let stretch): "\(w) × \(h) px" + (stretch ? ", stretched" : "")
        case .longEdge(let n): "Long edge \(n) px"
        }
    }

    /// The mode `size` is in.
    public static func sizeMode(of size: SuiteExportSize) -> SizeMode {
        switch size {
        case .scale: .scale
        case .pixels: .pixels
        case .longEdge: .longEdge
        }
    }

    /// The pixels `size` writes for `source`, or the source's own when the rules refuse it.
    static func written(_ size: SuiteExportSize, source: (width: Int, height: Int)) -> (width: Int, height: Int) {
        (try? ExportRules.pixels(of: source, size, evenSize: false)) ?? source
    }

    /// `size` moved to `mode` at the pixels it writes now: Pixels locked to them, Long edge their long side,
    /// Scale their width over the source's.
    public static func switching(
        _ size: SuiteExportSize, to mode: SizeMode, source: (width: Int, height: Int)
    ) -> SuiteExportSize {
        guard sizeMode(of: size) != mode else { return size }
        let (w, h) = written(size, source: source)
        switch mode {
        case .pixels: return .pixels(width: w, height: h)
        case .longEdge: return .longEdge(max(w, h))
        case .scale: return .scale(source.width >= 1 ? Double(w) / Double(source.width) : 1)
        }
    }

    /// `side` × `other` / `of`, rounded to a whole pixel and never under 1; 1 when `of` is 0.
    static func proportional(_ side: Int, _ other: Int, of: Int) -> Int {
        guard of >= 1 else { return 1 }
        let x = (Double(side) * Double(other) / Double(of)).rounded()
        return x.isFinite ? Int(min(max(x, 1), 1e9)) : 1
    }

    /// Width `typed` into a Pixels size: with the lock on the height follows the source's shape.
    public static func typing(width typed: Int, in size: SuiteExportSize, source: (width: Int, height: Int)) -> SuiteExportSize {
        guard case .pixels(_, let h, let stretch) = size else { return size }
        return .pixels(width: typed, height: stretch ? h : proportional(typed, source.height, of: source.width), stretch: stretch)
    }

    /// Height `typed` into a Pixels size: with the lock on the width follows the source's shape.
    public static func typing(height typed: Int, in size: SuiteExportSize, source: (width: Int, height: Int)) -> SuiteExportSize {
        guard case .pixels(let w, _, let stretch) = size else { return size }
        return .pixels(width: stretch ? w : proportional(typed, source.width, of: source.height), height: typed, stretch: stretch)
    }

    /// The ratio lock turned `on` (the height follows the width again) or off (the size may stretch).
    public static func locking(_ on: Bool, _ size: SuiteExportSize, source: (width: Int, height: Int)) -> SuiteExportSize {
        guard case .pixels(let w, let h, _) = size else { return size }
        return on ? typing(width: w, in: .pixels(width: w, height: h), source: source) : .pixels(width: w, height: h, stretch: true)
    }

    /// The readout under the Size row: "1080 × 1350 px" (", stretched" when an unlocked size leaves the
    /// source's shape), or the rules' refusal with `refused` set.
    public static func readout(
        _ size: SuiteExportSize, source: (width: Int, height: Int), evenSize: Bool = false
    ) -> (text: String, refused: Bool) {
        do {
            let (w, h) = try ExportRules.pixels(of: source, size, evenSize: evenSize)
            guard case .pixels(let pw, let ph, true) = size,
                  (try? ExportRules.pixels(of: source, .pixels(width: pw, height: ph), evenSize: false)) == nil
            else { return ("\(w) × \(h) px", false) }
            return ("\(w) × \(h) px, stretched", false)
        } catch {
            return (String(describing: error), true)
        }
    }

    /// `showsSize: false` leaves out the Size row, for a host that draws its own scale control; `source` is the
    /// artwork's pixels at 1x, which a pick's `size` reads against.
    public init<Options: Hashable & Sendable>(
        _ run: ExportRun<Options>, formats: [FormatChoice], showsSize: Bool = true,
        source: (width: Int, height: Int) = (0, 0), pick: (Options) -> ExportPick
    ) {
        var modes = SizeMode.allCases
        func shown(_ options: Options) -> [Row] {
            let p = pick(options), spec = ExportFormats.spec(p.format)
            let quality = formats.first { $0.id == p.format }?.hasQuality ?? false
            if spec?.kind == .vector { modes = [.scale] }
            let fits = p.size.map { modes.contains(Self.sizeMode(of: $0)) ? $0 : SuiteExportSize.scale(1) }
            let size: [Row] = !showsSize ? [] : fits.map { [.pixels($0, source: source.width, source.height)] } ?? [.size(p.scale)]
            let metadata: [Row] = spec?.carriesMetadata == false ? [] : p.metadata.map { [.metadata($0)] } ?? []
            return [.format(p.format)] + size + (quality ? [.quality(p.quality)] : []) + metadata
        }
        var progress: ExportProgress?, line: Line?, editable = false
        switch run {
        case .idle: rows = []
        case .editing(let o): rows = shown(o); editable = true
        case .running(let o, let done, let total): rows = shown(o); progress = ExportProgress(done: done, total: total)
        case .finished(let o, let files): rows = shown(o); line = .finished("Exported " + files.joined(separator: ", "))
        case .failed(let o, let error): rows = shown(o); line = .failed(error)
        }
        (self.progress, self.line, self.editable, self.sizeModes) = (progress, line, editable, modes)
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
    /// The Size row's parts: `<prefix>.size.width`, `.height`, `.lock`, `.longEdge`, `.scale`, `.readout`.
    public enum SizePart: String, Sendable { case width, height, lock, longEdge, scale, readout }
    public var size: String { prefix + ".size" }
    public var metadata: String { prefix + ".metadata" }
    public func size(_ part: SizePart) -> String { "\(size).\(part.rawValue)" }
    public func sizeMode(_ mode: ExportSheetRows.SizeMode) -> String { "\(size).mode.\(mode.rawValue)" }
}

public struct SuiteExportSheet<Options: View>: View {
    let readout: ExportSheetRows, formats: [FormatChoice], ids: ExportSheetIDs, options: Options
    let onFormat: @MainActor (String) -> Void, onScale: @MainActor (Double) -> Void, onQuality: @MainActor (Double) -> Void
    let onExport: @MainActor () -> Void, onClose: @MainActor () -> Void
    let onTryAgain: (@MainActor () -> Void)?, onReveal: (@MainActor () -> Void)?
    let onSize: (@MainActor (SuiteExportSize) -> Void)?, onMetadata: (@MainActor (ExportMetadata) -> Void)?
    @Environment(\.suiteProbeRecorder) private var recorder

    /// `options` are the host's rows, drawn under the sheet's own and disabled with them; Try Again and Reveal
    /// show only when the host handles them. The Size and Metadata rows' controls are disabled, saying why,
    /// unless the host passes `onSize` and `onMetadata`.
    public init(
        _ readout: ExportSheetRows, formats: [FormatChoice], idPrefix: String = "suite.export",
        onFormat: @escaping @MainActor (String) -> Void, onScale: @escaping @MainActor (Double) -> Void,
        onQuality: @escaping @MainActor (Double) -> Void, onExport: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void, onTryAgain: (@MainActor () -> Void)? = nil,
        onReveal: (@MainActor () -> Void)? = nil, onSize: (@MainActor (SuiteExportSize) -> Void)? = nil,
        onMetadata: (@MainActor (ExportMetadata) -> Void)? = nil, @ViewBuilder options: () -> Options
    ) {
        (self.readout, self.formats, self.ids, self.options) = (readout, formats, ExportSheetIDs(idPrefix), options())
        (self.onFormat, self.onScale, self.onQuality) = (onFormat, onScale, onQuality)
        (self.onExport, self.onClose, self.onTryAgain, self.onReveal) = (onExport, onClose, onTryAgain, onReveal)
        (self.onSize, self.onMetadata) = (onSize, onMetadata)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text("Export").font(SuiteFont.title)
            VStack(spacing: SuiteSpacing.s) {
                ForEach(Array(readout.rows.enumerated()), id: \.offset) { row($0.element) }
                options
            }
            .disabled(!readout.editable)
            if let p = readout.progress {
                BusyNote(p.text, identifier: ids.progress, fraction: (p.done, p.total))
                    .onAppear { recorder?.mark("progress-shown", series: ids.prefix) }
            }
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
            let help = readout.startBlock
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
                PresetGrid(
                    options: formats.map { InspectorOption(id: $0.id, title: $0.name, identifier: ids.format($0.id)) },
                    selected: id, columns: ExportSheetRows.formatColumns(formats.count), onSelect: onFormat)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Format")
                    .suiteControl(id: ids.formats, enabled: readout.editable, reason: readout.editable ? nil : "The export is under way or done.")
            }
        case .size(let scale):
            StudioScrubRow(label: "Size", value: scale, range: 0.25...4, step: 0.25, unit: row.unit, onChange: onScale)
        case .quality(let q): StudioScrubRow(label: "Quality", value: q, range: 0...1, step: 0.05, onChange: onQuality)
        case .pixels(let size, let w, let h): sizeRow(size, source: (w, h))
        case .metadata(let policy):
            let reason = editReason(handled: onMetadata != nil, what: "metadata")
            InspectorRow("Metadata") {
                InspectorValueMenu(
                    "Metadata", options: ExportMetadata.allCases.map { InspectorOption(id: $0, title: $0.title) },
                    selection: policy, onChange: { onMetadata?($0) })
                    .suiteControl(id: ids.metadata, enabled: reason == nil, reason: reason)
            }
            .disabled(reason != nil).help(reason ?? "")
        }
    }

    /// Why a row's controls can't edit: the run is past editing, or the host doesn't handle `what`.
    private func editReason(handled: Bool, what: String) -> String? {
        !readout.editable ? "The export is under way or done." : handled ? nil : "This sheet doesn't change the \(what) here."
    }

    /// The Size row: the mode chips, the mode's fields, and the readout of the pixels it writes.
    @ViewBuilder private func sizeRow(_ size: SuiteExportSize, source: (width: Int, height: Int)) -> some View {
        let reason = editReason(handled: onSize != nil, what: "size"), enabled = reason == nil
        let send: @MainActor (SuiteExportSize) -> Void = { onSize?($0) }
        let sides = 1...Double(ExportRules.maxSide)
        let shown = ExportSheetRows.readout(size, source: source)
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text("Size").font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
            ChoiceChips(
                options: readout.sizeModes.map { InspectorOption(id: $0, title: $0.title, identifier: ids.sizeMode($0)) },
                selected: ExportSheetRows.sizeMode(of: size),
                onSelect: { send(ExportSheetRows.switching(size, to: $0, source: source)) })
                .accessibilityElement(children: .contain).accessibilityLabel("Size")
                .suiteControl(id: ids.size, enabled: enabled, reason: reason)
            switch size {
            case .scale(let s):
                StudioScrubRow(label: "Scale", value: s, range: 0.25...4, step: 0.25, unit: ExportSheetRows.Row.size(s).unit, onChange: { send(.scale($0)) })
                    .suiteControl(id: ids.size(.scale), enabled: enabled, reason: reason)
            case .pixels(let w, let h, let stretch):
                InspectorRow("Width") {
                    ScrubField("Width", value: Double(w), in: sides, step: 1, decimals: 0, onChange: {
                        send(ExportSheetRows.typing(width: Int($0), in: size, source: source))
                    })
                    .suiteControl(id: ids.size(.width), enabled: enabled, reason: reason)
                }
                InspectorRow("Height") {
                    ScrubField("Height", value: Double(h), in: sides, step: 1, decimals: 0, onChange: {
                        send(ExportSheetRows.typing(height: Int($0), in: size, source: source))
                    })
                    .suiteControl(id: ids.size(.height), enabled: enabled, reason: reason)
                }
                InspectorRow("") {
                    Toggle("Keep Ratio", isOn: Binding(get: { !stretch }, set: { send(ExportSheetRows.locking($0, size, source: source)) }))
                        .toggleStyle(.checkbox)
                        .suiteControl(id: ids.size(.lock), enabled: enabled, reason: reason)
                }
            case .longEdge(let n):
                InspectorRow("Long Edge") {
                    ScrubField("Long Edge", value: Double(n), in: sides, step: 1, decimals: 0, onChange: { send(.longEdge(Int($0))) })
                        .suiteControl(id: ids.size(.longEdge), enabled: enabled, reason: reason)
                }
            }
            InspectorNote(shown.text, kind: shown.refused ? .error : .secondary, identifier: ids.size(.readout))
        }
        .disabled(!enabled).help(reason ?? "")
    }
}

extension SuiteExportSheet where Options == EmptyView {
    /// A sheet with no host rows.
    public init(
        _ readout: ExportSheetRows, formats: [FormatChoice], idPrefix: String = "suite.export",
        onFormat: @escaping @MainActor (String) -> Void, onScale: @escaping @MainActor (Double) -> Void,
        onQuality: @escaping @MainActor (Double) -> Void, onExport: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void, onTryAgain: (@MainActor () -> Void)? = nil,
        onReveal: (@MainActor () -> Void)? = nil, onSize: (@MainActor (SuiteExportSize) -> Void)? = nil,
        onMetadata: (@MainActor (ExportMetadata) -> Void)? = nil
    ) {
        self.init(
            readout, formats: formats, idPrefix: idPrefix, onFormat: onFormat, onScale: onScale, onQuality: onQuality,
            onExport: onExport, onClose: onClose, onTryAgain: onTryAgain, onReveal: onReveal, onSize: onSize,
            onMetadata: onMetadata) { EmptyView() }
    }
}
