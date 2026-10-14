// ThumbnailGrid.swift: ThumbnailItem and ThumbnailGrid, a LazyVGrid of image
// thumbnails with adaptive columns for Library and any asset browser. Content,
// so flat: no glass. The app owns the selection and gets every change through
// `onSelectionChange`; the grid keeps only presentation state (click anchor,
// focus, width). The selection rules live in GridSelection, where they are
// tested. Snapshots drop the ScrollView, which ImageRenderer does not draw.
import AppKit
import SwiftUI

/// Small symbols over a thumbnail. `rating` is clamped to 0...5 stars. The
/// color label's `name` is its accessibility label, so color never carries
/// the meaning alone.
public struct ThumbnailBadges: Sendable {
    public let rating: Int
    public let isFlagged: Bool
    public let colorLabel: (name: String, color: Color)?

    public init(rating: Int = 0, isFlagged: Bool = false, colorLabel: (name: String, color: Color)? = nil) {
        self.rating = min(max(rating, 0), 5)
        self.isFlagged = isFlagged
        self.colorLabel = colorLabel
    }
}

public struct ThumbnailItem<ID: Hashable>: Identifiable {
    public let id: ID
    /// The thumbnail; nil draws a flat cell with the `photo` symbol.
    public let image: Image?
    public let caption: String
    public let badges: ThumbnailBadges

    public init(id: ID, image: Image? = nil, caption: String, badges: ThumbnailBadges = ThumbnailBadges()) {
        self.id = id
        self.image = image
        self.caption = caption
        self.badges = badges
    }
}

public struct ThumbnailGrid<ID: Hashable>: View {
    private let items: [ThumbnailItem<ID>]
    private let cellSize: CGSize
    private let selection: Set<ID>
    private let onSelectionChange: @MainActor (Set<ID>) -> Void
    private let onOpen: @MainActor (ID) -> Void
    @State private var anchor: ID?
    @State private var width: CGFloat = 0
    @FocusState private var focused: Bool
    @Environment(\.suiteSnapshotRendering) private var snapshot

    /// Click selects, Command-click toggles, Shift-click selects a range in
    /// display order, arrow keys move; each reports the new set through
    /// `onSelectionChange`. Double-click or Return calls `onOpen`.
    public init(
        _ items: [ThumbnailItem<ID>], cellSize: CGSize, selection: Set<ID>,
        onSelectionChange: @escaping @MainActor (Set<ID>) -> Void,
        onOpen: @escaping @MainActor (ID) -> Void = { _ in }
    ) {
        self.items = items
        self.cellSize = cellSize
        self.selection = selection
        self.onSelectionChange = onSelectionChange
        self.onOpen = onOpen
    }

    public var body: some View {
        if snapshot {
            grid
        } else {
            ScrollViewReader { proxy in
                ScrollView { grid }.onChange(of: anchor) { _, id in if let id { proxy.scrollTo(id) } }
            }
        }
    }

    /// The image plus the cell's padding on both sides.
    private var columnWidth: CGFloat { cellSize.width + SuiteSpacing.xs * 2 }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: SuiteSpacing.m)], spacing: SuiteSpacing.m) {
            ForEach(items) { item in
                ThumbnailCell(item: item, size: cellSize, isSelected: selection.contains(item.id))
                    .id(item.id)
                    .contentShape(.rect)
                    .onTapGesture { click(item.id, kind: Self.clickKind()) }
                    .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen(item.id) })
                    .accessibilityAction { click(item.id, kind: .plain) }
                    .accessibilityAction(named: "Open") { onOpen(item.id) }
            }
        }
        .padding(SuiteSpacing.m)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { move(.left) }
        .onKeyPress(.rightArrow) { move(.right) }
        .onKeyPress(.upArrow) { move(.up) }
        .onKeyPress(.downArrow) { move(.down) }
        .onKeyPress(.return) {
            if let id = currentAnchor { onOpen(id) }
            return currentAnchor == nil ? .ignored : .handled
        }
    }

    private var order: [ID] { items.map(\.id) }

    /// The anchor while it is still selected; otherwise the first selected
    /// item in display order, so a selection the app changed still anchors.
    private var currentAnchor: ID? {
        if let anchor, selection.contains(anchor) { return anchor }
        return order.first(where: selection.contains)
    }

    private static func clickKind() -> GridSelection.Click {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) { return .extend }
        return flags.contains(.command) ? .toggle : .plain
    }

    private func click(_ id: ID, kind: GridSelection.Click) {
        focused = true
        apply(GridSelection.click(id, kind, order: order, selection: selection, anchor: currentAnchor))
    }

    private func move(_ direction: GridSelection.Direction) -> KeyPress.Result {
        let columns = GridSelection.columns(
            width: Double(width - SuiteSpacing.m * 2), minimum: Double(columnWidth), spacing: Double(SuiteSpacing.m))
        apply(GridSelection.move(direction, order: order, columns: columns, anchor: currentAnchor))
        return .handled
    }

    private func apply(_ result: GridSelection.Result<ID>) {
        anchor = result.anchor
        if result.selection != selection { onSelectionChange(result.selection) }
    }
}

/// One thumbnail: the image (or a flat placeholder) with its badges, and the
/// caption under it. Selection is a neutral rounded plate (`valueFill`) behind
/// and around the image and caption, plus the caption in `accentText`. The
/// plate's contrast comes from the grid around it, not from the image, so a
/// blue or teal photo can't hide it; the image keeps its plain hairline.
private struct ThumbnailCell<ID: Hashable>: View {
    let item: ThumbnailItem<ID>
    let size: CGSize
    let isSelected: Bool

    var body: some View {
        VStack(spacing: SuiteSpacing.xs) {
            thumbnail
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.small))
                .overlay(alignment: .bottomLeading) { badges }
                .overlay(RoundedRectangle(cornerRadius: SuiteRadius.small).strokeBorder(SuiteColor.separator, lineWidth: 1))
            Text(item.caption)
                .font(SuiteFont.caption)
                .foregroundStyle(isSelected ? SuiteColor.accentText : SuiteColor.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: size.width)
        }
        .padding(SuiteSpacing.xs)
        .background(isSelected ? SuiteColor.valueFill : .clear, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .help(item.caption)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = item.image {
            image.resizable().scaledToFill()
        } else {
            SuiteColor.surface.overlay {
                Image(systemName: "photo")
                    .font(SuiteFont.title)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var badges: some View {
        let marks = item.badges
        if marks.rating > 0 || marks.isFlagged || marks.colorLabel != nil {
            HStack(spacing: SuiteSpacing.xxs) {
                if marks.rating > 0 {
                    HStack(spacing: 0) {
                        ForEach(0..<marks.rating, id: \.self) { _ in Image(systemName: "star.fill") }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: marks.rating == 1 ? "1 star" : "\(marks.rating) stars"))
                }
                if marks.isFlagged { Image(systemName: "flag.fill").accessibilityLabel("Flagged") }
                if let label = marks.colorLabel {
                    Image(systemName: "circle.fill").foregroundStyle(label.color).accessibilityLabel(label.name)
                }
            }
            .font(SuiteFont.caption)
            .imageScale(.small)
            .padding(.horizontal, SuiteSpacing.xs)
            .padding(.vertical, SuiteSpacing.xxs)
            .background(SuiteColor.surface.opacity(0.9), in: Capsule())
            .padding(SuiteSpacing.xs)
        }
    }
}
