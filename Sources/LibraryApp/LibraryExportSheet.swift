// LibraryExportSheet.swift: File > Export… (export EX-6): editing, the progress
// row, the summary. Values in, closures out; a nil action disables its control.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryExportSheet: View {
    struct Actions {
        var setOptions: (@MainActor (ExportOptions) -> Void)?
        var chooseFolder, export, cancel, retry, close, showInFinder: LibraryMenu.Action?
        var applyPreset: (@MainActor (ExportPreset) -> Void)?
        var savePreset: (@MainActor (String) -> Void)?
    }

    let state: ExportState, count: Int, preview: String?, writable: Set<ExportFormat>, exportHelp: String?
    let presets: [ExportPreset], actions: Actions, progressDelay: Duration
    @State private var longEdgeText: String
    @State private var qualityText: String
    @State private var savingPreset = false
    @State private var presetName = ""

    init(state: ExportState, count: Int, preview: String?, writable: Set<ExportFormat>, exportHelp: String?,
         presets: [ExportPreset], actions: Actions = Actions(), progressDelay: Duration = .milliseconds(100)) {
        (self.state, self.count, self.preview, self.writable) = (state, count, preview, writable)
        (self.exportHelp, self.presets, self.actions, self.progressDelay) = (exportHelp, presets, actions, progressDelay)
        let options = Self.options(state)
        _longEdgeText = State(initialValue: options?.longEdge.map(String.init) ?? "")
        _qualityText = State(initialValue: options.map { String($0.quality) } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text(Self.title(count)).font(SuiteFont.headline)
            switch state {
            case .idle: EmptyView()
            case .editing(let options): editing(options)
            case .running(let done, let total): running(done: done, total: total)
            case .finished(let summary): finished(summary)
            }
        }
        .padding(SuiteSpacing.l).frame(width: SuiteSize.contentIdealWidth)
        .onChange(of: Self.options(state)) { (_: ExportOptions?, options: ExportOptions?) -> Void in sync(options) }
    }

    @ViewBuilder private func editing(_ options: ExportOptions) -> some View {
        let sizes: [InspectorOption<Int>] = Self.sizes.map { edge in
            InspectorOption(id: edge, title: edge == 0 ? "Original Size" : String(edge),
                            identifier: "library.export.size." + (edge == 0 ? "original" : String(edge)))
        }
        let formats: [InspectorOption<ExportFormat>] = ExportFormat.allCases.filter { $0.help(writable: writable) == nil }
            .map { InspectorOption(id: $0, title: $0.rawValue, identifier: "library.export.format.\($0.rawValue)") }
        let formatHelp = ExportFormat.allCases.compactMap { $0.help(writable: writable) }.joined(separator: " ")
        let blocked: String? = fieldsHelp(options) ?? exportHelp
        Form {
            LabeledContent("Size") {
                ChoiceChips(options: sizes, selected: options.longEdge ?? 0) { (edge: Int) -> Void in
                    change { $0.longEdge = edge == 0 ? nil : edge }
                }
            }
            TextField("Long Edge (px)", text: Binding(get: { longEdgeText }, set: { setLongEdge($0) }),
                      prompt: Text("Original"))
                .accessibilityLabel("Long Edge").accessibilityIdentifier("library.export.longEdge")
            TextField("Quality", text: Binding(get: { qualityText }, set: { setQuality($0) }))
                .disabled(!options.format.usesQuality)
                .accessibilityLabel("Quality").accessibilityIdentifier("library.export.quality")
            LabeledContent("Folder") {
                HStack(spacing: SuiteSpacing.s) {
                    Text(URL(fileURLWithPath: options.folder).lastPathComponent).lineLimit(1).truncationMode(.middle)
                        .help(options.folder).accessibilityIdentifier("library.export.folder")
                    Button("Choose…") { actions.chooseFolder?() }.disabled(actions.chooseFolder == nil)
                        .accessibilityIdentifier("library.export.chooseFolder")
                }
            }
            LabeledContent("Format") {
                ChoiceChips(options: formats, selected: options.format) { (format: ExportFormat) -> Void in
                    change { $0.format = format }
                }
                .help(formatHelp)
            }
            TextField("Name", text: Binding(get: { options.naming.template }, set: { setTemplate($0) }))
                .help(options.naming.help ?? "Tokens: {name}, {date}, {seq}, {rating}.")
                .accessibilityIdentifier("library.export.name")
            Menu("Preset") {
                ForEach(presets) { (preset: ExportPreset) in Button(preset.name) { actions.applyPreset?(preset) } }
            }
            .disabled(actions.applyPreset == nil || presets.isEmpty)
            .help(ExportPresets.unavailable ?? "Apply a saved preset.")
            .accessibilityIdentifier("library.export.preset")
            Toggle("Write Sidecar", isOn: Binding(get: { options.sidecar }, set: { setSidecar($0) }))
                .toggleStyle(.checkbox).disabled(ExportSidecar.unavailable != nil)
                .help(ExportSidecar.unavailable ?? "Writes an XMP file with the rating beside each photo.")
                .accessibilityIdentifier("library.export.sidecar")
        }
        Text(preview ?? "").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            .accessibilityIdentifier("library.export.preview")
        HStack {
            Button("Save as Preset…") { savingPreset = true }.disabled(actions.savePreset == nil)
                .help(ExportPresets.unavailable ?? "Save these settings under a name.")
                .accessibilityIdentifier("library.export.savePreset")
            Spacer()
            Button("Cancel") { actions.close?() }.keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("library.export.cancel")
            Button("Export") { actions.export?() }.keyboardShortcut(.defaultAction)
                .disabled(actions.export == nil || blocked != nil).help(blocked ?? "Export")
                .accessibilityIdentifier("library.export.export")
        }
        .alert("Save as Preset", isPresented: $savingPreset) {
            TextField("Name", text: $presetName).accessibilityIdentifier("library.export.presetName")
            Button("Save") { savePreset() }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder private func running(done: Int, total: Int) -> some View {
        BusyNote(ExportProgress(done: done + 1, total: total).text, identifier: "library.export.progress",
                 fraction: (done, total), delay: progressDelay)
        HStack {
            Spacer()
            Button("Cancel") { actions.cancel?() }.keyboardShortcut(.cancelAction).disabled(actions.cancel == nil)
                .accessibilityIdentifier("library.export.cancel")
        }
    }

    @ViewBuilder private func finished(_ summary: ExportSummary) -> some View {
        let failed = !summary.failures.isEmpty
        if failed {
            InspectorNote(summary.message, kind: .error, identifier: "library.export.summary")
            InspectorNote(Self.failureLines(summary.failures).joined(separator: "\n"), identifier: "library.export.failures")
        } else if summary.cancelled {
            InspectorNote(summary.message, identifier: "library.export.summary")
        } else {
            Label(summary.message, systemImage: "checkmark.circle").foregroundStyle(SuiteColor.stateSuccess)
                .accessibilityIdentifier("library.export.summary")
        }
        HStack {
            if !summary.failedIDs.isEmpty {
                Button("Try Again") { actions.retry?() }.disabled(actions.retry == nil)
                    .accessibilityIdentifier("library.export.retry")
            }
            Spacer()
            if !summary.written.isEmpty {
                Button("Show in Finder") { actions.showInFinder?() }.disabled(actions.showInFinder == nil)
                    .accessibilityIdentifier("library.export.showInFinder")
            }
            Button("Done") { actions.close?() }.keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("library.export.done")
        }
    }

    nonisolated static let sizes = [1024, 2048, 4096, 0]

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
        guard var options = Self.options(state) else { return }
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
