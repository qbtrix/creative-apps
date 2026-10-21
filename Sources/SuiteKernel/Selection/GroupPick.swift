// GroupPick.swift (area-selection AR-1 stubs, AR-4 bodies): the group-aware click every object editor shares: the outermost
// group in the entered scope, Command the deepest layer; Return enters, Escape steps out. The commands run on the stubs.

/// The groups a click is inside: the path of group ids from the root down; empty is the root.
public struct GroupScope: Hashable, Sendable, Codable {
    /// The entered groups, outermost first.
    public var path: [String]
    /// A scope of `path`; the root when empty.
    public init(path: [String] = []) { self.path = path }
    /// No group entered.
    public static let root = GroupScope()
}

/// A document with a layer tree a click picks in: an app's workspace conforms in its `<X>GroupPick+Kernel.swift`.
public protocol GroupPickTarget: Sendable {
    /// The app's layer payload.
    associatedtype PickPayload: LayerPayload
    /// The layers a click picks among.
    var pickTree: LayerTree<PickPayload> { get }
    /// The entered groups.
    var groupScope: GroupScope { get }
    /// The picked layer's id; nil when nothing is picked.
    var pickedLayer: String? { get }
    /// The innermost visible layer under `point` in document space; nil on empty canvas.
    func layerHit(at point: Point) -> String?
    /// Picks `id` (nil deselects) inside `scope`; a pick is view state, not an undo step.
    mutating func setGroupPick(_ id: String?, scope: GroupScope) throws
}

/// The group pick rule and its three commands.
public enum GroupPick {
    struct Empty: Codable, Sendable {}; struct Picked: Encodable { var id: String? }
    struct PickParams: Codable, Sendable { var x, y: Double; var deep: Bool? }
    /// Why Enter Group and Exit Group can't run.
    static let enterHelp = "Pick a group with layers in it first.", exitHelp = "No group is entered."
    /// The id a click picks: the ancestor of `hit` that is a direct child of the scope's innermost group, or `hit`
    /// itself when `deep` (Command) or when it already is one; nil when the hit is outside the scope or under a
    /// locked group. AR-1 stub: `hit`.
    public static func target<P>(hit: String, scope: GroupScope, deep: Bool, in tree: LayerTree<P>) -> String? { hit }
    /// The scope inside `id` when it is a group with children; nil otherwise. AR-1 stub: nil.
    public static func entering<P>(_ id: String, scope: GroupScope, in tree: LayerTree<P>) -> GroupScope? { nil }
    /// The scope one level up; the root stays the root. AR-1 stub: the root.
    public static func exiting(_ scope: GroupScope) -> GroupScope { .root }
    /// The three group commands on `target`: pick at a point, enter the picked group, exit one level; each a view
    /// change, not an undo step.
    public static func specs<T: GroupPickTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("select.pick", title: "Pick", summary: "Picks the layer a click at a point picks: the outermost group in the entered one, or with deep the layer itself.",
                   kind: .view, params: PickParams.self,
                   schema: .object(["x": .number("Document x."), "y": .number("Document y."), "deep": .optional(.boolean)], required: ["x", "y", "deep"]),
                   result: .object(["id": .optional(.string("The picked layer; left out when the click picked nothing."))], required: ["id"]),
                   example: .object(["x": .number(20), "y": .number(20)])) { t, p in try pick(&t, p) },
            .typed("select.enter-group", title: "Enter Group", summary: "Enters the picked group, so the next click picks inside it.",
                   kind: .view, params: Empty.self, schema: ParamSchema.none, example: .object([:]),
                   availability: { entered($0) == nil ? .unavailable(enterHelp) : .available }) { t, _ in try enter(&t) },
            .typed("select.exit-group", title: "Exit Group", summary: "Steps out of the entered group one level and picks it.",
                   kind: .view, params: Empty.self, schema: ParamSchema.none, example: .object([:]),
                   availability: { $0.groupScope.path.isEmpty ? .unavailable(exitHelp) : .available }) { t, _ in try exit(&t) },
        ]
    }

    static func pick<T: GroupPickTarget>(_ target: inout T, _ p: PickParams) throws -> Picked {
        let id = target.layerHit(at: Point(x: p.x, y: p.y)).flatMap { Self.target(hit: $0, scope: target.groupScope, deep: p.deep ?? false, in: target.pickTree) }
        try target.setGroupPick(id, scope: target.groupScope)
        return Picked(id: id)
    }
    static func entered<T: GroupPickTarget>(_ target: T) -> GroupScope? { target.pickedLayer.flatMap { entering($0, scope: target.groupScope, in: target.pickTree) } }
    /// The picked group entered, nothing picked inside it yet.
    static func enter<T: GroupPickTarget>(_ target: inout T) throws -> Empty {
        guard let scope = entered(target) else { throw CatalogError.unavailable(id: "select.enter-group", why: enterHelp) }
        try target.setGroupPick(nil, scope: scope); return Empty()
    }
    static func exit<T: GroupPickTarget>(_ target: inout T) throws -> Empty {
        try target.setGroupPick(target.groupScope.path.last, scope: exiting(target.groupScope)); return Empty()
    }
}
