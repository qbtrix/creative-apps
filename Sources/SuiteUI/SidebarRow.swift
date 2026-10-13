// SidebarRow.swift: SidebarItem (id, title, SF Symbol, optional count, row
// toggles, children), SidebarToggle, and the row SuiteWindow draws for an
// item. Row height follows the system sidebar size setting, so nothing here
// fixes a height. The row owns only presentation state (the rename draft);
// toggles and renames go out through closures, and a nil closure turns that
// gesture off.
import SwiftUI

public struct SidebarItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    /// A count shown as a trailing badge; nil or 0 shows none.
    public let count: Int?
    /// Small icon toggles after the title (visibility, lock, ...).
    public let toggles: [SidebarToggle]
    /// Rows nested under this one in the window's list.
    public let children: [SidebarItem]

    public init(
        id: String, title: String, systemImage: String, count: Int? = nil,
        toggles: [SidebarToggle] = [], children: [SidebarItem] = []
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.count = count
        self.toggles = toggles
        self.children = children
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
}

/// Where a click lands in a row: the title label, the blank space between
/// the title and the toggles, or one of the toggles.
public enum SidebarRowPart: Sendable {
    case title, blank, toggle
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
                    Label(toggle.title, systemImage: toggle.systemImage)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(toggle.isOn ? Color.primary : SuiteColor.secondaryText)
                .disabled(onToggle == nil)
                .help(toggle.title)
                .accessibilityLabel(toggle.title)
            }
        }
        .badge(item.count ?? 0)
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
            Label(item.title, systemImage: item.systemImage)
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
