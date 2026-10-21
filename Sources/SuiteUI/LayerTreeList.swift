// LayerTreeList.swift: the one layers panel every app shows over the kernel's
// `LayerTree` (packet docs/blueprints/suiteui/features/editor-kernel.md, EK-4).
// It reads `LayerRow`s (front to back, with depth and what they inherit) and
// draws each as a row: indent by depth, a disclosure for a container, the
// name (dimmed when it or an ancestor is hidden), then eye and lock toggles.
// Dragging a row onto a container row proposes a move into it as its last
// child; `drop(_:onto:in:childCount:)` is the pure rule (refusing a
// non-container, a locked target, the row itself and its own descendants),
// so it is tested without a window. The list mutates nothing: every gesture
// goes out through one `onAction` closure. Rows are keyed by the
// layer's id, lazy in the list's own scroll view and eager when `embedded` in a
// host's, and `.equatable()` on their plain values (swiftui-rules 2, 5).
// The only view state is the drop target lit while a drag hovers it and the
// row under the pointer (fill plus outline), each written on enter and exit,
// never per sample. A flat list (`nests: false`) drops the disclosure column.
// Each row's controls carry `suite.layers.<id>.<part>`; the row itself is
// `suite.layers.row.<id>`.
// To stand in for a sidebar layers panel (#2811) it can take a selected id
// and `onSelect` (a click on the row; the row draws the selected tint and
// reads selected), `onRename` (SidebarRow's double-click, Return and
// "Rename" routes; a non-nil result refuses and keeps the draft), SidebarRow's
// identifiers and labels (`naming: .sidebar`) and a header with an action
// (LayerTreeList+Rows.swift). Each defaults to off, so older callers are unchanged.
// App panels (#3194) add ids, options and decorations; `reorder` is the flat drop's pure rule.
// Multi-select (multi-layer-select PM-1): the `selected:` init draws every
// picked id selected and sends a click out through `onPick` with its mode,
// `pick(shift:command:)` of the modifiers read once when the click lands.
// It shows no scroller (wheel, trackpad and keys still scroll), so the
// audit finds no unnamed page-area button beside a long tree. While it
// scrolls it reports a drawn frame on series `layers-scroll` (SP4) to the
// environment's GridProbe, as ThumbnailGrid does.
import AppKit
import SuiteKernel
import SwiftUI

/// A move the list proposes: layer `id` into `parent` at `index`.
public struct LayerDrop: Equatable, Sendable {
    public let id: String
    public let parent: String
    public let index: Int

    public init(id: String, parent: String, index: Int) {
        self.id = id
        self.parent = parent
        self.index = index
    }

    /// The `parent` of a move among the roots.
    public static let root = ""

    /// The parent as the kernel's `move(_:into:at:)` takes it: nil for the roots.
    public var parentID: String? { parent == Self.root ? nil : parent }
}

/// What a person did in the list.
public enum LayerTreeAction: Equatable, Sendable {
    /// Opened or closed the container `id`.
    case disclose(String)
    /// Clicked the eye or the lock of `id`.
    case toggleHidden(String), toggleLocked(String)
    /// Dropped a row into a container.
    case move(LayerDrop)
}

public struct LayerTreeList: View {
    private let rows: [LayerRow]
    private let childCount: @MainActor (String) -> Int
    private let onAction: @MainActor (LayerTreeAction) -> Void
    private let selection: String?
    private let selected: Set<String>
    let naming: LayerTreeNaming
    let header: LayerTreeHeader?
    let options: LayerTreeOptions
    private let decorations: [String: LayerRowDecoration]
    private let onSelect: (@MainActor (String) -> Void)?
    private let onRename: (@MainActor (String, String) -> String?)?
    /// The row that starts with its rename field in this state: a snapshot's refused rename.
    private let renaming: (id: String, field: SidebarRenameField)?
    @State private var target: String?
    @Environment(\.gridProbe) private var probe

    /// The list with several rows picked: every id in `selected` draws
    /// selected, and a click on a row calls `onPick` with its id and the
    /// click's mode (`pick(shift:command:)`). The rest is as the `selection:` init.
    public init(
        rows: [LayerRow], childCount: @escaping @MainActor (String) -> Int, selected: Set<String>,
        naming: LayerTreeNaming = .layers, header: LayerTreeHeader? = nil, options: LayerTreeOptions = .init(),
        decorations: [String: LayerRowDecoration] = [:],
        onPick: @escaping @MainActor (String, Pick) -> Void, onRename: (@MainActor (String, String) -> String?)? = nil,
        onAction: @escaping @MainActor (LayerTreeAction) -> Void
    ) {
        self.init(rows: rows, childCount: childCount, selection: nil, selected: selected, naming: naming,
                  header: header, options: options, decorations: decorations,
                  onSelect: { id in
                      let flags = NSEvent.modifierFlags
                      onPick(id, Self.pick(shift: flags.contains(.shift), command: flags.contains(.command)))
                  },
                  onRename: onRename, renaming: nil, onAction: onAction)
    }

    /// `rows` from `LayerTree.rows(expanded:)`; `childCount` names how many
    /// children a closed container holds, so a drop lands after the last one.
    /// `selection` draws that row selected and a click on a row calls
    /// `onSelect`; `onRename` gets a row's id and new name and returns nil to
    /// accept it or the refusal shown under the field it keeps open. Nil
    /// turns that gesture off; `naming`, `header` and `options` are described
    /// on their types, and `decorations` holds each decorated row's by its id.
    public init(
        rows: [LayerRow], childCount: @escaping @MainActor (String) -> Int, selection: String? = nil,
        naming: LayerTreeNaming = .layers, header: LayerTreeHeader? = nil, options: LayerTreeOptions = .init(),
        decorations: [String: LayerRowDecoration] = [:],
        onSelect: (@MainActor (String) -> Void)? = nil, onRename: (@MainActor (String, String) -> String?)? = nil,
        onAction: @escaping @MainActor (LayerTreeAction) -> Void
    ) {
        self.init(rows: rows, childCount: childCount, selection: selection, naming: naming, header: header,
                  options: options, decorations: decorations,
                  onSelect: onSelect, onRename: onRename, renaming: nil, onAction: onAction)
    }

    init(
        rows: [LayerRow], childCount: @escaping @MainActor (String) -> Int, selection: String?,
        selected: Set<String> = [],
        naming: LayerTreeNaming, header: LayerTreeHeader?, options: LayerTreeOptions = .init(),
        decorations: [String: LayerRowDecoration] = [:], onSelect: (@MainActor (String) -> Void)?,
        onRename: (@MainActor (String, String) -> String?)?, renaming: (id: String, field: SidebarRenameField)?,
        onAction: @escaping @MainActor (LayerTreeAction) -> Void
    ) {
        self.rows = rows
        self.childCount = childCount
        self.onAction = onAction
        self.selection = selection
        self.selected = selected
        self.naming = naming
        self.header = header
        self.options = options
        self.decorations = decorations
        self.onSelect = onSelect
        self.onRename = onRename
        self.renaming = renaming
    }

    /// Whether row `id` draws selected: the single selection or any picked id.
    func isSelected(_ id: String) -> Bool { selection == id || selected.contains(id) }

    /// How a click with these modifiers changes the selection: Shift
    /// extends, Command toggles, a plain click replaces (Shift wins over both).
    nonisolated public static func pick(shift: Bool, command: Bool) -> Pick {
        shift ? .extend : command ? .toggle : .replace
    }

    /// A click on row `id`: tells the app, when it takes selection.
    func select(_ id: String) { onSelect?(id) }

    /// Row `id`'s rename, as SidebarRenameField commits it; nil when the list can't rename.
    func rename(_ id: String) -> (@MainActor (String) -> String?)? {
        guard let onRename else { return nil }
        return { onRename(id, $0) }
    }

    /// The move a drop of `id` onto `target` makes, or nil when the list
    /// refuses it: an unknown row, the row itself or one of its descendants,
    /// a target that holds no children, or one locked by itself or an ancestor.
    /// The index is the target's child count after the move leaves: read
    /// from the rows when it is open, else `childCount`.
    nonisolated public static func drop(_ id: String, onto target: String, in rows: [LayerRow], childCount: Int) -> LayerDrop? {
        guard id != target,
              let from = rows.firstIndex(where: { $0.id == id }),
              let to = rows.firstIndex(where: { $0.id == target }) else { return nil }
        let destination = rows[to]
        guard destination.holdsChildren, !destination.isLocked, !destination.inheritsLocked else { return nil }
        let depth = rows[from].depth
        let below = rows[(from + 1)...].prefix { $0.depth > depth }
        guard !below.contains(where: { $0.id == target }) else { return nil }
        // An open container lists its children right below it; count those at
        // its depth + 1 (the moving row among them, since it leaves first).
        let shown = rows[(to + 1)...].prefix { $0.depth > destination.depth }.filter { $0.depth == destination.depth + 1 }
        let count = destination.isExpanded ? shown.count - (shown.contains { $0.id == id } ? 1 : 0) : childCount
        return LayerDrop(id: id, parent: target, index: max(count, 0))
    }

    /// The move a drop of `id` beside the row `target` makes: into the
    /// target's own parent (`LayerDrop.root` at depth 0), just above it in the
    /// list or, when `below`, just under it. Nil for an unknown row, the row
    /// itself or one of its descendants, and a target locked by itself or an
    /// ancestor. The index counts from the back, as the kernel's children do,
    /// among the siblings left once the moving row leaves.
    nonisolated public static func reorder(_ id: String, beside target: String, below: Bool,
                                           in rows: [LayerRow]) -> LayerDrop? {
        guard id != target,
              let from = rows.firstIndex(where: { $0.id == id }),
              let to = rows.firstIndex(where: { $0.id == target }) else { return nil }
        let destination = rows[to]
        guard !destination.isLocked, !destination.inheritsLocked else { return nil }
        let depth = rows[from].depth
        guard !rows[(from + 1)...].prefix(while: { $0.depth > depth }).contains(where: { $0.id == target }) else {
            return nil
        }
        // The parent is the nearest row above one level up; none at depth 0.
        let parent = rows[..<to].lastIndex { $0.depth < destination.depth }
        let siblings = rows[(parent.map { $0 + 1 } ?? 0)...].prefix { $0.depth >= destination.depth }
            .filter { $0.depth == destination.depth && $0.id != id }
        guard let place = siblings.firstIndex(where: { $0.id == target }) else { return nil }
        let fromFront = place + (below ? 1 : 0)
        return LayerDrop(id: id, parent: parent.map { rows[$0].id } ?? LayerDrop.root,
                         index: siblings.count - fromFront)
    }

    /// Every id the list keys a row by, in order; ids are the layers' own, so
    /// a row keeps its identity when the rows around it change.
    nonisolated public static func rowIDs(_ rows: [LayerRow]) -> [String] { rows.map(\.id) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                SidebarSectionHeader(section: header.section)
                    .padding(.horizontal, SuiteSpacing.s)
                    .padding(.vertical, SuiteSpacing.xs)
            }
            list
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(naming.container)
    }

    @ViewBuilder private var list: some View {
        if options.embedded {
            // Eager: in a host's scroll view a lazy stack never builds the rows
            // below its fold, so they had no accessibility node to press.
            VStack(alignment: .leading, spacing: 0) { rowViews }
                .padding(.vertical, SuiteSpacing.xs)
        } else {
            scrolling
        }
    }

    private var rowViews: some View {
        ForEach(rows, id: \.id) { row in
            LayerTreeRow(
                row: row, lit: target == row.id, selected: isSelected(row.id), naming: naming,
                options: options, decoration: decorations[row.id],
                field: renaming?.id == row.id ? renaming?.field : nil,
                onAction: onAction, onSelect: onSelect, onRename: rename(row.id))
                .equatable()
                .draggable(row.id)
                .dropDestination(for: String.self) { items, _ in
                    accept(items, onto: row.id)
                } isTargeted: { over in
                    light(row.id, over)
                }
        }
    }

    private var scrolling: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) { rowViews }
                .padding(.vertical, SuiteSpacing.xs)
        }
        // No scroller: a legacy scroller's page area is an unnamed button with
        // no identifier to the app audit (#2742, as in Design's list, #2561).
        .scrollIndicators(.never)
        .onScrollGeometryChange(for: Double.self) { Double($0.contentOffset.y) } action: { _, _ in
            probe?.drew(GridProbe.layersScrollSeries, ProcessInfo.processInfo.systemUptime)
        }
    }

    private func accept(_ items: [String], onto parent: String) -> Bool {
        target = nil
        guard let id = items.first, let move = proposal(id, onto: parent) else { return false }
        onAction(.move(move))
        return true
    }

    /// A drop of `id` on `target`: into a container, or with `reorders` into
    /// a flat row's place (below it when the row comes from above).
    private func proposal(_ id: String, onto target: String) -> LayerDrop? {
        guard options.reorders, let to = rows.firstIndex(where: { $0.id == target }), !rows[to].holdsChildren else {
            return Self.drop(id, onto: target, in: rows, childCount: childCount(target))
        }
        let from = rows.firstIndex { $0.id == id } ?? to
        return Self.reorder(id, beside: target, below: from < to, in: rows)
    }

    private func light(_ id: String, _ over: Bool) {
        let row = rows.first { $0.id == id }
        let accepts = row.map { ($0.holdsChildren || options.reorders) && !$0.isLocked && !$0.inheritsLocked } ?? false
        if over, accepts {
            target = id
        } else if target == id {
            target = nil
        }
    }
}

/// One row: plain values in, so SwiftUI skips it when they compare equal.
/// The closures are left out of `==`; whether it selects and renames is kept in.
struct LayerTreeRow: View, Equatable {
    let row: LayerRow
    let lit: Bool
    let selected: Bool
    let naming: LayerTreeNaming
    let options: LayerTreeOptions
    let decoration: LayerRowDecoration?
    let onAction: @MainActor (LayerTreeAction) -> Void
    let onSelect: (@MainActor (String) -> Void)?
    let onRename: (@MainActor (String) -> String?)?
    @State var field: SidebarRenameField
    @State private var hovering = false
    @FocusState var editing: Bool
    @Environment(\.suiteReduceMotion) private var reduceMotion

    private var look: LayerRowLook { .resolve(selected: selected, lit: lit, hovering: hovering) }

    /// The selected tint wins over hover; a drop target over a selected row keeps the tint.
    private var fill: Color {
        if selected { return SuiteColor.selectedTint }
        return look == .rest ? Color.clear : SuiteColor.rowHover
    }

    init(
        row: LayerRow, lit: Bool, selected: Bool, naming: LayerTreeNaming, options: LayerTreeOptions,
        decoration: LayerRowDecoration?, field: SidebarRenameField?,
        onAction: @escaping @MainActor (LayerTreeAction) -> Void, onSelect: (@MainActor (String) -> Void)?,
        onRename: (@MainActor (String) -> String?)?
    ) {
        self.row = row
        self.lit = lit
        self.selected = selected
        self.naming = naming
        self.options = options
        self.decoration = decoration
        self.onAction = onAction
        self.onSelect = onSelect
        self.onRename = onRename
        _field = State(initialValue: field ?? SidebarRenameField())
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.row == rhs.row && lhs.lit == rhs.lit && lhs.selected == rhs.selected && lhs.naming == rhs.naming
            && lhs.options == rhs.options && lhs.decoration == rhs.decoration
            && (lhs.onRename == nil) == (rhs.onRename == nil) && (lhs.onSelect == nil) == (rhs.onSelect == nil)
    }

    var body: some View {
        decorated(content)
    }

    private var content: some View {
        HStack(spacing: SuiteSpacing.xs) {
            if options.nests {
                Color.clear.frame(width: CGFloat(row.depth) * SuiteSpacing.l, height: SuiteSpacing.xxs)
                disclosure
            }
            leading
            title
            Spacer(minLength: SuiteSpacing.s)
            if options.showsEye {
                toggle(naming.visibility(row)) { onAction(.toggleHidden(row.id)) }
            }
            if options.showsLock {
                toggle(naming.lock(row)) { onAction(.toggleLocked(row.id)) }
            }
        }
        // One pointer-sized height, so a caption under the name doesn't make its row jump.
        .frame(minHeight: SuiteSize.studioRow)
        .padding(.horizontal, SuiteSpacing.s)
        .background(fill, in: RoundedRectangle(cornerRadius: SuiteRadius.row))
        .overlay {
            switch look {
            case .dropTarget:
                RoundedRectangle(cornerRadius: SuiteRadius.row)
                    .strokeBorder(SuiteColor.accent, lineWidth: SuiteSize.focusRing)
                    .allowsHitTesting(false)
            case .hover:
                RoundedRectangle(cornerRadius: SuiteRadius.row)
                    .strokeBorder(SuiteColor.outline, lineWidth: 1)
                    .allowsHitTesting(false)
            case .rest, .selected:
                EmptyView()
            }
        }
        .contentShape(.rect)
        // Written on enter and exit only, never per pointer sample (swiftui-rules 1).
        .onHover { hovering = $0 }
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: look)
        .onTapGesture { onSelect?(row.id) }
        .focusable(onRename != nil)
        .onKeyPress(.return) { requestRename() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(row.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        // A press selects, as the click does: the tap gesture gives a `.contain` row no default action.
        .accessibilityAction { onSelect?(row.id) }
        .accessibilityActions {
            if onRename != nil { Button(SidebarRow.renameActionName) { _ = requestRename() } }
        }
        .accessibilityIdentifier(naming.row(row.id))
    }

    private func toggle(_ toggle: SidebarToggle, action: @escaping @MainActor () -> Void) -> some View {
        icon(toggle.systemImage, toggle.title, identifier: naming.identifier(of: toggle, in: row.id), action: action)
    }

    @ViewBuilder private var disclosure: some View {
        if row.holdsChildren {
            icon("chevron.right", row.isExpanded ? "Collapse \(row.name)" : "Expand \(row.name)",
                 identifier: naming.disclosure(row.id), turned: row.isExpanded) {
                onAction(.disclose(row.id))
            }
        } else {
            Color.clear.frame(width: SuiteSize.iconButtonHit, height: SuiteSize.iconButtonHit)
        }
    }

    private func icon(_ symbol: String, _ title: String, identifier: String, turned: Bool = false,
                      action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .imageScale(.small)
                .rotationEffect(.degrees(turned ? 90 : 0))
                .frame(minWidth: SuiteSize.iconButtonHit, minHeight: SuiteSize.iconButtonHit)
                .contentShape(.rect)
        }
        .buttonStyle(HoverButtonStyle())
        .foregroundStyle(SuiteColor.secondaryText)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}
