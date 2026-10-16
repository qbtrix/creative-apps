// ThumbnailGrid.swift: ThumbnailItem and ThumbnailGrid, a LazyVGrid of image
// thumbnails with adaptive columns for Library and any asset browser. Content,
// so flat: no glass. The app owns the selection and gets every change through
// `onSelectionChange`; the grid keeps only presentation state (click anchor,
// focus, width, the cells on screen). The selection rules live in
// GridSelection, where they are tested. Each cell is one accessibility
// element carrying the app's value, help and `<prefix><id>` identifier (ids go
// on that leaf, never on the grid), and `onVisibleChange` reports the cells on
// screen so the app can load only those thumbnails. Images aspect-fit inside
// the cell; a reject is dimmed with a badge and an unreadable file shows a
// warning mark. Snapshots drop the ScrollView, which ImageRenderer does not draw.
import AppKit
import SwiftUI

/// Small symbols over a thumbnail. `rating` is clamped to 0...5 stars. The
/// color label's `name` is its accessibility label, so color never carries
/// the meaning alone. `dimmed` (a reject) draws the image at 40% with an
/// `xmark.circle` badge labelled "Rejected".
public struct ThumbnailBadges: Sendable {
    public let rating: Int
    public let isFlagged: Bool
    public let colorLabel: (name: String, color: Color)?
    public let dimmed: Bool

    public init(
        rating: Int = 0, isFlagged: Bool = false, colorLabel: (name: String, color: Color)? = nil, dimmed: Bool = false
    ) {
        self.rating = min(max(rating, 0), 5)
        self.isFlagged = isFlagged
        self.colorLabel = colorLabel
        self.dimmed = dimmed
    }
}

public struct ThumbnailItem<ID: Hashable>: Identifiable {
    public let id: ID
    /// The thumbnail; nil draws a flat cell with the `photo` symbol.
    public let image: Image?
    public let caption: String
    public let badges: ThumbnailBadges
    /// The cell's accessibility value, such as "ready 256×171 3 stars".
    public let accessibilityValue: String?
    /// The cell's tooltip; nil shows the caption.
    public let help: String?
    /// The file can't be read: a warning triangle over the placeholder fill.
    public let isUnreadable: Bool

    public init(
        id: ID, image: Image? = nil, caption: String, badges: ThumbnailBadges = ThumbnailBadges(),
        accessibilityValue: String? = nil, help: String? = nil, isUnreadable: Bool = false
    ) {
        self.id = id
        self.image = image
        self.caption = caption
        self.badges = badges
        self.accessibilityValue = accessibilityValue
        self.help = help
        self.isUnreadable = isUnreadable
    }
}

public struct ThumbnailGrid<ID: Hashable>: View {
    private let items: [ThumbnailItem<ID>]
    private let cellSize: CGSize
    private let selection: Set<ID>
    private let onSelectionChange: @MainActor (Set<ID>) -> Void
    private let onOpen: @MainActor (ID) -> Void
    private let cellIdentifierPrefix: String?
    private let onVisibleChange: @MainActor ([ID]) -> Void
    @State private var anchor: ID?
    @State private var visible = Set<ID>()
    @State private var width: CGFloat = 0
    @FocusState private var focused: Bool
    @Environment(\.suiteSnapshotRendering) private var snapshot

    /// Click selects, Command-click toggles, Shift-click selects a range in
    /// display order, arrow keys move; each reports the new set through
    /// `onSelectionChange`. Double-click or Return calls `onOpen`. With
    /// `cellIdentifierPrefix` each cell's identifier is `<prefix><id>`.
    /// `onVisibleChange` gets the ids of the cells on screen, in display
    /// order, as cells appear and disappear.
    public init(
        _ items: [ThumbnailItem<ID>], cellSize: CGSize, selection: Set<ID>,
        onSelectionChange: @escaping @MainActor (Set<ID>) -> Void,
        onOpen: @escaping @MainActor (ID) -> Void = { _ in },
        cellIdentifierPrefix: String? = nil,
        onVisibleChange: @escaping @MainActor ([ID]) -> Void = { _ in }
    ) {
        self.items = items
        self.cellSize = cellSize
        self.selection = selection
        self.onSelectionChange = onSelectionChange
        self.onOpen = onOpen
        self.cellIdentifierPrefix = cellIdentifierPrefix
        self.onVisibleChange = onVisibleChange
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
                    .accessibilityIdentifier(cellIdentifierPrefix.map { "\($0)\(item.id)" } ?? "")
                    .id(item.id)
                    .onAppear { setVisible(item.id, true) }
                    .onDisappear { setVisible(item.id, false) }
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

    // ponytail: filters every id per appear, O(items) a call; keep an index if huge catalogs stutter.
    private func setVisible(_ id: ID, _ isVisible: Bool) {
        var next = visible
        if isVisible { next.insert(id) } else { next.remove(id) }
        visible = next
        onVisibleChange(order.filter(next.contains))
    }

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

/// One thumbnail: the image (or a flat placeholder) with its badges clipped
/// to it, and the caption under it. Selection is an accent ring and a light
/// accent fill, and a `stateSelected` hairline just outside the ring, so the
/// selection still reads on a blue or teal photo where the ring blends in.
private struct ThumbnailCell<ID: Hashable>: View {
    let item: ThumbnailItem<ID>
    let size: CGSize
    let isSelected: Bool

    var body: some View {
        VStack(spacing: SuiteSpacing.xs) {
            thumbnail
                .frame(width: size.width, height: size.height)
                // Badges go on before the clip, so a small cell trims them
                // instead of letting them spill past its edge (issue #102).
                .overlay(alignment: .bottomLeading) { badges }
                .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: SuiteRadius.small)
                        .strokeBorder(isSelected ? SuiteColor.accent : SuiteColor.separator, lineWidth: isSelected ? 2 : 1))
                .overlay { if isSelected { selectionHairline } }
            Text(item.caption)
                .font(SuiteFont.caption)
                .foregroundStyle(isSelected ? Color.primary : SuiteColor.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: size.width)
        }
        .padding(SuiteSpacing.xs)
        .background(isSelected ? SuiteColor.accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .accessibilityElement(children: .combine)
        // After the combine, so a cell with badges reads its help once, not once per element.
        .help(item.help ?? item.caption)
        .accessibilityValue(Text(verbatim: item.accessibilityValue ?? ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// One focus-gap-wide line around the image's edge, outside the ring;
    /// `stateSelected` clears 3:1 on the cell's accent fill in both schemes.
    private var selectionHairline: some View {
        RoundedRectangle(cornerRadius: SuiteRadius.small + SuiteSize.focusRingGap)
            .strokeBorder(SuiteColor.stateSelected, lineWidth: SuiteSize.focusRingGap)
            .padding(-SuiteSize.focusRingGap)
            .accessibilityHidden(true)
    }

    /// The image aspect-fit over the placeholder fill, never cropped.
    private var thumbnail: some View {
        SuiteColor.surface.overlay {
            if item.isUnreadable {
                Image(systemName: "exclamationmark.triangle")
                    .font(SuiteFont.title)
                    .foregroundStyle(SuiteColor.stateWarning)
                    .accessibilityLabel("Unreadable")
            } else if let image = item.image {
                image.resizable().scaledToFit()
                    .opacity(item.badges.dimmed ? SuiteColor.disabledOpacity : 1)
            } else {
                Image(systemName: "photo")
                    .font(SuiteFont.title)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var badges: some View {
        let marks = item.badges
        if marks.rating > 0 || marks.isFlagged || marks.colorLabel != nil || marks.dimmed {
            HStack(spacing: SuiteSpacing.xxs) {
                if marks.rating > 0 {
                    HStack(spacing: 0) {
                        ForEach(0..<marks.rating, id: \.self) { _ in Image(systemName: "star.fill") }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: marks.rating == 1 ? "1 star" : "\(marks.rating) stars"))
                }
                if marks.dimmed { Image(systemName: "xmark.circle").accessibilityLabel("Rejected") }
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
