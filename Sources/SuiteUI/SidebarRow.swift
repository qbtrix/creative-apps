// SidebarRow.swift: SidebarItem (id, title, SF Symbol or an app's mark,
// optional count, row toggles, children, dimmed), SidebarToggle, and the row SuiteWindow draws for an
// item. A dimmed item (a hidden or locked layer) draws its title and symbol in
// SuiteColor.textSecondary (SidebarRowLook) and stays selectable; its toggles
// draw as on any row. Row height follows the system sidebar size setting, so nothing here
// fixes a height. The row owns only presentation state (the rename draft);
// toggles and renames go out through closures, and a nil closure turns that
// gesture off. Each toggle icon lays out both of its symbols and draws one,
// so it is as wide in every state and the toggles form a column (#53). The
// icon is hidden from accessibility, so each toggle carries its own
// identifier, `suite.sidebar.<item id>.<toggle id>` (the app audit, #262).
import SuiteModel
import SwiftUI

public struct SidebarItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    /// The app whose mark the row shows in place of `systemImage` (AppMark
    /// .line; .launcher is the suite mark); nil shows the symbol.
    public let app: SuiteApp?
    /// A count shown as a trailing badge; nil or 0 shows none.
    public let count: Int?
    /// Small icon toggles after the title (visibility, lock, ...).
    public let toggles: [SidebarToggle]
    /// Rows nested under this one in the window's list. The sidebar shows at
    /// most two levels (docs/design.md): a top-level item's children sit one
    /// level in, and their own descendants are drawn flat at that same level,
    /// in depth-first order, right after their parent (`secondLevelRows`).
    public let children: [SidebarItem]
    /// Draws the title and symbol in SuiteColor.textSecondary, for a hidden or
    /// locked layer. The row stays selectable and its toggles are unchanged.
    public let isDimmed: Bool

    public init(
        id: String, title: String, systemImage: String, count: Int? = nil,
        toggles: [SidebarToggle] = [], children: [SidebarItem] = [], app: SuiteApp? = nil,
        isDimmed: Bool = false
    ) {
        self.isDimmed = isDimmed
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.app = app
        self.count = count
        self.toggles = toggles
        self.children = children
    }

    /// A row that shows `app`'s mark instead of a symbol.
    public init(id: String, title: String, app: SuiteApp, count: Int? = nil) {
        self.init(id: id, title: title, systemImage: "", count: count, app: app)
    }

    /// The rows the sidebar draws under this item at the second level: every
    /// descendant in depth-first order, each without children, so nothing
    /// nests a third level deep.
    public var secondLevelRows: [SidebarItem] {
        children.flatMap { child in
            [SidebarItem(
                id: child.id, title: child.title, systemImage: child.systemImage, count: child.count,
                toggles: child.toggles, app: child.app, isDimmed: child.isDimmed)] + child.secondLevelRows
        }
    }
}

/// One on/off state of a row, drawn as an icon: `onSymbol` when on,
/// `offSymbol` when off. `title` is the tooltip and accessibility label.
public struct SidebarToggle: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let onSymbol: String
    public let offSymbol: String
    public let isOn: Bool

    public init(id: String, title: String, onSymbol: String, offSymbol: String, isOn: Bool) {
        self.id = id
        self.title = title
        self.onSymbol = onSymbol
        self.offSymbol = offSymbol
        self.isOn = isOn
    }

    /// The SF Symbol for the current state.
    public var systemImage: String { isOn ? onSymbol : offSymbol }

    /// The toggle's accessibility identifier in the row of item `itemID`:
    /// the same whatever its state or title, and unique across rows.
    public func identifier(in itemID: SidebarItem.ID) -> String {
        "suite.sidebar.\(itemID).\(id)"
    }
}

/// Where a click lands in a row: the title label, the blank space between
/// the title and the toggles, or one of the toggles.
public enum SidebarRowPart: Sendable {
    case title, blank, toggle
}

/// How a row draws its title and symbol: `title` is the foreground (nil keeps
/// the list's own, which turns white on a selected row), and `isSelectable`
/// stays true for a dimmed row, so a hidden or locked layer can still be picked.
public struct SidebarRowLook: Equatable, Sendable {
    public let title: Color?
    public let isSelectable: Bool

    public init(_ item: SidebarItem) {
        title = item.isDimmed ? SuiteColor.textSecondary : nil
        isSelectable = true
    }
}

public struct SidebarRow: View {
    private let item: SidebarItem
    private let onToggle: (@MainActor (SidebarToggle.ID) -> Void)?
    private let onRename: (@MainActor (String) -> Void)?
    @State private var draft: String?
    @FocusState private var editing: Bool

    /// `onToggle` gets a toggle's id when it is clicked; `onRename` gets the
    /// new title after a double-click edit. Nil turns that gesture off.
    public init(
        _ item: SidebarItem, onToggle: (@MainActor (SidebarToggle.ID) -> Void)? = nil,
        onRename: (@MainActor (String) -> Void)? = nil
    ) {
        self.item = item
        self.onToggle = onToggle
        self.onRename = onRename
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            title
            Spacer(minLength: SuiteSpacing.s)
            ForEach(item.toggles) { toggle in
                Toggle(isOn: Binding(get: { toggle.isOn }, set: { _ in onToggle?(toggle.id) })) {
                    Label { Text(toggle.title) } icon: { SidebarToggleIcon(toggle: toggle) }
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(toggle.isOn ? Color.primary : SuiteColor.secondaryText)
                .disabled(onToggle == nil)
                .help(toggle.title)
                .accessibilityLabel(toggle.title)
                .accessibilityIdentifier(toggle.identifier(in: item.id))
            }
        }
        .badge(item.count ?? 0)
        .selectionDisabled(!SidebarRowLook(item).isSelectable)
    }

    /// The title label, or the rename field while renaming. The rename
    /// double-click lives on the label alone, not on the row or the blank
    /// space after it, so a double-click on a toggle is two plain clicks that
    /// flip it twice, and one on blank space selects the row and nothing more.
    @ViewBuilder private var title: some View {
        if draft != nil {
            TextField(item.title, text: Binding(get: { draft ?? item.title }, set: { draft = $0 }))
                .focused($editing)
                .onSubmit(commitRename)
                .onExitCommand { draft = nil }
                .onChange(of: editing) { _, focused in if !focused { commitRename() } }
        } else {
            Label { Text(item.title) } icon: { SidebarRowIcon(item: item) }
                .modifier(SidebarRowDimming(color: SidebarRowLook(item).title))
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture(count: 2).onEnded { beginRename(on: .title) })
        }
    }

    /// Whether a double-click on `part` opens the rename field: only on the
    /// title label, only when the row can be renamed and is not being
    /// renamed. Blank space and toggles never rename.
    nonisolated public static func doubleClickRenames(_ part: SidebarRowPart, renamable: Bool, renaming: Bool) -> Bool {
        part == .title && renamable && !renaming
    }

    private func beginRename(on part: SidebarRowPart) {
        guard Self.doubleClickRenames(part, renamable: onRename != nil, renaming: draft != nil) else { return }
        draft = item.title
        editing = true
    }

    private func commitRename() {
        guard let name = draft?.trimmingCharacters(in: .whitespaces) else { return }
        draft = nil
        if !name.isEmpty, name != item.title { onRename?(name) }
    }
}

/// Draws the title label in a dimmed row's color; a nil color leaves the
/// list's own foreground, so a normal row reads as before.
private struct SidebarRowDimming: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content.foregroundStyle(color)
        } else {
            content
        }
    }
}

/// A row's icon: its app's line mark (AppMark, sized like a symbol), else its SF Symbol.
private struct SidebarRowIcon: View {
    let item: SidebarItem

    var body: some View {
        if let app = item.app {
            AppMark(app: app, style: .line).symbolSized()
        } else {
            Image(systemName: item.systemImage)
        }
    }
}

/// A toggle's icon: its on and off symbols stacked, only the current one
/// drawn. The unseen symbol still takes part in layout, so the icon is as
/// wide as the wider of the two whatever the state, and a toggle with the
/// same symbols sits at the same x in every row (#53). No hand-sized frame.
private struct SidebarToggleIcon: View {
    let toggle: SidebarToggle

    var body: some View {
        ZStack {
            Image(systemName: toggle.onSymbol).opacity(toggle.isOn ? 1 : 0)
            Image(systemName: toggle.offSymbol).opacity(toggle.isOn ? 0 : 1)
        }
        .accessibilityHidden(true)
    }
}
