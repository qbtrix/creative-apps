// DesignExport+Kernel.swift: File > Export…'s sheet (design-export DE-6) on SuiteUI's
// SuiteExportSheet. DesignExportArea keeps the run (DesignExportRun) as its own state, so editing
// the sheet never runs the window's body; each change of `request` opens it on the Model's
// `exportSheetDefaults`, which a finished run updates through `remember` (the window's
// `rememberExport` intent, so the Model itself keeps them). Ids hang off
// `design.export`: Format (no Size row: Scale is the one scale control), then DesignExportRows'
// Scale (`scale.<n>x`, off with `scaleHelp` for SVG and PDF) and Scope (`scope.<scope>`) chips, the
// file list (`items`) and the plan's refusal (`result`), which also disables Export, saying why
// (SuiteExportSheet's `blocked`). Export on the fakes (DE-7) runs fake steps
// that write nothing. Export on the live services (DE-10) writes into `-DesignExportTo`, else the
// folder an NSOpenPanel picks (its Cancel leaves the sheet editing): the plan is named against the
// folder's listing, each item renders (SVG from `exportSVG`, PNG, JPEG and PDF from DesignRasterizer) and
// is written `.withoutOverwriting`, progress steps per file, and the sheet and the status line read
// "Exported n file(s) to <folder>". A write that throws ends the run failed with the file's name and
// the system's reason, keeping the files already written; Cancel or Escape mid-run stops after the
// current file and reports what was written (DE-11). `sheet` is the content alone, which
// DesignExportSnapshots renders.
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignExportArea: ViewModifier {
    let model: DesignWorkspace
    /// Bumped by File > Export…; each change opens the sheet.
    let request: Int
    let onNote: @MainActor (String) -> Void
    /// A finished run's options, for the Model to open the next sheet with.
    let remember: @MainActor (DesignExportOptions) -> Void
    @State private var run: DesignExportRun = .idle
    @State private var task: Task<Void, Never>?
    /// The folder a finished live run wrote to, for its line; nil on the fakes.
    @State private var folderName: String?

    #if DEBUG
    /// RenderBudgetDesignExportTests' folder, in place of the panel.
    // view-static: main-actor
    static var testFolder: URL?
    #endif

    /// The format chips: one per DesignExportFormat, its id the raw value.
    nonisolated static let formats = DesignExportFormat.allCases.map {
        FormatChoice(id: $0.rawValue, name: $0.rawValue.uppercased(), hasQuality: false)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { open() }
            .sheet(isPresented: Binding(get: { run != .idle }, set: { if !$0 { close() } })) {
                Self.sheet(model: model, run: run, edit: { _ = run.begin($0) }, export: export, close: close, folder: folderName)
            }
    }

    /// Opens the sheet on the Model's defaults: the last finished run's options, else PNG 1x Frame.
    private func open() {
        folderName = nil
        _ = run.begin(model.exportSheetDefaults)
    }

    /// Cancel or Escape: stops a run under way after its current file, else closes the sheet.
    private func close() {
        if case .running = run { task?.cancel() } else { run.dismiss() }
    }

    /// Export: the fake steps on the fakes, else the live run into a folder.
    private func export() {
        guard case .editing(let options) = run else { return }
        if model.services == .fake {
            exportFakes(options)
        } else if let folder = Self.folder() {
            exportLive(options, to: folder)
        }
    }

    /// Where a live run writes: `-DesignExportTo`, else the folder the panel picks; nil on its Cancel.
    // view-static: main-actor
    private static func folder() -> URL? {
        if let path = DesignWindowOptions(arguments: ProcessInfo.processInfo.arguments).exportFolder {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        #if DEBUG
        if let testFolder { return testFolder }
        #endif
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// The live run (DE-10, DE-11): names against the folder's listing, then one render and one
    /// `.withoutOverwriting` write per file. A throw fails the run with the file's name and the
    /// system's reason; a cancel stops after the current file and reports what was written.
    private func exportLive(_ options: DesignExportOptions, to folder: URL) {
        let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        let items: [DesignExportItem]
        do { items = try model.exportPlan(options, existing: existing) } catch {
            refuse(error.help)
            return
        }
        guard run.start(total: items.count) else { return }
        let model = model
        task = Task {
            var written: [String] = []
            for item in items {
                if Task.isCancelled { break }
                do {
                    try Self.render(item, options.format, model)
                        .write(to: folder.appendingPathComponent(item.fileName), options: .withoutOverwriting)
                } catch {
                    let reason = (error as? DesignRefusal)?.help ?? error.localizedDescription
                    let line = "\(item.fileName) couldn't be written. \(reason)"
                    run.end(.failure(DesignExportFailure(line)))
                    onNote(line)
                    return
                }
                written.append(item.fileName)
                run.progressed(done: written.count)
                // Lets the sheet draw the step and a Cancel arrive before the next file.
                try? await Task.sleep(for: .milliseconds(10))
            }
            guard !written.isEmpty else { return run.end(.failure(CancellationError())) }
            folderName = folder.lastPathComponent
            run.end(.success(written))
            remember(options)
            onNote("Exported \(Self.files(written.count)) to \(folder.lastPathComponent)")
        }
    }

    /// One item's file: SVG text from the Model; PNG, JPEG (on the item's background) and PDF from DesignRasterizer.
    // view-static: main-actor
    private static func render(_ item: DesignExportItem, _ format: DesignExportFormat, _ model: DesignWorkspace) throws -> Data {
        switch format {
        case .svg: Data(try model.exportSVG(item).utf8)
        case .png: try DesignRasterizer.png(try model.exportRaster(item))
        case .pdf: try DesignRasterizer.pdf(try model.exportRaster(item))
        case .jpeg: try DesignRasterizer.jpeg(try model.exportRaster(item), background: item.background ?? .white)
        }
    }

    /// A plan refused before any file: the failed line and the status line read `help`.
    private func refuse(_ help: String) {
        guard run.start(total: 0) else { return }
        run.end(.failure(DesignExportFailure(help)))
        onNote(help)
    }

    /// "1 file", "3 files".
    nonisolated static func files(_ count: Int) -> String { "\(count) file\(count == 1 ? "" : "s")" }

    /// Export on the fakes (DE-7): one step per planned file, writing nothing; `-DesignExportFail` fails its file.
    private func exportFakes(_ options: DesignExportOptions) {
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
                remember(options)
                onNote(DesignWorkspace.exportSummary(names))
            } catch {
                run.end(.failure(error))
                if let failure = error as? DesignExportFailure { onNote(failure.description) }
            }
        }
    }

    /// The sheet's content on `run`; `edit` takes new options, `export` starts, `close` is Cancel or Done.
    /// A finished run with a `folder` reads "Exported n file(s) to <folder>", else `summarized`.
    @MainActor static func sheet(
        model: DesignWorkspace, run: DesignExportRun, edit: @escaping @MainActor (DesignExportOptions) -> Void,
        export: @escaping @MainActor () -> Void, close: @escaping @MainActor () -> Void, folder: String? = nil
    ) -> some View {
        let options = run.shownOptions ?? model.exportSheetDefaults
        var shown = run.summarized
        if case .finished(let finished, let names) = run, let folder {
            shown = .finished(finished, ["\(files(names.count)) to \(folder)"])
        }
        return SuiteExportSheet(
            ExportSheetRows(shown, formats: formats, showsSize: false) { ExportPick(format: $0.format.rawValue, scale: Double($0.scale)) },
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
            onClose: close,
            blocked: run.shownOptions.flatMap { model.exportHelp($0) }
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
