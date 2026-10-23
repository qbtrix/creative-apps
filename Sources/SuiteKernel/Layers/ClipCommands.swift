// ClipCommands.swift (layer-styles LS-11): `layer.clip` and `layer.unclip`, the clipping-mask
// commands any app with a ClipTarget registers. Whether a layer has a base comes from ClipRules;
// each command sets the whole selection in one call, so it records one undo step.
// Linux-safe: no Foundation API is needed.

/// The selected layer as the clip commands see it: its id, whether it is clipped, and whether
/// there is an unclipped layer below it among its siblings to clip to.
public typealias ClipSelection = (id: String, isClipped: Bool, hasBase: Bool)

/// What an app gives the clip commands: the selection and the edit that clips or releases it.
public protocol ClipTarget: Sendable {
    /// The selected layer; nil when nothing is selected. `ClipCommands.selection` builds it from a tree.
    var clipSelection: ClipSelection? { get }
    /// Clips (or releases) every selected layer as one undo step named `name`.
    mutating func setClipped(_ clipped: Bool, name: String) throws
}

/// The `layer.clip` and `layer.unclip` specs.
public enum ClipCommands {
    /// Both commands take nothing and return nothing.
    public struct NoParams: Codable, Sendable { public init() {} }

    /// The help both commands show when no layer is selected.
    public static let nothingSelectedHelp = "Select a layer first."
    /// The help `layer.unclip` shows when the selected layer isn't clipped.
    public static let notClippedHelp = "The selected layer isn't clipped."

    /// The selection for `id` in `tree`: nil for an unknown id; its base comes from ClipRules on
    /// its own sibling list, so a clip never reaches out of its group.
    public static func selection<P>(of id: String, in tree: LayerTree<P>, isClipped: (P) -> Bool) -> ClipSelection? {
        guard let node = tree.node(id), let ancestors = tree.ancestors(of: id) else { return nil }
        let siblings = ancestors.last.flatMap { tree.node($0)?.children } ?? tree.roots
        return (id, isClipped(node.payload), ClipRules.base(of: id, in: siblings, isClipped: isClipped) != nil)
    }

    /// `layer.clip` needs a selection with a base below it.
    static func canClip<T: ClipTarget>(_ t: T) -> Availability {
        guard let s = t.clipSelection else { return .unavailable(nothingSelectedHelp) }
        guard s.hasBase else { return .unavailable(ClipRules.noBaseHelp) }
        return .available
    }

    /// `layer.unclip` needs a clipped selection.
    static func canUnclip<T: ClipTarget>(_ t: T) -> Availability {
        guard let s = t.clipSelection else { return .unavailable(nothingSelectedHelp) }
        return s.isClipped ? .available : .unavailable(notClippedHelp)
    }

    /// The two specs, for an app whose layers clip.
    public static func specs<T: ClipTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("layer.clip", title: "Create Clipping Mask",
                   summary: "Clips the selected layers to the nearest unclipped layer below them.",
                   kind: .edit, params: NoParams.self, schema: .none, example: .object([:]),
                   availability: { canClip($0) }) { (t: inout T, _: NoParams) throws -> NoParams in
                try set(&t, true, name: "Create Clipping Mask")
            },
            .typed("layer.unclip", title: "Release Clipping Mask",
                   summary: "Releases the selected layers from their clipping mask.",
                   kind: .edit, params: NoParams.self, schema: .none, example: .object([:]),
                   availability: { canUnclip($0) }) { (t: inout T, _: NoParams) throws -> NoParams in
                try set(&t, false, name: "Release Clipping Mask")
            },
        ]
    }

    /// One call for the whole selection: one undo step.
    static func set<T: ClipTarget>(_ t: inout T, _ clipped: Bool, name: String) throws -> NoParams {
        try t.setClipped(clipped, name: name)
        return NoParams()
    }
}
