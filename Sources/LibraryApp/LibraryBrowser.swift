// LibraryBrowser.swift: the Library window's content: the import progress
// row while an import runs (shown 100 ms after it starts), the notice slot
// (the catalog file's problem, the last import's result with its failures
// and close button, or a refused cull change with its close button:
// `LibraryCatalog.notice`), then
// the photo grid (LibraryGrid), the loupe (LibraryLoupe), or an empty state.
// Values in, closures out; LibraryCatalog holds the state. The progress row
// and the import notice are plain SwiftUI placeholders until SuiteUI's
// ProgressRow (#781) and InlineNotice (#780) land.
import LibraryModel
import SuiteUI
import SwiftUI

/// The notice row over the photo grid, or the empty state whose one button is
/// Import Folder… (disabled until import lands, its message then saying why and
/// pointing to File > Load Sample Photos; none for a newer catalog); an empty collection in a non-empty catalog gets an empty
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
    /// How long an import runs before its progress row shows (zero in snapshots).
    var importProgressDelay: Duration = .milliseconds(100)
    /// Whether the import notice opens with its failures listed (snapshots).
    var importFailuresExpanded = false

    /// Why Import Folder… can't act when neither the menu nor the services say.
    static let importFallbackHelp = "Import isn't connected yet."

    var body: some View {
        VStack(spacing: 0) {
            if case .running(let progress) = model.importState {
                LibraryImportProgressRow(progress: progress, delay: importProgressDelay)
            }
            if let notice = model.notice {
                if notice.source == .import, let importNotice = model.importNotice {
                    LibraryImportNoticeRow(
                        notice: importNotice, onClose: menu.file.dismissImportNotice,
                        expanded: importFailuresExpanded)
                } else {
                    LibraryNoticeRow(
                        notice: notice, action: noticeAction(notice),
                        onClose: notice.source == .cull ? menu.cull.dismissCullError : nil)
                }
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

    @ViewBuilder private var content: some View {
        if model.isEmpty {
            let empty = model.emptyState(importReason: importAction.unavailableHelp)
            if empty.offersImport {
                EmptyStateView(empty.title, systemImage: "photo.stack", message: empty.message, action: importAction)
                    .libraryControl(importAction)
            } else {
                EmptyStateView(empty.title, systemImage: "photo.stack", message: empty.message)
            }
        } else if model.isSelectedCollectionEmpty, let collection = model.selectedCollection {
            EmptyStateView(
                "No Photos in \(collection.name)", systemImage: "photo.stack", message: collection.emptyMessage,
                action: collection.emptyActionTitle.map {
                    ToolbarAction($0, systemImage: "photo.on.rectangle.angled", perform: onShowAll)
                })
        } else if model.loupeItem != nil {
            LibraryLoupe(model: model, menu: menu, onStep: onStep, onGrid: onGrid)
        } else {
            // Top-aligned, so a short grid (an import's first batch) starts under the rows above.
            LibraryGrid(model: model, menu: menu, onSelect: onSelect, onOpen: onOpen)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// The notice slot's row: the message with an error or warning symbol, and
/// the source's action as a button when it has one, and Close when the
/// source passes `onClose` (a refused cull change). A plain placeholder until
/// the import feature restyles it.
struct LibraryNoticeRow: View {
    static let closeHelp = "Close the notice."
    let notice: LibraryNoticeContent
    var action: ToolbarAction?
    var onClose: (@MainActor () -> Void)?

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

/// The import's progress row: "Importing 3 of 27" over a determinate bar,
/// `library.import.progress` with the text as its label and value (XCUITest
/// reads a SwiftUI value as "", so journeys read the label). It appears `delay`
/// after the import starts, so a quick import never flashes it.
struct LibraryImportProgressRow: View {
    static let identifier = "library.import.progress"
    let progress: ImportProgress
    let delay: Duration
    @State private var shown: Bool

    init(progress: ImportProgress, delay: Duration = .milliseconds(100)) {
        self.progress = progress
        self.delay = delay
        _shown = State(initialValue: delay <= .zero)
    }

    /// The row's text and its accessibility value.
    var value: String { progress.text }

    /// The row's accessibility label: the same text, which journeys read.
    var label: String { value }

    /// The bar's value and total: done of total, never past it, total at least 1.
    var fraction: (value: Double, total: Double) {
        let total = max(progress.total, 1)
        return (Double(min(max(progress.done, 0), total)), Double(total))
    }

    /// A ZStack, not a Group: its zero-height placeholder always exists, so
    /// the delay's `.task` runs even while the row is hidden (#1379).
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(height: CGFloat.zero)
            if shown {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    Text(value)
                        .font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.textSecondary)
                    ProgressView(value: fraction.value, total: fraction.total)
                        .progressViewStyle(.linear)
                }
                .padding(.horizontal, SuiteSpacing.m)
                .padding(.vertical, SuiteSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SuiteColor.panel)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(value)
                .accessibilityIdentifier(Self.identifier)
            }
        }
        .task {
            guard !shown else { return }
            try? await Task.sleep(for: delay)
            if !Task.isCancelled { shown = true }
        }
    }
}

/// The last import's notice (`library.import.notice`): its message, in the
/// error style when `isError` and the warning style when some files failed;
/// Show, which lists each `name: reason` failure; and Close, which calls the
/// import area's `onClose` (`dismissImportNotice()`), disabled with its
/// reason until the area passes one.
struct LibraryImportNoticeRow: View {
    static let identifier = "library.import.notice"
    static let closeUnavailable = "Closing the import notice isn't connected yet."
    let notice: ImportNotice
    let onClose: (@MainActor () -> Void)?
    @State private var expanded: Bool

    init(notice: ImportNotice, onClose: (@MainActor () -> Void)?, expanded: Bool = false) {
        self.notice = notice
        self.onClose = onClose
        _expanded = State(initialValue: expanded)
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
                    Button(expanded ? "Hide" : "Show") { expanded.toggle() }
                        .help(expanded ? "Hide the files that couldn't be imported." : "List the files that couldn't be imported.")
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
