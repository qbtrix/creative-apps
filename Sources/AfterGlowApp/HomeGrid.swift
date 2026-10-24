// HomeGrid.swift: the recents (blueprint suite.md 6.1): RECENT with the
// "Preview data" label on the fakes (a plain placeholder until SuiteUI has a
// standalone StatusPill, #1790), the app chips, a message in place
// (InlineNotice #780's placeholder: the missing file, or the removed one with
// Undo), then the grid, the empty sentence with
// Open… prominent (while it waits, the sentence says why instead of inviting
// it, #1754), or the no-match sentence. "Missing" sits in a missing
// card's caption until ThumbnailBadges has its badge (#804); until then a
// caption carries the card's age and its tooltip the app. The recents take
// the height left between the New row and the running strip and clip to it
// (ThumbnailGrid scrolls itself live). Each card shows its document's
// published preview, asked once through HomePreviews when the cards change
// and kept for the window's life; a document without one shows its app's mark
// (shared-thumbnails ST-3).
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI

struct HomeGrid: View {
    let model: HomeModel
    /// Loaded thumbnails by `RecentItem.thumbnail`.
    let images: [String: Image]
    let isPreview: Bool
    let open: ToolbarAction
    /// A test passes previews it loaded; the window keeps its own.
    var loaded: HomePreviews<Image>? = nil
    @State private var own = HomeGrid.previews()
    private var previews: HomePreviews<Image> { loaded ?? own }

    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            header
            ChipRow(chips) { model.filter(SuiteApp(rawValue: $0), now: Date()) }
                .suiteControl(id: "afterglow.home.filter", enabled: true, reason: nil, identifies: false)
            if let message = model.message {
                notice(message)
            } else if let removed = model.removedNotice {
                removedNotice(removed)
            }
            if !model.state.cards.isEmpty {
                ThumbnailGrid(
                    model.state.cards.map(item), cellSize: cellSize, selection: Set(model.selection.map { [$0] } ?? []),
                    onSelectionChange: { model.select($0.first) },
                    onOpen: { id in model.select(id); Task { await model.openSelection(now: Date()) } },
                    cellIdentifierPrefix: "afterglow.home.card.")
            } else if model.message == nil { empty }
        }
        .frame(maxWidth: .infinity, minHeight: .zero, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .task(id: model.state.cards.map(\.item.ref.fileID)) {
            await previews.load(model.state.cards.map(\.item.ref), from: model.thumbnails)
        }
    }

    private var header: some View {
        HStack(spacing: SuiteSpacing.s) {
            Text("Recent").font(SuiteFont.sectionCaps).textCase(.uppercase).tracking(SuiteSize.capsTracking)
                .foregroundStyle(SuiteColor.textSecondary)
            if let matching = Self.matching(query: model.query, count: model.state.cards.count) {
                Text(matching).font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
                    .accessibilityIdentifier("afterglow.home.matching")
            }
            Spacer(minLength: SuiteSpacing.s)
            if isPreview {
                Label("Preview data", systemImage: "exclamationmark.triangle")
                    .font(SuiteFont.caption).foregroundStyle(SuiteColor.stateWarning)
                    .help("This window shows built-in sample data, not your recent work.")
                    .accessibilityIdentifier("afterglow.home.preview")
            }
        }
    }

    /// All, then one chip per app; the ids are "all" and each app's raw value.
    private var chips: [ChipItem<String>] {
        [ChipItem(id: "all", title: "All", isOn: model.filter == nil)] + SuiteApp.apps.map {
            ChipItem(id: $0.rawValue, title: $0.displayName, app: $0, isOn: model.filter == $0)
        }
    }

    /// HomeLayout's card widths in four steps (View > Larger and Smaller), at 4:3.
    private var cellSize: CGSize {
        let width = HomeLayout.cardMin + Double(model.thumbnailStep) * (HomeLayout.cardMax - HomeLayout.cardMin) / 3
        return CGSize(width: width, height: width * 3 / 4)
    }

    private func item(_ card: RecentCard) -> ThumbnailItem<String> { Self.item(card, images: images, previews: previews) }

    /// A card as a cell: its name and age, the app in the tooltip. With `previews`, its published
    /// preview, else its own thumbnail, else the app's mark once the preview answered nil; the
    /// accessibility value then says which ("Today, preview" or "Today, app mark").
    static func item(_ card: RecentCard, images: [String: Image], previews: HomePreviews<Image>? = nil) -> ThumbnailItem<String> {
        let name = card.item.ref.displayName
        let own = card.item.thumbnail.flatMap { images[$0] }
        let shown = previews.map { $0.picture(for: card.item.ref, fallback: own) } ?? own
        let kind = previews?.kind(for: card.item.ref) ?? .waiting
        let said = kind == .preview ? ", preview" : kind == .mark && own == nil ? ", app mark" : ""
        return ThumbnailItem(
            id: card.item.ref.fileID, image: card.isMissing ? nil : shown,
            caption: card.isMissing ? "\(name) · Missing" : "\(name) · \(card.age)",
            accessibilityValue: card.isMissing ? "Missing, \(card.age)" : card.age + said,
            help: card.isMissing ? SuiteError.fileMissing(name: name).message
                : "\(name), \(card.item.ref.app.displayName), \(card.age)",
            isUnreadable: card.isMissing)
    }

    /// The window's previews: PNG bytes through NSImage, the app's mark drawn once per app.
    // view-static: main-actor
    static func previews() -> HomePreviews<Image> {
        HomePreviews(decode: { NSImage(data: $0).map { Image(nsImage: $0) } }, mark: mark)
    }

    /// The app's mark (SuiteUI AppMark, never a symbol) centred at half the card's height on a
    /// clear 4:3 card, rendered once so a card draws it as any other picture.
    // view-static: main-actor
    static func mark(_ app: SuiteApp) -> Image? {
        let width = HomeLayout.cardMax, height = HomeLayout.cardMax * 3 / 4
        let renderer = ImageRenderer(content: AppMark(app: app, style: .icon)
            .frame(width: height / 2, height: height / 2)
            .frame(width: width, height: height))
        return renderer.nsImage.map { Image(nsImage: $0) }
    }

    /// "2 items matching “logo”" beside RECENT while a search is on; nil without one (HomeModel's, #1866).
    static func matching(query: String, count: Int) -> String? { HomeModel.matching(query: query, count: count) }

    /// The empty state's text: the model's sentence, saying why Open… waits while it can't act.
    static func emptyMessage(_ model: HomeModel, open: ToolbarAction) -> String {
        HomeBuilder.emptyMessage(model.state.emptyMessage, openReason: open.unavailableHelp) ?? ""
    }

    /// The notice's buttons: Locate… then Remove from Recents for a missing
    /// selected file; none otherwise.
    static func noticeActions(_ message: SuiteError, hasSelection: Bool) -> [String] {
        guard case .fileMissing = message, hasSelection else { return [] }
        return ["afterglow.home.locate", "afterglow.home.remove"]
    }

    private var selectedRef: SuiteDocumentRef? {
        model.selection.flatMap { id in model.state.cards.first { $0.item.ref.fileID == id } }?.item.ref
    }

    @ViewBuilder private var empty: some View {
        if model.query.isEmpty && model.filter == nil {
            EmptyStateView("No Recent Work", systemImage: "clock", message: Self.emptyMessage(model, open: open), action: open)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .homeLayoutAnchor("empty")
        } else {
            EmptyStateView("No Results", systemImage: "magnifyingglass", message: model.state.emptyMessage ?? "")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .homeLayoutAnchor("empty")
        }
    }

    private func notice(_ message: SuiteError) -> some View {
        noticeRow(message.message, systemImage: "exclamationmark.triangle", color: SuiteColor.stateWarning) {
            if !Self.noticeActions(message, hasSelection: model.selection != nil).isEmpty {
                if let ref = selectedRef {
                    Button("Locate…") { HomeInspector.locate(ref, model: model) }
                        .suiteControl(id: "afterglow.home.locate", enabled: true, reason: nil)
                }
                Button("Remove from Recents") { Task { await model.removeSelection(now: Date()) } }
                    .suiteControl(id: "afterglow.home.remove", enabled: true, reason: nil)
            }
        }
    }

    /// After Remove from Recents (#1865): says which file went, with Undo beside it.
    private func removedNotice(_ text: String) -> some View {
        noticeRow(text, systemImage: "trash", color: SuiteColor.textSecondary) {
            Button("Undo") { Task { await model.undoRemove(now: Date()) } }
                .suiteControl(id: "afterglow.home.undo-remove", enabled: true, reason: nil)
        }
    }

    /// InlineNotice #780's placeholder, as Library's notice row draws it (#1871):
    /// a caption-sized label in the state color and its buttons, no tinted fill.
    private func noticeRow<Actions: View>(_ text: String, systemImage: String, color: Color,
                                          @ViewBuilder actions: () -> Actions) -> some View {
        HStack(spacing: SuiteSpacing.s) {
            Label(text, systemImage: systemImage).font(SuiteFont.caption).foregroundStyle(color).lineLimit(2)
            Spacer(minLength: SuiteSpacing.s)
            actions()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("afterglow.home.notice")
    }
}
