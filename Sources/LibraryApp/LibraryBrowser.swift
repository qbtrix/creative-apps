// LibraryBrowser.swift: the Library window's content: the import progress
// row while an import runs (shown 100 ms after it starts), the notice slot
// (the catalog file's problem, the last import's result with its failures
// and close button, or a refused cull change with its close button:
// `LibraryCatalog.notice`), the collections file's notice (set aside, a
// warning), then the photo grid (LibraryGrid), the loupe (LibraryLoupe), or an empty state.
// Values in, closures out; LibraryCatalog holds the state. The progress row
// is SuiteUI's BusyNote (`library.import.progress`, with the import's
// fraction); the import notice is a plain SwiftUI placeholder until SuiteUI's
// InlineNotice (#780) lands.
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
struct LibraryBrowser: View {
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
    /// How many times the content's body ran; RenderBudgetLibraryFoldersTests checks a folder's
    /// disclosure leaves it, and the grid under it, alone.
    @MainActor static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(spacing: 0) {
            if case .running(let progress) = model.importState {
                BusyNote(
                    progress.text, identifier: "library.import.progress",
                    fraction: (progress.done, progress.total), delay: importProgressDelay)
            }
            if let notice = model.notice {
                if notice.source == .import, let importNotice = model.importNotice {
                    LibraryImportNoticeRow(
                        notice: importNotice, onClose: menu.file.dismissImportNotice,
                        expanded: importFailuresExpanded || model.showsImportFailures,
                        onShowFailures: menu.file.showImportFailures, catalog: model)
                } else {
                    LibraryNoticeRow(
                        notice: notice, action: noticeAction(notice),
                        onClose: notice.source == .cull ? menu.cull.dismissCullError : nil, catalog: model)
                }
            }
            if let message = model.collectionsNotice {
                LibraryNoticeRow(notice: LibraryNoticeContent(message: message, isError: false, action: nil, source: .catalog))
            }
            // Fills the space under the notice, so the empty state stays centred.
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The notice's button: the closure of the area that owns its action; nil (no button) until it exists.
    private func noticeAction(_ notice: LibraryNoticeContent) -> ToolbarAction? {
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
            LibraryGrid(model: model, menu: menu, thumbnails: thumbnails, onSelect: onSelect, onOpen: onOpen)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .libraryShare(model, inset: true)
        }
    }
}

/// The notice slot's row: the message with an error or warning symbol, and
/// the source's action as its catalog command's item (CS-6) when it has one,
/// and Close when the source passes `onClose` (a refused cull change). A plain
/// placeholder until the import feature restyles it.
struct LibraryNoticeRow: View {
    static let closeHelp = "Close the notice."
    let notice: LibraryNoticeContent
    var action: ToolbarAction?
    var onClose: (@MainActor () -> Void)?
    /// The window's catalog, which the action's spec (`notice.action?.commandID`) reads; nil in a snapshot.
    var catalog: LibraryCatalog?

    var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            Label(notice.message, systemImage: notice.isError ? "exclamationmark.octagon" : "exclamationmark.triangle")
                .font(SuiteFont.caption)
                .foregroundStyle(notice.isError ? SuiteColor.stateError : SuiteColor.stateWarning)
                .lineLimit(2)
            Spacer(minLength: SuiteSpacing.s)
            if let action, let id = notice.action?.commandID {
                MenuCommand(id, on: catalog, title: action.title, action: action.perform, reason: action.help)
                    .libraryControl(id: "library.notice.action", enabled: true, help: nil)
            }
            if let onClose {
                Button("Close", systemImage: "xmark") { onClose() }
                    .labelStyle(.iconOnly)
                    .help(Self.closeHelp)
                    .libraryControl(id: "library.notice.close", enabled: true, help: nil)
            }
        }
        .padding(.horizontal, SuiteSpacing.m)
        .padding(.vertical, SuiteSpacing.s)
        .background(SuiteColor.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.notice")
    }
}

/// The last import's notice (`library.import.notice`): its message, in the
/// error style when `isError` and the warning style when some files failed;
/// Show, which lists each `name: reason` failure (`notice.show-failures`, the
/// window's, so the catalog holds whether they show); and Close, which calls the
/// import area's `onClose` (`dismissImportNotice()`), disabled with its
/// reason until the area passes one.
struct LibraryImportNoticeRow: View {
    static let identifier = "library.import.notice"
    static let closeUnavailable = "Closing the import notice isn't connected yet."
    let notice: ImportNotice
    let onClose: (@MainActor () -> Void)?
    /// Whether the failures are listed: the catalog's `showsImportFailures`, or a snapshot's choice.
    let expanded: Bool
    /// Show and Hide: the window's `notice.show-failures`, nil (off) until it passes one.
    let onShowFailures: (@MainActor () -> Void)?
    let catalog: LibraryCatalog?

    init(
        notice: ImportNotice, onClose: (@MainActor () -> Void)?, expanded: Bool = false,
        onShowFailures: (@MainActor () -> Void)? = nil, catalog: LibraryCatalog? = nil
    ) {
        (self.notice, self.onClose, self.expanded) = (notice, onClose, expanded)
        (self.onShowFailures, self.catalog) = (onShowFailures, catalog)
    }

    /// Each failure as `name: reason`, the name the file's last path component.
    var failureLines: [String] {
        notice.failures.map { "\($0.path.split(separator: "/").last.map(String.init) ?? $0.path): \($0.reason)" }
    }

    /// Error red, warning orange when some files failed, success green when
    /// photos came in, and secondary text when nothing new did.
    var tint: Color {
        if notice.isError { return SuiteColor.stateError }
        if !notice.failures.isEmpty { return SuiteColor.stateWarning }
        return notice.added > 0 ? SuiteColor.stateSuccess : SuiteColor.textSecondary
    }

    /// The state's shape cue, matching `tint`.
    var symbol: String {
        if notice.isError { return "exclamationmark.octagon" }
        if !notice.failures.isEmpty { return "exclamationmark.triangle" }
        return notice.added > 0 ? "checkmark.circle" : "info.circle"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            HStack(spacing: SuiteSpacing.s) {
                Label(notice.message, systemImage: symbol)
                    .font(SuiteFont.caption)
                    .foregroundStyle(tint)
                    .lineLimit(2)
                Spacer(minLength: SuiteSpacing.s)
                if !notice.failures.isEmpty {
                    MenuCommand("notice.show-failures", on: catalog, title: expanded ? "Hide" : "Show",
                                action: onShowFailures, reason: "Showing the failures isn't connected yet.")
                        .libraryControl(id: "library.import.notice.show", enabled: true, help: nil)
                }
                Button("Close", systemImage: "xmark") { onClose?() }
                    .labelStyle(.iconOnly)
                    .help(onClose == nil ? Self.closeUnavailable : "Close the import notice.")
                    .disabled(onClose == nil)
                    .libraryControl(
                        id: "library.import.notice.close", enabled: onClose != nil, help: Self.closeUnavailable)
            }
            if expanded {
                ForEach(Array(failureLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, SuiteSpacing.m)
        .padding(.vertical, SuiteSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SuiteColor.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Self.identifier)
    }
}
