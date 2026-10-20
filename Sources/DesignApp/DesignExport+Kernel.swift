// DesignExport+Kernel.swift: File > Export…'s sheet (design-export DE-6) on SuiteUI's
// SuiteExportSheet. DesignExportArea keeps the run (DesignExportRun) as its own state, so editing
// the sheet never runs the window's body; each change of `request` opens it on the Model's
// `exportSheetDefaults`. Ids hang off `design.export`: Format (no Size row: Scale is the one
// scale control), then DesignExportRows' Scale (`scale.<n>x`, off with `scaleHelp` for SVG and
// PDF) and Scope (`scope.<scope>`) chips, the file list (`items`) and the plan's refusal (`result`).
// Export (DE-7) runs the fake steps in a task, the summary on the sheet and the status line;
// Cancel mid-run cancels it. `sheet` is the content alone, which DesignExportSnapshots renders.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignExportArea: ViewModifier {
    let model: DesignWorkspace
    /// Bumped by File > Export…; each change opens the sheet.
    let request: Int
    let onNote: @MainActor (String) -> Void
    @State private var run: DesignExportRun = .idle
    @State private var task: Task<Void, Never>?

    /// The format chips: one per DesignExportFormat, its id the raw value.
    nonisolated static let formats = DesignExportFormat.allCases.map {
        FormatChoice(id: $0.rawValue, name: $0.rawValue.uppercased(), hasQuality: false)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _ = run.begin(model.exportSheetDefaults) }
            .sheet(isPresented: Binding(get: { run != .idle }, set: { if !$0 { close() } })) {
                Self.sheet(model: model, run: run, edit: { _ = run.begin($0) }, export: export, close: close)
            }
    }

    /// Cancel or Escape: stops a run under way (it ends idle), else closes the sheet.
    private func close() {
        if case .running = run { task?.cancel() } else { run.dismiss() }
    }

    /// Export on the fakes (DE-7): one step per planned file, writing nothing; `-DesignExportFail` fails its file.
    private func export() {
        guard case .editing(let options) = run else { return }
        let failing = DesignWindowOptions(arguments: ProcessInfo.processInfo.arguments).exportFail
        let files = model.exportFiles(options)
        guard run.start(total: (try? files.get())?.count ?? 0) else { return }
        task = Task {
            do {
                let names = try files.get()
                for (index, name) in names.enumerated() {
                    try await Task.sleep(for: .milliseconds(150))
                    try DesignWorkspace.fakeWrite(name, failing: failing)
                    run.progressed(done: index + 1)
                }
                run.end(.success(names))
                onNote(DesignWorkspace.exportSummary(names))
            } catch {
                run.end(.failure(error))
                if let failure = error as? DesignExportFailure { onNote(failure.description) }
            }
        }
    }

    /// The sheet's content on `run`; `edit` takes new options, `export` starts, `close` is Cancel or Done.
    @MainActor static func sheet(
        model: DesignWorkspace, run: DesignExportRun, edit: @escaping @MainActor (DesignExportOptions) -> Void,
        export: @escaping @MainActor () -> Void, close: @escaping @MainActor () -> Void
    ) -> some View {
        let options = run.shownOptions ?? model.exportSheetDefaults
        return SuiteExportSheet(
            ExportSheetRows(run.summarized, formats: formats, showsSize: false) { ExportPick(format: $0.format.rawValue, scale: Double($0.scale)) },
            formats: formats,
            idPrefix: "design.export",
            onFormat: { id in
                if let format = DesignExportFormat(rawValue: id) {
                    var next = options
                    next.format = format
                    edit(next)
                }
            },
            onScale: { edit(options.scaled($0)) },
            onQuality: { _ in },
            onExport: export,
            onClose: close
        ) {
            if run.shownOptions != nil { DesignExportRows(model: model, options: options, edit: edit) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(DesignControlID.exportSheet)
    }
}

/// Design's rows in the export sheet's options slot: Scale, Scope, the file list and the plan's refusal.
struct DesignExportRows: View {
    let model: DesignWorkspace
    let options: DesignExportOptions
    let edit: @MainActor (DesignExportOptions) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            labeled("Scale", DesignControlID.exportScale) {
                ChoiceChips(
                    options: [1, 2, 3].map { InspectorOption(id: $0, title: "\($0)x", identifier: "design.export.scale.\($0)x") },
                    selected: options.scaleHelp == nil ? options.scale : nil
                ) { edit(options.scaled(Double($0))) }
                    .disabled(options.scaleHelp != nil)
                    .help(options.scaleHelp ?? "")
                if let help = options.scaleHelp { InspectorNote(help) }
            }
            labeled("Scope", DesignControlID.exportScope) {
                ChoiceChips(
                    options: DesignExportScope.allCases.map {
                        InspectorOption(id: $0, title: $0.title, identifier: "design.export.scope.\($0.rawValue)")
                    },
                    selected: options.scope
                ) { scope in
                    var next = options
                    next.scope = scope
                    edit(next)
                }
            }
            labeled("Files", DesignControlID.exportItems) {
                ForEach(model.exportRows(options)) { row in
                    if let skipped = row.skipped {
                        Text(row.text).font(SuiteFont.body).foregroundStyle(SuiteColor.textTertiary)
                        InspectorNote(skipped)
                    } else {
                        Text(row.text).font(SuiteFont.body)
                    }
                }
            }
            if let help = model.exportHelp(options) {
                InspectorNote(help, kind: .error, identifier: DesignControlID.exportResult)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `content` under a row label, grouped as `identifier`.
    private func labeled(_ label: String, _ identifier: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text(label).font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
            content()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
