// SidebarRow.swift: SidebarItem (id, title, SF Symbol or an app's mark,
// optional count, row toggles, children, dimmed), SidebarToggle, and the row SuiteWindow draws for an
// item. A dimmed item (a hidden or locked layer) draws its title and symbol in
// SuiteColor.textSecondary (SidebarRowLook) and stays selectable; its toggles
// draw as on any row. Row height follows the system sidebar size setting, so nothing here
// fixes a height. The row owns only presentation state (the rename field);
// toggles and renames go out through closures, and a nil closure turns that
// gesture off. A rename the app refuses (its `onRename` returns a message)
// keeps the field open with the draft as typed and the message under it in
// SuiteColor.stateError (SidebarRenameField, LL-6); the Void form still renames. Each toggle icon lays out both of its symbols and draws one,
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

/// A row's rename field (lists-and-layers LL-6): the draft as typed and the
/// app's refusal shown under it. A commit runs SuiteListEditing with the app's
/// rename as its validate, so a refusal keeps the draft and the field stays
/// open; typing clears the message; Escape, or focus lost while refused, closes it.
public struct SidebarRenameField: Equatable, Sendable {
    /// The text in the field; nil while the title shows as a label.
    public private(set) var draft: String?
    /// Why the app refused the last commit; nil when it didn't.
    public private(set) var message: String?

    public init() {}

    public var isOpen: Bool { draft != nil }

    public mutating func open(_ title: String) {
        draft = title
        message = nil
    }

    public mutating func type(_ text: String) {
        draft = text
        message = nil
    }

    public mutating func cancel() {
        draft = nil
        message = nil
    }

    /// Commits the draft: `rename` gets the trimmed new name and returns nil
    /// to accept it or a message to refuse it. Accepted, empty or unchanged
    /// closes the field; refused keeps it open with the draft and the message.
    @MainActor public mutating func commit(original: String, rename: (@MainActor (String) -> String?)?) {
        guard let draft else { return }
        switch SuiteListEditing().commitRename(draft, original: original, validate: { rename?($0) }) {
        case let .refused(message, kept):
            self.draft = kept
            self.message = message
        case .renamed, .unchanged, .cancelled:
            cancel()
        }
    }

    /// Focus left the field: a refused draft is dropped (no refusal loop),
    /// any other draft is committed.
    @MainActor public mutating func loseFocus(original: String, rename: (@MainActor (String) -> String?)?) {
        if message != nil { cancel() } else { commit(original: original, rename: rename) }
    }
}

public struct SidebarRow: View {
    private let item: SidebarItem
    private let onToggle: (@MainActor (SidebarToggle.ID) -> Void)?
    private let onRename: (@MainActor (String) -> String?)?
    @State private var field = SidebarRenameField()
    @FocusState private var editing: Bool

    /// `onToggle` gets a toggle's id when it is clicked; `onRename` gets the
    /// new title after a double-click edit. Nil turns that gesture off.
    public init(
        _ item: SidebarItem, onToggle: (@MainActor (SidebarToggle.ID) -> Void)? = nil,
        onRename: (@MainActor (String) -> Void)? = nil
    ) {
        self.init(item, onToggle: onToggle, refusableRename: Self.refusable(onRename))
    }

    /// A rename the app can refuse: `onRename` returns nil to accept the new
    /// title, or the message the row shows under the field it keeps open.
    public init(
        _ item: SidebarItem, onToggle: (@MainActor (SidebarToggle.ID) -> Void)? = nil,
        onRename: @escaping @MainActor (String) -> String?
    ) {
        self.init(item, onToggle: onToggle, refusableRename: onRename)
    }

    /// `field` is the rename state the row starts in: closed, unless a
    /// snapshot shows a refused rename.
    init(
        _ item: SidebarItem, onToggle: (@MainActor (SidebarToggle.ID) -> Void)?,
        refusableRename: (@MainActor (String) -> String?)?, field: SidebarRenameField = SidebarRenameField()
    ) {
        self.item = item
        self.onToggle = onToggle
        self.onRename = refusableRename
        _field = State(initialValue: field)
    }

    /// The Void rename form as one that never refuses.
    public static func refusable(_ onRename: (@MainActor (String) -> Void)?) -> (@MainActor (String) -> String?)? {
        guard let onRename else { return nil }
        return { name in
            onRename(name)
            return nil
        }
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
        if field.isOpen {
            VStack(alignment: .leading, spacing: SuiteSpacing.xxs) {
                TextField(item.title, text: Binding(get: { field.draft ?? item.title }, set: { field.type($0) }))
                    .focused($editing)
                    .onSubmit(commitRename)
                    .onExitCommand { field.cancel() }
                    .onChange(of: editing) { _, focused in if !focused { loseFocus() } }
                    .accessibilityIdentifier("suite.sidebar.\(item.id).rename")
                if let message = field.message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.stateError)
                        .accessibilityIdentifier("suite.sidebar.\(item.id).renameMessage")
                }
            }
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
        guard Self.doubleClickRenames(part, renamable: onRename != nil, renaming: field.isOpen) else { return }
        field.open(item.title)
        editing = true
    }

    private func commitRename() {
        field.commit(original: item.title, rename: onRename)
    }

    private func loseFocus() {
        field.loseFocus(original: item.title, rename: onRename)
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
