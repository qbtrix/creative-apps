// GroupPick.swift (area-selection AR-1): the declarations the tests compile against; the specs follow.

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
    /// The id a click picks. Declaration only: nil.
    public static func target<P>(hit: String, scope: GroupScope, deep: Bool, in tree: LayerTree<P>) -> String? { nil }
    /// The scope inside `id`. Declaration only: nil.
    public static func entering<P>(_ id: String, scope: GroupScope, in tree: LayerTree<P>) -> GroupScope? { nil }
    /// The scope one level up. Declaration only: the scope as it is.
    public static func exiting(_ scope: GroupScope) -> GroupScope { scope }
    /// The group commands on `target`. Declaration only: none yet.
    public static func specs<T: GroupPickTarget>(_ target: T.Type) -> [CommandSpec<T>] { [] }
}
