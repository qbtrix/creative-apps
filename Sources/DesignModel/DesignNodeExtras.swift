// DesignNodeExtras.swift: a node's rarely set payloads (stroke, gradient, shape spec, picture and its focus, keys), kept on
// the heap behind one copy-on-write box so DesignNode stays small inline. The kernel projection (`layerNode`) recurses once per tree
// level and holds several node copies per frame, so every inline byte costs stack at every level; a 416-byte node
// overflowed a 512 KB test thread at 61 levels (DesignNodeStackTests pins the size). Every node without extras
// shares one empty box, which is never uniquely referenced, so a plain node allocates nothing and its first write
// copies. Compares and hashes by value, so DesignNode's equality is unchanged. Linux-safe.
import SuiteKernel

/// The fields most nodes leave nil.
struct DesignNodeExtras: Hashable, Sendable {
    var stroke: DesignStroke?
    var gradient: Fill?
    var shape: ShapeSpec?
    var placedAsset: PlacedAsset?
    var placedFocus = DesignNode.centreFocus
    /// Keyed properties; nil for a still node.
    var time: DesignNodeTime?
}

/// `DesignNodeExtras` on the heap: reads share it, a write to a shared box copies it first.
struct DesignNodeExtrasBox: Hashable, Sendable {
    /// Written only through `value`'s `_modify`, after the uniqueness check.
    private final class Storage: @unchecked Sendable {
        var value: DesignNodeExtras
        init(_ value: DesignNodeExtras) { self.value = value }
    }

    /// The box every node without extras shares; the static keeps it from ever being unique.
    private static let empty = Storage(DesignNodeExtras())
    private var storage = Self.empty

    var value: DesignNodeExtras {
        get { storage.value }
        _modify {
            if !isKnownUniquelyReferenced(&storage) { storage = Storage(storage.value) }
            yield &storage.value
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.storage.value == rhs.storage.value }
    func hash(into hasher: inout Hasher) { hasher.combine(storage.value) }
}
