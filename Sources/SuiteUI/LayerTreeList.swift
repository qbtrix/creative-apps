// LayerTreeList.swift: the one layers panel every app shows over the kernel's
// `LayerTree` (packet docs/blueprints/suiteui/features/editor-kernel.md, EK-4).
// It reads `LayerRow`s (front to back, with depth and what they inherit) and
// draws each as a row: indent by depth, a disclosure for a container, the
// name (dimmed when it or an ancestor is hidden), then eye and lock toggles.
// Dragging a row onto a container row proposes a move into it as its last
// child; `drop(_:onto:in:childCount:)` is the pure rule (refusing a
// non-container, a locked target, the row itself and its own descendants),
// so it is tested without a window. The list mutates nothing: every gesture
// goes out through one `onAction` closure. Rows are lazy, keyed by the
// layer's id, and `.equatable()` on their plain values (swiftui-rules 2, 5).
// The only view state is the drop target lit while a drag hovers it, written
// on enter and exit, never per sample. Each row's controls carry
// `suite.layers.<id>.<part>`; the row itself is `suite.layers.row.<id>`.
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
    @State private var target: String?

    /// `rows` from `LayerTree.rows(expanded:)`; `childCount` names how many
    /// children a closed container holds, so a drop lands after the last one.
    public init(
        rows: [LayerRow], childCount: @escaping @MainActor (String) -> Int,
        onAction: @escaping @MainActor (LayerTreeAction) -> Void
    ) {
        self.rows = rows
        self.childCount = childCount
        self.onAction = onAction
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

    /// Every id the list keys a row by, in order; ids are the layers' own, so
    /// a row keeps its identity when the rows around it change.
    nonisolated public static func rowIDs(_ rows: [LayerRow]) -> [String] { rows.map(\.id) }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows, id: \.id) { row in
                    LayerTreeRow(row: row, lit: target == row.id, onAction: onAction)
                        .equatable()
                        .draggable(row.id)
                        .dropDestination(for: String.self) { items, _ in
                            accept(items, onto: row.id)
                        } isTargeted: { over in
                            light(row.id, over)
                        }
                }
            }
            .padding(.vertical, SuiteSpacing.xs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.layers")
    }

    private func accept(_ items: [String], onto parent: String) -> Bool {
        target = nil
        guard let id = items.first,
              let move = Self.drop(id, onto: parent, in: rows, childCount: childCount(parent)) else { return false }
        onAction(.move(move))
        return true
    }

    private func light(_ id: String, _ over: Bool) {
        let row = rows.first { $0.id == id }
        let accepts = row.map { $0.holdsChildren && !$0.isLocked && !$0.inheritsLocked } ?? false
        if over, accepts {
            target = id
        } else if target == id {
            target = nil
        }
    }
}

/// One row: plain values in, so SwiftUI skips it when they compare equal.
private struct LayerTreeRow: View, Equatable {
    let row: LayerRow
    let lit: Bool
    let onAction: @MainActor (LayerTreeAction) -> Void

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.row == rhs.row && lhs.lit == rhs.lit }

    var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            Color.clear.frame(width: CGFloat(row.depth) * SuiteSpacing.l, height: SuiteSpacing.xxs)
            disclosure
            Text(row.name)
                .lineLimit(1)
                .foregroundStyle(row.isHidden || row.inheritsHidden ? SuiteColor.secondaryText : Color.primary)
            Spacer(minLength: SuiteSpacing.s)
            icon(row.isHidden ? "eye.slash" : "eye", row.isHidden ? "Show \(row.name)" : "Hide \(row.name)", part: "eye") {
                onAction(.toggleHidden(row.id))
            }
            icon(row.isLocked ? "lock" : "lock.open", row.isLocked ? "Unlock \(row.name)" : "Lock \(row.name)", part: "lock") {
                onAction(.toggleLocked(row.id))
            }
        }
        .padding(.horizontal, SuiteSpacing.s)
        .background(lit ? SuiteColor.rowHover : Color.clear, in: RoundedRectangle(cornerRadius: SuiteRadius.row))
        .overlay {
            if lit {
                RoundedRectangle(cornerRadius: SuiteRadius.row)
                    .strokeBorder(SuiteColor.accent, lineWidth: SuiteSize.focusRing)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(row.name)
        .accessibilityIdentifier("suite.layers.row.\(row.id)")
    }

    @ViewBuilder private var disclosure: some View {
        if row.holdsChildren {
            icon("chevron.right", row.isExpanded ? "Collapse \(row.name)" : "Expand \(row.name)", part: "disclose",
                 turned: row.isExpanded) {
                onAction(.disclose(row.id))
            }
        } else {
            Color.clear.frame(width: SuiteSize.iconButtonHit, height: SuiteSize.iconButtonHit)
        }
    }

    private func icon(_ symbol: String, _ title: String, part: String, turned: Bool = false,
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
        .accessibilityIdentifier("suite.layers.\(row.id).\(part)")
    }
}
