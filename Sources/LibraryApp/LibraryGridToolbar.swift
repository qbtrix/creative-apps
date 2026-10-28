// LibraryGridToolbar.swift: the one row over Library's photo grid (#3632):
// the collection's name and photo count, the thumbnail Size bar, the Sort
// menu, then Import Folder… and Export…. Every control is built from its
// command spec in `LibraryCatalog.catalog` (`commandIDs`), so it is enabled
// exactly when that command can run, its tooltip says why when it can't, and
// the CLI and MCP run the same commands; a click calls the window's route
// for the command (LibraryMenu), which runs the same LibraryAction. Built
// from SuiteUI's top bar pieces (EditorBarItem, EditorBarMenu with
// MenuCommand items, EditorBarDivider) and its bar slider
// (InspectorStepperRow); no single-key handling, so the grid keeps its keys.
// The row never asks for more than the content column: when the full row
// doesn't fit (the 880 pt window with both side columns open), it drops the
// photo count, draws Sort, Import and Export as symbols and shortens the Size
// bar, and the title truncates (LibraryGridHeaderFitTests).
// The filter bar's removable chips take the slot after the title once the
// filter model lands (filters-collections FC-4, FC-7); on dev it is a stub.
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct LibraryGridToolbar: View {
    let model: LibraryCatalog
    /// The window's menu; LibraryMenu() (every route nil) outside one.
    var menu = LibraryMenu()

    /// The catalog commands the row's controls are built from, in order.
    static let commandIDs = ["view.thumbnail-size", "view.sort", "file.import-folder", "file.export"]
    static let identifier = "library.grid.toolbar"

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(compact: false)
            row(compact: true)
        }
        .padding(.horizontal, SuiteSpacing.m)
        .padding(.vertical, SuiteSpacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Self.identifier)
    }

    /// The command spec `id` in Library's catalog, else one that refuses, saying Library has no such command.
    nonisolated static func spec(_ id: String) -> CommandSpec<LibraryCatalog> {
        LibraryCatalog.catalog.spec(id) ?? .typed(
            id, title: id, summary: "Library has no \(id) command.", kind: .view, params: JSONValue.self,
            example: .object([:]), availability: { _ in .unavailable("Library has no \(id) command.") }
        ) { _, _ in JSONValue.object([:]) }
    }

    /// The row; `compact` drops the count, draws the commands as symbols and shortens the Size bar.
    private func row(compact: Bool) -> some View {
        HStack(spacing: SuiteSpacing.s) {
            Text(model.selectedCollection?.name ?? "All Photos").font(SuiteFont.headline).lineLimit(1)
            if !compact {
                Text(LibraryCatalog.photoCountText(model.order.count))
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.textSecondary)
            }
            // The filter chips' slot (FC-4).
            Spacer(minLength: SuiteSpacing.s)
            sizeBar(width: compact ? SuiteSize.sidebarWidth.min : SuiteSize.inspectorWidth.ideal)
            EditorBarDivider()
            sortMenu(compact: compact)
            EditorBarDivider()
            EditorBarItem(importAction, showsTitle: !compact).libraryControl(importAction)
            EditorBarItem(exportAction, showsTitle: !compact).libraryControl(exportAction)
        }
    }

    /// view.thumbnail-size: the cell size in its steps, through the window's route.
    private func sizeBar(width: CGFloat) -> some View {
        let range = LibraryCatalog.cellSizeRange
        return InspectorStepperRow(
            "Size", value: Double(model.cellSize), in: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(LibraryCatalog.cellSizeStep), unit: "pt"
        ) { size in menu.view.setCellSize?(Int(size)) }
            .frame(width: width)
            .help(Self.spec("view.thumbnail-size").summary)
            .libraryControl(id: "library.grid.toolbar.size", enabled: true, help: nil)
    }

    /// view.sort: one item per order, the current one checked.
    private func sortMenu(compact: Bool) -> some View {
        let spec = Self.spec("view.sort"), why = spec.availability(model).why
        return EditorBarMenu(
            "Sort: \(model.sort.rawValue)", systemImage: "arrow.up.arrow.down",
            unavailableHelp: why.map { "\(spec.title): \($0)" }, showsTitle: !compact
        ) {
            ForEach(LibrarySort.allCases, id: \.self) { sort in
                MenuCommand(spec, on: model, title: sort.rawValue, systemImage: sort == model.sort ? "checkmark" : nil) {
                    menu.view.setSort?(sort)
                }
            }
        }
        .libraryControl(id: "library.grid.toolbar.sort", enabled: why == nil, help: why)
    }

    /// file.import-folder, through the import area's open panel.
    var importAction: ToolbarAction { action("file.import-folder", "folder.badge.plus", "library.grid.toolbar.import", menu.file.importFolder) }

    /// file.export, through the export area's sheet.
    var exportAction: ToolbarAction { action("file.export", "square.and.arrow.up", "library.grid.toolbar.export", menu.export.export) }

    private func action(_ id: String, _ symbol: String, _ identifier: String, _ route: LibraryMenu.Action?) -> ToolbarAction {
        ToolbarAction(Self.spec(id), on: model, systemImage: symbol, identifier: identifier, perform: route ?? {})
    }
}
