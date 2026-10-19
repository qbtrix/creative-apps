// LayerTreeList+Rows.swift: what LayerTreeList needs to stand in for an app's
// sidebar layers panel (#2811). LayerTreeNaming picks the identifiers and
// labels: `.layers` keeps the list's own (`suite.layers`, "Hide Ball"),
// `.sidebar` matches SidebarRow's (`suite.sidebar` container, toggles
// `suite.sidebar.<id>.visible` / `.locked` through SidebarToggle.identifier,
// labelled "Hide Layer" / "Lock Layer"). LayerTreeHeader is the optional
// title and action button above the rows, drawn by SidebarSectionHeader. The
// row's rename reuses SidebarRow's rules and state: SidebarRenameField holds
// the draft and the refusal (a refused rename keeps its draft), and
// SidebarRow.doubleClickRenames / keyRenames / renameActionName gate the
// double-click on the title, Return on the focused row and the "Rename"
// accessibility action.
import SuiteKernel
import SwiftUI

/// Which identifiers and labels LayerTreeList gives its container, rows and toggles.
public enum LayerTreeNaming: Equatable, Sendable {
    /// `suite.layers`, `suite.layers.<id>.eye` / `.lock`, "Hide <name>": the list's own.
    case layers
    /// SidebarRow's: `suite.sidebar`, `suite.sidebar.<id>.visible` / `.locked`, "Hide Layer" / "Lock Layer".
    case sidebar

    /// The list's container identifier, which holds every row.
    public var container: String { self == .layers ? "suite.layers" : "suite.sidebar" }

    /// The row `id`'s own identifier.
    public func row(_ id: String) -> String { "\(container).row.\(id)" }

    /// The disclosure button of the container row `id`.
    public func disclosure(_ id: String) -> String { "\(container).\(id).disclose" }

    /// The rename field of row `id`, and the refusal under it.
    public func renameField(_ id: String) -> String { "\(container).\(id).rename" }
    public func renameMessage(_ id: String) -> String { "\(container).\(id).renameMessage" }

    /// The eye toggle of `row`: on while the layer shows.
    public func visibility(_ row: LayerRow) -> SidebarToggle {
        let title = self == .layers ? row.name : "Layer"
        return SidebarToggle(
            id: self == .layers ? "eye" : "visible", title: row.isHidden ? "Show \(title)" : "Hide \(title)",
            onSymbol: "eye", offSymbol: "eye.slash", isOn: !row.isHidden)
    }

    /// The lock toggle of `row`: on while the layer is locked.
    public func lock(_ row: LayerRow) -> SidebarToggle {
        let title = self == .layers ? row.name : "Layer"
        return SidebarToggle(
            id: self == .layers ? "lock" : "locked", title: row.isLocked ? "Unlock \(title)" : "Lock \(title)",
            onSymbol: "lock", offSymbol: "lock.open", isOn: row.isLocked)
    }

    /// The identifier of `toggle` in row `id`: SidebarToggle's own for `.sidebar`.
    public func identifier(of toggle: SidebarToggle, in id: String) -> String {
        self == .sidebar ? toggle.identifier(in: id) : "suite.layers.\(id).\(toggle.id)"
    }
}

/// The title and optional action button (for example "New Layer") above the rows.
public struct LayerTreeHeader {
    public let title: String
    public let action: ToolbarAction?

    public init(title: String, action: ToolbarAction? = nil) {
        self.title = title
        self.action = action
    }

    /// The header as a sidebar section's, so SidebarSectionHeader draws it.
    var section: SidebarSection { SidebarSection(id: "layers", title: title, items: [], addAction: action) }
}

extension LayerTreeRow {
    /// The name, or the rename field while renaming, with the app's refusal under it.
    @ViewBuilder var title: some View {
        if field.isOpen {
            VStack(alignment: .leading, spacing: SuiteSpacing.xxs) {
                TextField(row.name, text: Binding(get: { field.draft ?? row.name }, set: { field.type($0) }))
                    .focused($editing)
                    .onSubmit { field.commit(original: row.name, rename: onRename) }
                    .onExitCommand { field.cancel() }
                    .onChange(of: editing) { _, focused in
                        if !focused { field.loseFocus(original: row.name, rename: onRename) }
                    }
                    .accessibilityIdentifier(naming.renameField(row.id))
                if let refusal = field.message {
                    Label(refusal, systemImage: "exclamationmark.triangle.fill")
                        .font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.stateError)
                        .accessibilityIdentifier(naming.renameMessage(row.id))
                }
            }
        } else {
            Text(row.name)
                .lineLimit(1)
                .foregroundStyle(row.isHidden || row.inheritsHidden ? SuiteColor.secondaryText : Color.primary)
                .contentShape(.rect)
                .simultaneousGesture(TapGesture(count: 2).onEnded { openRename(on: .title) })
        }
    }

    /// A double-click on `part`: opens the field on the title of a renamable row.
    func openRename(on part: SidebarRowPart) {
        guard SidebarRow.doubleClickRenames(part, renamable: onRename != nil, renaming: field.isOpen) else { return }
        field.open(row.name)
        editing = true
    }

    /// Return on the focused row or the "Rename" action: as a double-click on the title.
    func requestRename() -> KeyPress.Result {
        guard SidebarRow.keyRenames(renamable: onRename != nil, renaming: field.isOpen) else { return .ignored }
        openRename(on: .title)
        return .handled
    }
}
