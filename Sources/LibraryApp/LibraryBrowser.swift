// LibraryBrowser.swift: the Library window's content: the import progress
// row while an import runs (shown 100 ms after it starts), the notice slot
// (the catalog file's problem, the last import's result with its failures
// and close button, or a refused cull change with its close button:
// `LibraryCatalog.notice`), the collections file's notice (set aside, a
// warning), then the photo grid (LibraryGrid), the loupe (LibraryLoupe), or an empty state.
// Values in, closures out; LibraryCatalog holds the state. The progress row
// is SuiteUI's BusyNote (`library.import.progress`, with the import's
// fraction); every notice is SuiteUI's InlineNotice.
// The grid has its toolbar row (LibraryGridToolbar) above it.
import LibraryModel
import SuiteUI
import SwiftUI

/// The notice row over the photo grid, or the empty state whose one button is
/// Import Folder… (disabled until import lands, its message then saying why and
/// pointing to File > Load Sample Photos; none for a newer catalog), beside Try
/// Sample Photos, and that takes a dropped folder as an import; an empty collection in a non-empty catalog gets an empty
/// state that says how to fill it, with a button back to All Photos; a filter
/// that hides every photo of the collection gets No Matching Photos with Clear
/// Filter (`library.filter.empty.clear`). In loupe
/// mode it shows the loupe's photo (LibraryLoupe) instead of the grid.
struct LibraryBrowser: View, BodyCounted {
    let model: LibraryCatalog
    /// The window's menu (LibraryMenu.disabled outside one), passed to the grid and the loupe.
    var menu = LibraryMenu()
    /// The window's held thumbnails, passed to the grid; nil shows the catalog's own.
    var thumbnails: LibraryThumbnailStore? = nil
    var onSelect: @MainActor (Set<String>) -> Void = { _ in }
    var onOpen: @MainActor (String) -> Void = { _ in }
    var onShowAll: @MainActor () -> Void = {}
    var onStep: @MainActor (Int) -> Void = { _ in }
    var onGrid: @MainActor () -> Void = {}
    /// The window's filter and collection actions; Clear Filter in No Matching Photos.
    var filters = LibraryFiltersMenu()
    /// How long an import runs before its progress row shows (zero in snapshots).
    var importProgressDelay: Duration = .milliseconds(100)
    /// Whether the import notice opens with its failures listed (snapshots).
    var importFailuresExpanded = false

    /// Why Import Folder… can't act when neither the menu nor the services say.
    static let importFallbackHelp = "Import isn't connected yet."

    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(spacing: 0) {
            if case .running(let progress) = model.importState {
                BusyNote(
                    progress.text, identifier: "library.import.progress",
                    fraction: (progress.done, progress.total), delay: importProgressDelay)
            }
            if let notice = model.notice {
                if notice.source == .import, let importNotice = model.importNotice {
                    importNoticeRow(importNotice)
                } else {
                    noticeRow(notice)
                }
            }
            if let message = model.backup.notice {
                let close = menu.persist.dismissBackupNotice.map {
                    ToolbarAction("Close", systemImage: "xmark", identifier: "library.notice.close", perform: $0)
                }
                InlineNotice(message, kind: .warning, identifier: Self.noticeID, close: close)
                    .transformPreference(LibraryControlsKey.self) { if let entry = close?.controlEntry() { $0.append(entry) } }
            }
            if let message = model.collectionsNotice {
                InlineNotice(message, kind: .warning, identifier: Self.noticeID)
            }
            // Fills the space under the notice, so the empty state stays centred.
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The notice's button: the closure of the area that owns its action; nil (no button) until it exists.
    func noticeAction(_ notice: LibraryNoticeContent) -> ToolbarAction? {
        switch notice.action {
        case .showCatalogInFinder:
            menu.persist.showCatalogInFinder.map { ToolbarAction("Show in Finder", systemImage: "folder", perform: $0) }
        case .showFailures:
            menu.file.showImportFailures.map { ToolbarAction("Show Failures", systemImage: "list.bullet", perform: $0) }
        case .importFolder:
            menu.file.importFolder.map { ToolbarAction("Import Folder…", systemImage: "folder.badge.plus", perform: $0) }
        case nil:
            nil
        }
    }

    /// Import Folder… (`library.import`), disabled with its reason while the import area's action is nil.
    var importAction: ToolbarAction {
        let action = menu.file.importFolder
        let reason = menu.file.importHelp ?? model.help(for: "importer") ?? Self.importFallbackHelp
        return ToolbarAction(
            "Import Folder…", systemImage: "folder.badge.plus", unavailableHelp: action == nil ? reason : nil,
            identifier: "library.import", perform: action ?? {})
    }

    /// Clear Filter in No Matching Photos, disabled with its reason while it can't act.
    var clearFilterAction: ToolbarAction {
        let reason = filters.clearFilterHelp ?? filters.filterHelp ?? LibraryFilter.unavailable ?? "No filter is on."
        return ToolbarAction(
            "Clear Filter", systemImage: "xmark.circle", unavailableHelp: filters.clearFilter == nil ? reason : nil,
            identifier: "library.filter.empty.clear", perform: filters.clearFilter ?? {})
    }

    /// Why Try Sample Photos can't act when the catalog doesn't say.
    static let samplesFallbackHelp = "Sample photos aren't available here."

    /// Try Sample Photos (`library.samples`): File > Load Sample Photos as the empty catalog's
    /// second way in, disabled with its reason while it can't run.
    var samplesAction: ToolbarAction {
        let action = menu.edit.loadSamples
        let reason = model.help(.loadSamples) ?? Self.samplesFallbackHelp
        return ToolbarAction(
            "Try Sample Photos", systemImage: "photo.badge.plus", unavailableHelp: action == nil ? reason : nil,
            identifier: "library.samples", perform: action ?? {})
    }

    /// A drop on the empty catalog imports its first folder; refused while import can't run or nothing dropped is a folder.
    private func dropFolder(_ urls: [URL]) -> Bool {
        guard let importDropped = menu.file.importDropped,
              let folder = LibraryCatalog.droppedFolder(urls.map(\.path)) else { return false }
        importDropped(folder)
        return true
    }

    @ViewBuilder private var content: some View {
        if model.showsEmptyState {
            let empty = model.emptyState(importReason: importAction.unavailableHelp)
            if empty.offersImport {
                EmptyStateView(
                    empty.title, systemImage: "photo.stack", message: empty.message, action: importAction,
                    secondary: samplesAction, onDrop: dropFolder
                )
                .libraryControl(importAction)
                .libraryControl(samplesAction)
            } else {
                EmptyStateView(empty.title, systemImage: "photo.stack", message: empty.message)
            }
        } else if model.isEmpty {
            // The launch read is running: blank until the catalog appears, no "No Photos" flash.
            Color.clear
        } else if model.isHiddenByFilter {
            EmptyStateView(
                "No Matching Photos", systemImage: "line.3.horizontal.decrease.circle",
                message: model.filterEmptyMessage, action: clearFilterAction)
                .libraryControl(clearFilterAction)
        } else if model.isSelectedCollectionEmpty, let collection = model.selectedCollection {
            EmptyStateView(
                "No Photos in \(collection.name)", systemImage: "photo.stack", message: collection.emptyMessage,
                action: collection.emptyActionTitle.map {
                    ToolbarAction($0, systemImage: "photo.on.rectangle.angled", perform: onShowAll)
                })
        } else if model.loupeItem != nil {
            LibraryLoupe(model: model, menu: menu, onStep: onStep, onGrid: onGrid)
                .libraryShare(model)
        } else {
            // Top-aligned, so a short grid (an import's first batch) starts under the rows above.
            // Share ends the toolbar row, so it covers no photo and no toolbar control.
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    LibraryGridToolbar(model: model, menu: menu)
                    LibrarySharePill(model: model).padding(.trailing, SuiteSpacing.m)
                }
                LibraryGrid(model: model, menu: menu, thumbnails: thumbnails, onSelect: onSelect, onOpen: onOpen)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// The notice slot's rows, both SuiteUI's InlineNotice: the last import's
/// (`library.import.notice`) with Show, which lists each `name: reason`
/// failure (`notice.show-failures`, the window's, so the catalog holds whether
/// they show), and Close, disabled with its reason until the import area
/// passes `dismissImportNotice`; and any other notice (`library.notice`) with
/// its source's action as its catalog command's item (CS-6) and, for a refused
/// cull change, Close.
extension LibraryBrowser {
    static let noticeID = "library.notice"
    static let importNoticeID = "library.import.notice"
    static let importCloseUnavailable = "Closing the import notice isn't connected yet."

    /// An error; a warning when some files failed; success when photos came in; info when nothing new did.
    nonisolated static func noticeKind(_ notice: ImportNotice) -> NoticeKind {
        if notice.isError { return .error }
        if !notice.failures.isEmpty { return .warning }
        return notice.added > 0 ? .success : .info
    }

    /// Each failure as `name: reason`, the name the file's last path component.
    nonisolated static func failureLines(_ notice: ImportNotice) -> [String] {
        notice.failures.map { "\($0.path.split(separator: "/").last.map(String.init) ?? $0.path): \($0.reason)" }
    }

    /// The import notice's Close: the import area's `dismissImportNotice`, disabled with its reason until it exists.
    var importClose: ToolbarAction {
        let dismiss = menu.file.dismissImportNotice
        return ToolbarAction(
            "Close", systemImage: "xmark", unavailableHelp: dismiss == nil ? Self.importCloseUnavailable : nil,
            identifier: "library.import.notice.close", perform: dismiss ?? {})
    }

    /// A refused cull change's Close (`dismissCullError`); nil for any other notice or while the cull area has none.
    func noticeClose(_ notice: LibraryNoticeContent) -> ToolbarAction? {
        guard notice.source == .cull, let dismiss = menu.cull.dismissCullError else { return nil }
        return ToolbarAction("Close", systemImage: "xmark", identifier: "library.notice.close", perform: dismiss)
    }

    func importNoticeRow(_ notice: ImportNotice) -> some View {
        let expanded = importFailuresExpanded || model.showsImportFailures
        return InlineNotice(
            notice.message, kind: Self.noticeKind(notice), identifier: Self.importNoticeID, close: importClose,
            detail: expanded ? Self.failureLines(notice) : []
        ) {
            if !notice.failures.isEmpty {
                MenuCommand("notice.show-failures", on: model, title: expanded ? "Hide" : "Show",
                            action: menu.file.showImportFailures, reason: "Showing the failures isn't connected yet.")
                    .libraryControl(id: "library.import.notice.show", enabled: true, help: nil)
            }
        }
        .libraryControl(importClose)
    }

    func noticeRow(_ notice: LibraryNoticeContent) -> some View {
        let close = noticeClose(notice)
        return InlineNotice(
            notice.message, kind: notice.isError ? .error : .warning, identifier: Self.noticeID, close: close
        ) {
            if let action = noticeAction(notice), let id = notice.action?.commandID {
                MenuCommand(id, on: model, title: action.title, action: action.perform, reason: action.help)
                    .libraryControl(id: "library.notice.action", enabled: true, help: nil)
            }
        }
        .transformPreference(LibraryControlsKey.self) { if let entry = close?.controlEntry() { $0.append(entry) } }
    }
}
