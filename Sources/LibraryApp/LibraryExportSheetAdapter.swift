// LibraryExportSheetAdapter.swift: File > Export… (export EX-6) on SuiteUI's
// SuiteExportSheet (#5270), its ids under `library.export`. The shared sheet
// draws the title ("Export 3 Photos"), Format chips for the formats this Mac
// writes, the progress row ("Exporting 2 of 3" while the second photo writes),
// the summary line (the run's ExportSummary words, failed once a photo failed)
// and Cancel, Export, Try Again, Reveal in Finder and Done. Library's own rows
// fill the options slot: Size chips, Long Edge, Quality (0 to 100, for formats
// that take one), Folder with Choose…, Name, Preset, Write Sidecar, the preview
// line, Save as Preset… and, after a failed run, the files that failed. Values
// in, closures out; a nil action leaves its control off. The slot's commands
// are their catalog command's MenuCommand on the window's catalog (command-state
// CS-6); Export is off with the fields', the exporter's or the catalog's reason.
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct LibraryExportSheetAdapter: View {
    struct Actions {
        var setOptions: (@MainActor (ExportOptions) -> Void)?
        var chooseFolder, export, cancel, retry, close, showInFinder: LibraryMenu.Action?
        var applyPreset: (@MainActor (ExportPreset) -> Void)?
        var savePreset: (@MainActor (String) -> Void)?
    }

    let run: ExportRun<ExportOptions>, summary: ExportSummary?, count: Int, preview: String?
    let writable: Set<ExportFormat>, exportHelp: String?, presets: [ExportPreset], actions: Actions
    /// The window's catalog, which the controls' specs read; nil (a snapshot) leaves the actions alone to decide.
    var catalog: LibraryCatalog?
    @State private var longEdgeText: String
    @State private var qualityText: String
    @State private var savingPreset = false
    @State private var presetName = ""

    init(run: ExportRun<ExportOptions>, summary: ExportSummary?, count: Int, preview: String?, writable: Set<ExportFormat>,
         exportHelp: String?, presets: [ExportPreset], actions: Actions = Actions(), catalog: LibraryCatalog? = nil) {
        (self.run, self.summary, self.count, self.preview, self.writable) = (run, summary, count, preview, writable)
        (self.exportHelp, self.presets, self.actions, self.catalog) = (exportHelp, presets, actions, catalog)
        let options = Self.options(run)
        _longEdgeText = State(initialValue: options?.longEdge.map(String.init) ?? "")
        _qualityText = State(initialValue: options.map { String($0.quality) } ?? "")
    }

    var body: some View {
        let formats = Self.formats(writable: writable)
        SuiteExportSheet(
            Self.readout(run, summary: summary, formats: formats), formats: formats, idPrefix: "library.export",
            title: Self.title(count), startReason: Self.options(run).flatMap(startReason),
            onFormat: { (id: String) -> Void in if let format = ExportFormat(rawValue: id) { change { $0.format = format } } },
            onScale: { _ in }, onQuality: { _ in },
            onExport: { actions.export?() },
            onClose: { if case .running = run { actions.cancel?() } else { actions.close?() } },
            onTryAgain: summary?.failedIDs.isEmpty == false ? actions.retry : nil,
            onReveal: summary?.written.isEmpty == false ? actions.showInFinder : nil
        ) {
            if let options = Self.options(run) { editing(options) }
            if let summary, !summary.failures.isEmpty {
                InspectorNote(Self.failureLines(summary.failures).joined(separator: "\n"), identifier: "library.export.failures")
            }
        }
        .onChange(of: Self.options(run)) { (_: ExportOptions?, options: ExportOptions?) -> Void in sync(options) }
    }

    @ViewBuilder private func editing(_ options: ExportOptions) -> some View {
        let sizes: [InspectorOption<Int>] = Self.sizes.map { edge in
            InspectorOption(id: edge, title: edge == 0 ? "Original Size" : String(edge),
                            identifier: "library.export.size." + (edge == 0 ? "original" : String(edge)))
        }
        let formatHelp = ExportFormat.allCases.compactMap { $0.help(writable: writable) }.joined(separator: " ")
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text("Size").font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
            ChoiceChips(options: sizes, selected: options.longEdge ?? 0) { (edge: Int) -> Void in
                change { $0.longEdge = edge == 0 ? nil : edge }
            }
        }
        Form {
            TextField("Long Edge (px)", text: Binding(get: { longEdgeText }, set: { setLongEdge($0) }),
                      prompt: Text("Original"))
                .accessibilityLabel("Long Edge").accessibilityIdentifier("library.export.longEdge")
            if options.format.usesQuality {
                TextField("Quality", text: Binding(get: { qualityText }, set: { setQuality($0) }))
                    .accessibilityLabel("Quality").accessibilityIdentifier("library.export.quality")
            }
            LabeledContent("Folder") {
                HStack(spacing: SuiteSpacing.s) {
                    Text(URL(fileURLWithPath: options.folder).lastPathComponent).lineLimit(1).truncationMode(.middle)
                        .help(options.folder).accessibilityIdentifier("library.export.folder")
                    MenuCommand("export.set-folder", on: catalog, title: "Choose…", action: actions.chooseFolder,
                                reason: Self.notEditing)
                        .accessibilityIdentifier("library.export.chooseFolder")
                }
            }
            TextField("Name", text: Binding(get: { options.naming.template }, set: { setTemplate($0) }))
                .help(options.naming.help ?? "Tokens: {name}, {date}, {seq}, {rating}.")
                .accessibilityIdentifier("library.export.name")
            Menu("Preset") {
                ForEach(presets) { (preset: ExportPreset) in
                    MenuCommand("export.apply-preset", on: catalog, title: preset.name, action: apply(preset),
                                reason: ExportPresets.unavailable ?? Self.notEditing)
                }
            }
            .disabled(actions.applyPreset == nil || presets.isEmpty)
            .help(ExportPresets.unavailable ?? "Apply a saved preset.")
            .accessibilityIdentifier("library.export.preset")
            Toggle("Write Sidecar", isOn: Binding(get: { options.sidecar }, set: { setSidecar($0) }))
                .toggleStyle(.checkbox).disabled(ExportSidecar.unavailable != nil)
                .help(ExportSidecar.unavailable ?? "Writes an XMP file with the rating beside each photo.")
                .accessibilityIdentifier("library.export.sidecar")
        }
        if !formatHelp.isEmpty { Text(formatHelp).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText) }
        Text(preview ?? "").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("library.export.preview")
        HStack {
            MenuCommand("export.save-preset", on: catalog, title: "Save as Preset…", action: askPresetName,
                        reason: ExportPresets.unavailable ?? Self.notEditing)
                .accessibilityIdentifier("library.export.savePreset")
            Spacer()
        }
        .alert("Save as Preset", isPresented: $savingPreset) {
            TextField("Name", text: $presetName).accessibilityIdentifier("library.export.presetName")
            Button("Save") { savePreset() }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// What the shared sheet shows for `run`: the Format row alone (Library draws its own size and quality), the
    /// photo being written counted in the progress ("Exporting 2 of 3" with one done), and a finished run's
    /// summary in its own words, failed when a photo failed.
    nonisolated static func readout(_ run: ExportRun<ExportOptions>, summary: ExportSummary?, formats: [FormatChoice]) -> ExportSheetRows {
        let base = ExportSheetRows(run, formats: formats, showsSize: false) { ExportPick(format: $0.format.rawValue) }
        var progress = base.progress, line = base.line
        if case .running(_, let done, let total) = run { progress = ExportProgress(done: done + 1, total: total) }
        if case .finished = run, let summary {
            line = summary.failures.isEmpty ? .finished(summary.message) : .failed(summary.message)
        }
        return ExportSheetRows(rows: base.rows, editable: base.editable, progress: progress, line: line)
    }

    /// The Format chips: the formats this Mac writes; Library's own Quality field stands in for the shared row.
    nonisolated static func formats(writable: Set<ExportFormat>) -> [FormatChoice] {
        ExportFormat.allCases.filter { $0.help(writable: writable) == nil }
            .map { FormatChoice(id: $0.rawValue, name: $0.rawValue, hasQuality: false) }
    }

    /// Why Export is off while editing: a field that doesn't read, the exporter's or the name's help, no action,
    /// or `file.export` unable to run on the catalog.
    private func startReason(_ options: ExportOptions) -> String? {
        if let blocked = fieldsHelp(options) ?? exportHelp { return blocked }
        guard actions.export != nil else { return Self.notEditing }
        return catalog.flatMap { LibraryCatalog.catalog.spec("file.export")?.availability($0).why }
    }

    nonisolated static let sizes = [1024, 2048, 4096, 0]

    /// Why an editing control is off with no action: the sheet isn't editing.
    nonisolated static let notEditing = "The export sheet isn't editing."

    /// Apply Preset's action for `preset`, nil while presets can't apply.
    private func apply(_ preset: ExportPreset) -> LibraryMenu.Action? {
        guard let applyPreset = actions.applyPreset else { return nil }
        return { applyPreset(preset) }
    }

    /// Save as Preset…'s action: asks for the name, then Save runs the window's save; nil while it can't save.
    private var askPresetName: LibraryMenu.Action? {
        guard actions.savePreset != nil else { return nil }
        return { savingPreset = true }
    }

    nonisolated static func title(_ count: Int) -> String { count == 1 ? "Export 1 Photo" : "Export \(count) Photos" }

    nonisolated static func failureLines(_ failures: [FileFailure]) -> [String] {
        failures.map { "\(URL(fileURLWithPath: $0.path).lastPathComponent): \($0.reason)" }
    }

    nonisolated static func number(_ text: String, in range: ClosedRange<Int>) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces)).flatMap { range.contains($0) ? $0 : nil }
    }

    nonisolated static func options(_ state: ExportState) -> ExportOptions? {
        if case .editing(let options) = state { return options }
        return nil
    }

    nonisolated static func options(_ run: ExportRun<ExportOptions>) -> ExportOptions? {
        if case .editing(let options) = run { return options }
        return nil
    }

    private func fieldsHelp(_ options: ExportOptions) -> String? {
        let range = ExportOptions.longEdgeRange
        if !(options.longEdge == nil && longEdgeText.isEmpty), Self.number(longEdgeText, in: range) == nil {
            return "Type a long edge from \(range.lowerBound) to \(range.upperBound) px."
        }
        if options.format.usesQuality, Self.number(qualityText, in: 0...100) == nil { return "Type a quality from 0 to 100." }
        return nil
    }

    /// A chip or preset changed the options: a field that reads otherwise follows them.
    private func sync(_ options: ExportOptions?) {
        guard let options else { return }
        if Self.number(longEdgeText, in: ExportOptions.longEdgeRange) != options.longEdge {
            longEdgeText = options.longEdge.map(String.init) ?? ""
        }
        if Self.number(qualityText, in: 0...100) != options.quality { qualityText = String(options.quality) }
    }

    private func change(_ edit: (inout ExportOptions) -> Void) {
        guard var options = Self.options(run) else { return }
        edit(&options)
        actions.setOptions?(options)
    }

    private func setLongEdge(_ text: String) {
        longEdgeText = text
        if let edge = Self.number(text, in: ExportOptions.longEdgeRange) { change { $0.longEdge = edge } }
    }
    private func setQuality(_ text: String) {
        qualityText = text
        if let quality = Self.number(text, in: 0...100) { change { $0.quality = quality } }
    }

    private func setTemplate(_ template: String) { change { $0.naming = ExportNaming(template: template) } }
    private func setSidecar(_ on: Bool) { change { $0.sidecar = on } }

    private func savePreset() {
        let name = presetName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { actions.savePreset?(name) }
        presetName = ""
    }
}
