// ThumbnailGrid.swift: ThumbnailItem and ThumbnailGrid, a LazyVGrid of image
// thumbnails with adaptive columns for Library and any asset browser. Content,
// so flat: no glass. The app owns the selection and gets every change through
// `onSelectionChange`; the grid keeps only presentation state (click anchor,
// focus, width, the cells on screen). Every click and arrow move goes through
// a `GridSelecting` rule (UC9), `SuiteGridSelecting` over GridSelection unless
// the caller passes another (lists-and-layers LL-12). Each cell is one
// accessibility element carrying the app's value, help and `<prefix><id>`
// identifier, registered in `suite.controls` (ids go on that leaf, never on
// the grid; the gallery uses `suite.grid.`). While it scrolls the grid reports
// a drawn frame on series `grid-scroll` (SP4) to the GridProbe a probe host
// sets in the environment. `onVisibleChange` reports the cells on
// screen so the app can load only those thumbnails. Images aspect-fit inside
// the cell; a reject is dimmed with a badge and an unreadable file shows a
// warning mark, and a cell still waiting for its image pulses its placeholder
// symbol (none under `suiteReduceMotion`). Columns hold at least `cellSize.width` plus padding, and the
// cells stretch to fill the row with their images a fixed 8 pt
// (`SuiteSpacing.s`) apart, keeping `cellSize`'s aspect; adjacent selection
// fills touch; `showsCaptions: false` drops the file name under each
// image (the cell still reads it). With several selected, `active` names the
// one the app acts from (Library's Sync source): its ring is heavier and its
// accessibility value ends in "active". Snapshots drop the ScrollView, which ImageRenderer does not draw.
// Its indicators are `.never`, as in Halo's and Photo's inspectors: a legacy
// scroller is an unlabelled, unidentified button to the app audit (#1368).
// The grid still scrolls by wheel, trackpad and arrow keys.
import AppKit
import SwiftUI

/// Small symbols over a thumbnail. `rating` is clamped to 0...5 stars. The
/// color label's `name` is its accessibility label, so color never carries
/// the meaning alone. `dimmed` (a reject) draws the image at 40% with an
/// `xmark.circle.fill` badge labelled "Rejected", solid like the stars.
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
    /// No image yet and nothing wrong with the file: the placeholder's `photo` symbol pulses, except under reduce motion.
    public var isLoading: Bool { image == nil && !isUnreadable }

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

public struct ThumbnailGrid<ID: Hashable & Sendable>: View {
    private let items: [ThumbnailItem<ID>]
    private let cellSize: CGSize
    private let selection: Set<ID>
    private let onSelectionChange: @MainActor (Set<ID>) -> Void
    private let onOpen: @MainActor (ID) -> Void
    private let cellIdentifierPrefix: String?
    private let onVisibleChange: @MainActor ([ID]) -> Void
    private let selecting: any GridSelecting
    private let showsCaptions: Bool
    private let active: ID?
    @State private var anchor: ID?
    @State private var visible = Set<ID>()
    @State private var width: CGFloat = 0
    @FocusState private var focused: Bool
    @Environment(\.suiteSnapshotRendering) private var snapshot
    @Environment(\.gridProbe) private var probe

    /// Click selects, Command-click toggles, Shift-click selects a range in
    /// display order, arrow keys move; each reports the new set through
    /// `onSelectionChange`. Double-click or Return calls `onOpen`. With
    /// `cellIdentifierPrefix` each cell's identifier is `<prefix><id>`.
    /// `onVisibleChange` gets the ids of the cells on screen, in display
    /// order, as cells appear and disappear. `selecting` is the selection
    /// rule every click and arrow move goes through. `showsCaptions` false
    /// hides the caption under each image. `active`, when selected, draws the
    /// heavier ring of the item the app acts from.
    public init(
        _ items: [ThumbnailItem<ID>], cellSize: CGSize, selection: Set<ID>,
        onSelectionChange: @escaping @MainActor (Set<ID>) -> Void,
        onOpen: @escaping @MainActor (ID) -> Void = { _ in },
        cellIdentifierPrefix: String? = nil,
        onVisibleChange: @escaping @MainActor ([ID]) -> Void = { _ in },
        selecting: any GridSelecting = SuiteGridSelecting(),
        showsCaptions: Bool = true, active: ID? = nil
    ) {
        self.items = items
        self.cellSize = cellSize
        self.selection = selection
        self.onSelectionChange = onSelectionChange
        self.onOpen = onOpen
        self.cellIdentifierPrefix = cellIdentifierPrefix
        self.onVisibleChange = onVisibleChange
        self.selecting = selecting
        self.showsCaptions = showsCaptions
        self.active = active
    }

    public var body: some View {
        if snapshot {
            grid
        } else {
            ScrollViewReader { proxy in
                ScrollView { grid }
                    .scrollIndicators(.never)
                    .onScrollGeometryChange(for: Double.self) { Double($0.contentOffset.y) } action: { _, _ in
                        probe?.drew(GridProbe.scrollSeries, ProcessInfo.processInfo.systemUptime)
                    }
                    .onChange(of: anchor) { _, id in if let id { proxy.scrollTo(id) } }
            }
        }
    }

    /// The narrowest column: the image plus the cell's padding on both sides.
    private var columnWidth: CGFloat { cellSize.width + SuiteSpacing.xs * 2 }
    /// Between cells, so two images sit `SuiteSpacing.s` apart once each cell's padding is added.
    nonisolated private static var spacing: CGFloat { SuiteSpacing.s - SuiteSpacing.xs * 2 }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: Self.spacing)], spacing: Self.spacing) {
            ForEach(items) { item in
                ThumbnailCell(
                    item: item, aspect: cellSize, showsCaption: showsCaptions, isSelected: selection.contains(item.id),
                    isActive: item.id == active && selection.contains(item.id))
                    .suiteControl(id: cellIdentifierPrefix.map { "\($0)\(item.id)" }, enabled: true, reason: nil)
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

    private static func clickKind() -> ClickKind {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) { return .extend }
        return flags.contains(.command) ? .toggle : .plain
    }

    /// The pick after clicking `id`: what `rule` gives for the selection and
    /// anchor the grid holds. The grid's only click path (LL-12).
    nonisolated public static func picked(
        _ id: ID, _ kind: ClickKind, selection: Set<ID>, anchor: ID?, order: [ID], rule: any GridSelecting
    ) -> GridPick<ID> {
        rule.click(id, kind, current: GridPick(selection: selection, anchor: anchor), order: order)
    }

    private func click(_ id: ID, kind: ClickKind) {
        focused = true
        apply(Self.picked(id, kind, selection: selection, anchor: currentAnchor, order: order, rule: selecting))
    }

    private func move(_ arrow: GridArrow) -> KeyPress.Result {
        let columns = selecting.columns(
            width: Double(width - SuiteSpacing.m * 2), minimum: Double(columnWidth), spacing: Double(Self.spacing))
        let current = GridPick(selection: selection, anchor: currentAnchor)
        apply(selecting.move(arrow, extend: false, current: current, order: order, columns: columns))
        return .handled
    }

    private func apply(_ pick: GridPick<ID>) {
        anchor = pick.anchor
        if pick.selection != selection { onSelectionChange(pick.selection) }
    }
}

/// Where scrolling lists report their frames (`.suiteProbes()` sets it; nil
/// records nothing): one drawn frame per scroll offset change, on series
/// `grid-scroll` from ThumbnailGrid and `layers-scroll` from LayerTreeList,
/// for SP4's frame-interval p95 (QB-S7).
struct GridProbe: Sendable {
    static let scrollSeries = "grid-scroll"
    static let layersScrollSeries = "layers-scroll"
    let drew: @MainActor @Sendable (String, Double) -> Void
}

extension EnvironmentValues {
    /// Where thumbnail grids and layer lists report their scroll frames; nil records nothing.
    var gridProbe: GridProbe? {
        get { self[GridProbeKey.self] }
        set { self[GridProbeKey.self] = newValue }
    }
}

private struct GridProbeKey: EnvironmentKey {
    static let defaultValue: GridProbe? = nil
}

/// One thumbnail: the image (or a flat placeholder) at the column's width and
/// `aspect`'s shape, with its badges clipped to it, and the caption under it
/// unless `showsCaption` is false. Selection is an accent ring and a light
/// accent fill, and a `stateSelected` hairline just outside the ring, so the
/// selection still reads on a blue or teal photo where the ring blends in.
/// The active cell's ring is half again as heavy, and its value says "active".
/// Hover on an unselected cell takes the row-hover fill and a primary caption
/// (two signals, so it never reads by fill alone).
private struct ThumbnailCell<ID: Hashable>: View {
    let item: ThumbnailItem<ID>
    let aspect: CGSize
    let showsCaption: Bool
    let isSelected: Bool
    var isActive = false
    @State private var hovering = false
    @Environment(\.suiteReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SuiteSpacing.xs) {
            thumbnail
                .aspectRatio(aspect, contentMode: .fit)
                // Badges go on before the clip, so a small cell trims them
                // instead of letting them spill past its edge (issue #102).
                .overlay(alignment: .bottomLeading) { badges }
                .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: SuiteRadius.small)
                        .strokeBorder(
                            isSelected ? SuiteColor.accent : SuiteColor.separator,
                            lineWidth: isActive ? 3 : isSelected ? 2 : 1))
                .overlay { if isSelected { selectionHairline } }
            if showsCaption {
                Text(item.caption)
                    .font(SuiteFont.caption)
                    .foregroundStyle(isSelected || hovering ? Color.primary : SuiteColor.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(SuiteSpacing.xs)
        .background(
            isSelected ? SuiteColor.accent.opacity(0.15) : hovering ? SuiteColor.rowHover : .clear,
            in: RoundedRectangle(cornerRadius: SuiteRadius.medium)
        )
        .onHover { hovering = $0 }
        // No caption on screen: `.combine` would find no text and drop the element, so the cell
        // names itself, file name first, then what its badges say.
        .accessibilityElement(children: showsCaption ? .combine : .ignore)
        .accessibilityLabel { label in
            if showsCaption { label } else { Text(verbatim: spokenName) }
        }
        // After the combine, so a cell with badges reads its help once, not once per element.
        .help(item.help ?? item.caption)
        .accessibilityValue(Text(verbatim: [item.accessibilityValue ?? "", isActive ? "active" : ""]
                .filter { !$0.isEmpty }.joined(separator: ", ")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The captionless cell's label: the file name, then the badges' and the warning mark's words.
    private var spokenName: String {
        let marks = item.badges
        var parts = [item.caption]
        if item.isUnreadable { parts.append("Unreadable") }
        if marks.rating > 0 { parts.append(marks.rating == 1 ? "1 star" : "\(marks.rating) stars") }
        if marks.dimmed { parts.append("Rejected") }
        if marks.isFlagged { parts.append("Flagged") }
        if let label = marks.colorLabel { parts.append(label.name) }
        return parts.joined(separator: ", ")
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
                    .symbolEffect(.pulse, isActive: item.isLoading && !reduceMotion)
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
                if marks.dimmed { Image(systemName: "xmark.circle.fill").accessibilityLabel("Rejected") }
                if marks.isFlagged { Image(systemName: "flag.fill").accessibilityLabel("Picked") }
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
