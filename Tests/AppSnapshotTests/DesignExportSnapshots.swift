// DesignExportSnapshots.swift: File > Export… (design-export DE-6). The File menu with
// Export… ⇧⌘E off and on (design-export-menu); the sheet on `cards` at PNG 1x Frame with
// Desktop selected (design-export-sheet), and Selection with A and the hidden layer, the hidden
// one skipped (design-export-sheet-selection), and SVG with Scale off (design-export-sheet-svg).
// No Size row: Scale is the sheet's one scale control. The run (DE-7) at 2 of 3, finished with the
// summary, and failed on a file (design-export-running, -finished, -failed). Light and dark.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignExportSnapshots {
    /// `cards` with Desktop selected.
    private func cards(selecting ids: [String] = ["node-1"]) -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.useServices(.fake)
        if let first = ids.first { model.selectItem(first) }
        for id in ids.dropFirst() { model.toggleSelection(id) }
        return model
    }

    private func shoot(_ model: DesignWorkspace, _ run: DesignExportRun, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            let view = DesignExportArea.sheet(model: model, run: run, edit: { _ in }, export: {}, close: {})
            try snapshot(view, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func menu() throws {
        var open = DesignWorkspace()
        open.newFile()
        let off = DesignMenu(model: DesignWorkspace(), perform: { _ in })
        let on = DesignMenu(model: open, perform: { _ in })
        #expect(!off.isOpen && off.noFileHelp == "Create or open a file first.")
        #expect(on.isOpen && on.noFileHelp == nil)
        var exports = 0
        DesignMenu(model: open, perform: { if case .export = $0 { exports += 1 } }).perform(.export)
        #expect(exports == 1)
        for scheme in [ColorScheme.light, .dark] {
            let view = HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
                VStack(alignment: .leading, spacing: SuiteSpacing.s) { DesignFileMenu(menu: off) }
                VStack(alignment: .leading, spacing: SuiteSpacing.s) { DesignFileMenu(menu: on) }
            }
            .labelStyle(.titleAndIcon)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            try snapshot(view, name: "design-export-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func sheet() throws {
        let model = cards()
        let options = model.exportSheetDefaults
        #expect(options == DesignExportOptions(format: .png, scale: 1, scope: .frame))
        #expect(model.exportHelp(options) == nil)
        #expect(model.exportRows(options).map(\.text) == ["Desktop.png 1440 × 1024, 1x, 1440 × 1024 px"])
        try shoot(model, .editing(options), "design-export-sheet")
    }

    @Test func selection() throws {
        let model = cards(selecting: ["node-10", "node-2"])
        #expect(model.selectedNodeIDs == ["node-10", "node-2"])
        let options = DesignExportOptions(format: .png, scale: 2, scope: .selection)
        let rows = model.exportRows(options)
        #expect(rows.map(\.id) == ["node-2", "node-10"])
        #expect(rows.last?.skipped == "Hidden layers aren't exported")
        try shoot(model, .editing(options), "design-export-sheet-selection")
    }

    @Test func vector() throws {
        let options = DesignExportOptions(format: .svg, scale: 2, scope: .frame)
        let rows = ExportSheetRows(DesignExportRun.editing(options), formats: DesignExportArea.formats, showsSize: false) {
            ExportPick(format: $0.format.rawValue, scale: Double($0.scale))
        }
        #expect(rows.rows == [.format("svg")])
        #expect(options.scaleHelp != nil)
        try shoot(cards(), .editing(options), "design-export-sheet-svg")
    }

    @Test func running() throws {
        let options = DesignExportOptions(format: .png, scale: 1, scope: .page)
        try shoot(cards(), .running(options, done: 2, total: 3), "design-export-running")
    }

    @Test func finished() throws {
        let options = DesignExportOptions(format: .png, scale: 1, scope: .frame)
        #expect(DesignExportRun.finished(options, ["Desktop.png"]).summarized == .finished(options, ["1 file: Desktop.png."]))
        try shoot(cards(), .finished(options, ["Desktop.png"]), "design-export-finished")
    }

    @Test func failed() throws {
        let options = DesignExportOptions(format: .png, scale: 1, scope: .frame)
        try shoot(cards(), .failed(options, "Desktop.png couldn't be written."), "design-export-failed")
    }
}
