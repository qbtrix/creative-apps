// HomeGrid.swift: the recents (blueprint suite.md 6.1): RECENT with the
// "Preview data" label on the fakes (a plain placeholder until SuiteUI has a
// standalone StatusPill, #1790), the app chips, a message in place
// (InlineNotice #780's placeholder), then the grid, the empty sentence with
// Open… prominent (while it waits, the sentence says why instead of inviting
// it, #1754), or the no-match sentence. "Missing" sits in a missing
// card's caption until ThumbnailBadges has its badge (#804); until then a
// caption carries the card's age and its tooltip the app. The recents take
// the height left between the New row and the running strip and clip to it
// (ThumbnailGrid scrolls itself live).
import SuiteModel
import SuiteUI
import SwiftUI

struct HomeGrid: View {
    let model: HomeModel
    /// Loaded thumbnails by `RecentItem.thumbnail`.
    let images: [String: Image]
    let isPreview: Bool
    let open: ToolbarAction

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            header
            ChipRow(chips) { model.filter(SuiteApp(rawValue: $0), now: Date()) }
                .suiteControl(id: "afterglow.home.filter", enabled: true, reason: nil, identifies: false)
            if let message = model.message { notice(message) }
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
            ChipItem(id: $0.rawValue, title: $0.displayName, systemImage: HomeSidebarRows.symbol($0),
                     isOn: model.filter == $0)
        }
    }

    /// HomeLayout's card widths in four steps (View > Larger and Smaller), at 4:3.
    private var cellSize: CGSize {
        let width = HomeLayout.cardMin + Double(model.thumbnailStep) * (HomeLayout.cardMax - HomeLayout.cardMin) / 3
        return CGSize(width: width, height: width * 3 / 4)
    }

    private func item(_ card: RecentCard) -> ThumbnailItem<String> { Self.item(card, images: images) }

    /// A card as a cell: its name and age, the app in the tooltip.
    static func item(_ card: RecentCard, images: [String: Image]) -> ThumbnailItem<String> {
        let name = card.item.ref.displayName
        return ThumbnailItem(
            id: card.item.ref.fileID, image: card.isMissing ? nil : card.item.thumbnail.flatMap { images[$0] },
            caption: card.isMissing ? "\(name) · Missing" : "\(name) · \(card.age)",
            accessibilityValue: card.isMissing ? "Missing, \(card.age)" : card.age,
            help: card.isMissing ? SuiteError.fileMissing(name: name).message
                : "\(name), \(card.item.ref.app.displayName), \(card.age)",
            isUnreadable: card.isMissing)
    }

    /// "Matching “logo” · 2" beside RECENT while a search is on; nil without one.
    static func matching(query: String, count: Int) -> String? {
        query.isEmpty ? nil : "Matching \u{201C}\(query)\u{201D} · \(count)"
    }

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
        HStack(spacing: SuiteSpacing.s) {
            Label { Text(message.message) } icon: {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(SuiteColor.stateWarning)
            }
            Spacer(minLength: SuiteSpacing.s)
            if !Self.noticeActions(message, hasSelection: model.selection != nil).isEmpty {
                if let ref = selectedRef {
                    Button("Locate…") { HomeInspector.locate(ref, model: model) }
                        .suiteControl(id: "afterglow.home.locate", enabled: true, reason: nil)
                }
                Button("Remove from Recents") { Task { await model.removeSelection(now: Date()) } }
                    .suiteControl(id: "afterglow.home.remove", enabled: true, reason: nil)
            }
        }
        .padding(SuiteInset.card)
        .background(SuiteColor.warningTint, in: RoundedRectangle(cornerRadius: SuiteRadius.control))
    }
}
