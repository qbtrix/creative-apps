// LibraryBrowser.swift: the Library window's content: the notice slot on top
// (the catalog file's problem, the last import's result or a refused cull
// change: `LibraryCatalog.notice`), then the photo grid (LibraryGrid), the
// loupe (LibraryLoupe), or an empty state. Values in, closures out;
// LibraryCatalog holds the state.
import LibraryModel
import SuiteUI
import SwiftUI

/// The notice row over the photo grid, or the empty state whose one button is
/// Import Folder… (disabled, saying why, until import lands; Load Sample
/// Photos stays in File); an empty collection in a non-empty catalog gets an empty
/// state that says how to fill it, with a button back to All Photos. In loupe
/// mode it shows the loupe's photo (LibraryLoupe) instead of the grid.
struct LibraryBrowser: View {
    let model: LibraryCatalog
    /// The window's menu (LibraryMenu.disabled outside one), passed to the grid and the loupe.
    var menu = LibraryMenu()
    var onSelect: @MainActor (Set<String>) -> Void = { _ in }
    var onOpen: @MainActor (String) -> Void = { _ in }
    var onShowAll: @MainActor () -> Void = {}
    var onStep: @MainActor (Int) -> Void = { _ in }
    var onGrid: @MainActor () -> Void = {}

    /// Why Import Folder… can't act when neither the menu nor the services say.
    static let importFallbackHelp = "Import isn't connected yet."

    var body: some View {
        VStack(spacing: 0) {
            if let notice = model.notice {
                LibraryNoticeRow(notice: notice, action: noticeAction(notice))
            }
            content
        }
    }

    /// The notice's button: the closure of the area that owns its action; nil (no button) until it exists.
    private func noticeAction(_ notice: LibraryNoticeContent) -> ToolbarAction? {
        switch notice.action {
        case .showCatalogInFinder:
            menu.persist.showCatalogInFinder.map { ToolbarAction("Show in Finder", systemImage: "folder", perform: $0) }
        case .showFailures:
            menu.file.showImportFailures.map { ToolbarAction("Show Failures", systemImage: "list.bullet", perform: $0) }
        case nil:
            nil
        }
    }

    /// Import Folder… (`library.import`), disabled with its reason while the import area's action is nil.
    private var importAction: ToolbarAction {
        let action = menu.file.importFolder
        let reason = menu.file.importHelp ?? model.help(for: "importer") ?? Self.importFallbackHelp
        return ToolbarAction(
            "Import Folder…", systemImage: "folder.badge.plus", unavailableHelp: action == nil ? reason : nil,
            identifier: "library.import", perform: action ?? {})
    }

    @ViewBuilder private var content: some View {
        if model.isEmpty {
            EmptyStateView(
                "No Photos", systemImage: "photo.stack",
                message: "Photos you import appear here, sorted by the date they were taken.",
                action: importAction)
                .libraryControl(importAction)
        } else if model.isSelectedCollectionEmpty, let collection = model.selectedCollection {
            EmptyStateView(
                "No Photos in \(collection.name)", systemImage: "photo.stack", message: collection.emptyMessage,
                action: collection.emptyActionTitle.map {
                    ToolbarAction($0, systemImage: "photo.on.rectangle.angled", perform: onShowAll)
                })
        } else if let photo = model.loupeItem, let position = model.loupePosition {
            LibraryLoupe(photo: photo, position: position, menu: menu, value: model.loupeValue, cropDraft: model.cropDraft, onStep: onStep, onGrid: onGrid)
        } else {
            LibraryGrid(model: model, menu: menu, onSelect: onSelect, onOpen: onOpen)
        }
    }
}

/// The notice slot's row: the message with an error or warning symbol, and
/// the source's action as a button when it has one. A plain placeholder until
/// the import feature restyles it.
struct LibraryNoticeRow: View {
    let notice: LibraryNoticeContent
    var action: ToolbarAction?

    var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            Label(notice.message, systemImage: notice.isError ? "exclamationmark.octagon" : "exclamationmark.triangle")
                .font(SuiteFont.caption)
                .foregroundStyle(notice.isError ? SuiteColor.stateError : SuiteColor.stateWarning)
                .lineLimit(2)
            Spacer(minLength: SuiteSpacing.s)
            if let action {
                Button(action.title, action: action.perform)
                    .help(action.help)
                    .libraryControl(id: "library.notice.action", enabled: true, help: nil)
            }
        }
        .padding(.horizontal, SuiteSpacing.m)
        .padding(.vertical, SuiteSpacing.s)
        .background(SuiteColor.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.notice")
    }
}
