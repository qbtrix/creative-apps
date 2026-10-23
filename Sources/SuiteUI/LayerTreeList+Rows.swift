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
// accessibility action. App panels (#3194): `.app` naming, LayerTreeOptions, LayerRowDecoration.
// LayerRowLook picks a row's state fill: drop target, selected, hover, rest.
// LayerRowJoin names the edges a selected row shares with a selected neighbour.
import SuiteKernel
import SwiftUI

/// Which identifiers and labels LayerTreeList gives its container, rows and toggles.
public enum LayerTreeNaming: Equatable, Sendable {
    /// `suite.layers`, `suite.layers.<id>.eye` / `.lock`, "Hide <name>": the list's own.
    case layers
    /// SidebarRow's: `suite.sidebar`, `suite.sidebar.<id>.visible` / `.locked`, "Hide Layer" / "Lock Layer".
    case sidebar
    /// The app's own ids (#3194), so a panel swap keeps its journeys' ids;
    /// labels and toggle parts as `.layers` ("Hide <name>", `.eye`, `.lock`).
    case app(LayerTreeIDs)

    /// The ids this naming builds from.
    var ids: LayerTreeIDs {
        switch self {
        case .layers: LayerTreeIDs(container: "suite.layers", row: "suite.layers.row.", control: "suite.layers.")
        case .sidebar: LayerTreeIDs(container: "suite.sidebar", row: "suite.sidebar.row.", control: "suite.sidebar.")
        case .app(let ids): ids
        }
    }

    /// The list's container identifier, which holds every row.
    public var container: String { ids.container }

    /// The row `id`'s own identifier.
    public func row(_ id: String) -> String { ids.row + id }

    /// Control `part` of row `id`, for example a decoration's symbol.
    public func control(_ id: String, _ part: String) -> String { "\(ids.control)\(id).\(part)" }

    /// The disclosure button of the container row `id`.
    public func disclosure(_ id: String) -> String { control(id, "disclose") }

    /// The rename field of row `id`, and the refusal under it.
    public func renameField(_ id: String) -> String { control(id, "rename") }
    public func renameMessage(_ id: String) -> String { control(id, "renameMessage") }

    /// The eye toggle of `row`: on while the layer shows.
    public func visibility(_ row: LayerRow) -> SidebarToggle {
        let title = self == .sidebar ? "Layer" : row.name
        return SidebarToggle(
            id: self == .sidebar ? "visible" : "eye", title: row.isHidden ? "Show \(title)" : "Hide \(title)",
            onSymbol: "eye", offSymbol: "eye.slash", isOn: !row.isHidden)
    }

    /// The lock toggle of `row`: on while the layer is locked.
    public func lock(_ row: LayerRow) -> SidebarToggle {
        let title = self == .sidebar ? "Layer" : row.name
        return SidebarToggle(
            id: self == .sidebar ? "locked" : "lock", title: row.isLocked ? "Unlock \(title)" : "Lock \(title)",
            onSymbol: "lock", offSymbol: "lock.open", isOn: row.isLocked)
    }

    /// The identifier of `toggle` in row `id` (for `.sidebar`, SidebarToggle's own).
    public func identifier(of toggle: SidebarToggle, in id: String) -> String { control(id, toggle.id) }
}

/// An app's ids for LayerTreeList: the container, the prefix before a row's
/// layer id, and the prefix before `<id>.<part>` of each control.
public struct LayerTreeIDs: Equatable, Sendable {
    public let container: String
    public let row: String
    public let control: String

    public init(container: String, row: String, control: String) {
        self.container = container
        self.row = row
        self.control = control
    }
}

/// How the list draws (#3194). Each option is off by default, so a list
/// without it looks as before: both toggles, drops only into containers, its own ScrollView.
public struct LayerTreeOptions: Equatable, Sendable {
    /// Whether each row draws its eye and its lock toggle.
    public var showsEye: Bool
    public var showsLock: Bool
    /// Whether a drop on a row that holds no children reorders the dragged
    /// row beside it (`LayerTreeList.reorder`), taking its place.
    public var reorders: Bool
    /// Whether the rows sit in the host's own scroll view, without the list's ScrollView.
    public var embedded: Bool
    /// Whether rows can hold children; a flat list (Photo) leaves out the
    /// indent and the empty disclosure column, so names start near the edge.
    public var nests: Bool

    public init(showsEye: Bool = true, showsLock: Bool = true, reorders: Bool = false, embedded: Bool = false,
                nests: Bool = true) {
        self.showsEye = showsEye
        self.showsLock = showsLock
        self.reorders = reorders
        self.embedded = embedded
        self.nests = nests
    }
}

/// How a row draws its state. A drop target wins, then the selection, then
/// the pointer: hover is a `rowHover` fill with an `outline` edge, never fill
/// alone (docs/design.md, Surfaces).
enum LayerRowLook: Equatable {
    case rest, hover, selected, dropTarget

    static func resolve(selected: Bool, lit: Bool, hovering: Bool) -> Self {
        lit ? .dropTarget : selected ? .selected : hovering ? .hover : .rest
    }
}

/// What one row draws beyond its name, as plain data the app keys by layer
/// id (#3194): a thumbnail, a leading SF Symbol with its label and id (by
/// default the naming's `<id>.symbol`), a caption line under the name, and
/// the row's tooltip and accessibility value.
public struct LayerRowDecoration: Equatable, Sendable {
    public var thumbnail: Image?
    public var symbol: String?
    public var symbolLabel: String?
    public var symbolID: String?
    public var caption: String?
    public var help: String?
    public var value: String?

    public init(thumbnail: Image? = nil, symbol: String? = nil, symbolLabel: String? = nil, symbolID: String? = nil,
                caption: String? = nil, help: String? = nil, value: String? = nil) {
        self.thumbnail = thumbnail
        self.symbol = symbol
        self.symbolLabel = symbolLabel
        self.symbolID = symbolID
        self.caption = caption
        self.help = help
        self.value = value
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
        } else if let caption = decoration?.caption {
            VStack(alignment: .leading, spacing: 0) {
                name
                Text(caption)
                    .font(SuiteFont.inspectorMeta)
                    .lineLimit(1)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
        } else {
            name
        }
    }

    private var name: some View {
        Text(row.name)
            .lineLimit(1)
            .foregroundStyle(row.isHidden || row.inheritsHidden ? SuiteColor.secondaryText : Color.primary)
            .contentShape(.rect)
            .simultaneousGesture(TapGesture(count: 2).onEnded { openRename(on: .title) })
    }

    /// The decoration's thumbnail and symbol, before the name.
    @ViewBuilder var leading: some View {
        if let thumbnail = decoration?.thumbnail {
            thumbnail
                .resizable()
                .scaledToFill()
                .frame(width: SuiteSize.studioRow, height: SuiteSize.studioRow)
                .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.field))
                .accessibilityHidden(true)
        }
        if let symbol = decoration?.symbol {
            Image(systemName: symbol)
                .frame(width: SuiteSize.iconButtonHit)
                .foregroundStyle(SuiteColor.secondaryText)
                .accessibilityLabel(decoration?.symbolLabel ?? row.name)
                .accessibilityIdentifier(decoration?.symbolID ?? naming.control(row.id, "symbol"))
        }
    }

    /// The row's tooltip and accessibility value, when its decoration has them.
    @ViewBuilder func decorated(_ content: some View) -> some View {
        if let help = decoration?.help, let value = decoration?.value {
            content.help(help).accessibilityValue(value)
        } else if let help = decoration?.help {
            content.help(help)
        } else if let value = decoration?.value {
            content.accessibilityValue(value)
        } else {
            content
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

/// Which edges of a selected row meet a selected neighbour (LayerTreeList.selectionJoins).
struct LayerRowJoin: Equatable, Sendable {
    var above = false
    var below = false

    static let none = LayerRowJoin()
}
