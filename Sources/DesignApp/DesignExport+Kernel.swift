// DesignExport+Kernel.swift: File > Export…'s sheet (design-export DE-6) on SuiteUI's
// SuiteExportSheet. DesignExportArea keeps the run (DesignExportRun) as its own state, so editing
// the sheet never runs the window's body; each change of `request` opens it on the Model's
// `exportSheetDefaults`. Ids hang off `design.export`: Format, Size, then DesignExportRows' Scale
// (`scale.<n>x`) and Scope (`scope.<scope>`) chips, the file list (`items`) and the plan's
// refusal (`result`). `sheet` is the content alone, which DesignExportSnapshots renders.
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

    /// The format chips: one per DesignExportFormat, its id the raw value.
    nonisolated static let formats = DesignExportFormat.allCases.map {
        FormatChoice(id: $0.rawValue, name: $0.rawValue.uppercased(), hasQuality: false)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _ = run.begin(model.exportSheetDefaults) }
            .sheet(isPresented: Binding(get: { run != .idle }, set: { if !$0 { run.dismiss() } })) {
                Self.sheet(model: model, run: run, edit: { _ = run.begin($0) },
                           export: { onNote("Exporting isn't built yet.") }, close: { run.dismiss() })
            }
    }

    /// The sheet's content on `run`; `edit` takes new options, `export` starts, `close` is Cancel or Done.
    @MainActor static func sheet(
        model: DesignWorkspace, run: DesignExportRun, edit: @escaping @MainActor (DesignExportOptions) -> Void,
        export: @escaping @MainActor () -> Void, close: @escaping @MainActor () -> Void
    ) -> some View {
        let options = run.shownOptions ?? model.exportSheetDefaults
        return SuiteExportSheet(
            ExportSheetRows(run, formats: formats) { ExportPick(format: $0.format.rawValue, scale: Double($0.scale)) },
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
                    selected: options.scale
                ) { edit(options.scaled(Double($0))) }
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
