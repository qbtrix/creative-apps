// ClipRules.swift (layer-styles LS-10): the clipping rule on the kernel's
// layer tree. A clipped layer draws only where its base has alpha; its base
// is the nearest unclipped layer below it among its siblings, one parent's
// children. A group sibling is a valid base, and the walk never enters it or
// leaves the sibling list, so a clip never reaches out of its group.
// Linux-safe: no Foundation API is needed.

/// Which layer a clipped layer clips to, and which layers clip to a base.
public enum ClipRules {
    /// The help a clip command shows when the layer has nothing below to clip to.
    public static let noBaseHelp = "There is no layer below to clip to."
    /// The help an unclip command shows when the layer isn't clipped.
    public static let notClippedHelp = "This layer isn't clipped."

    /// The id `id` clips to among `siblings` (back to front): the nearest
    /// layer below it that isn't clipped. Nil for the bottom layer, a layer
    /// with only clipped layers below it, or an id not among `siblings`.
    public static func base<P>(of id: String, in siblings: [LayerNode<P>], isClipped: (P) -> Bool) -> String? {
        guard let index = siblings.firstIndex(where: { $0.id == id }) else { return nil }
        let below = siblings[..<index]
        return below.last { !isClipped($0.payload) }?.id
    }

    /// The ids clipped onto `baseID` among `siblings` (back to front): the
    /// run of clipped layers right above it, back to front. Empty when the
    /// base is unknown or is itself clipped.
    public static func clipped<P>(onto baseID: String, in siblings: [LayerNode<P>], isClipped: (P) -> Bool) -> [String] {
        guard let index = siblings.firstIndex(where: { $0.id == baseID }),
              !isClipped(siblings[index].payload) else { return [] }
        let above = siblings[(index + 1)...]
        return above.prefix { isClipped($0.payload) }.map(\.id)
    }
}
