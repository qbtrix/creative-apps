// HaloTransform+Kernel.swift: Halo's selected layer as a SuiteKernel
// TransformTarget (transform HT-1, docs/blueprints/halo/features/transform.md).
// On these stubs the box is the selected layer's drawn box at the playhead
// (the axis-aligned box the viewer outlines, the move drag included) with no
// turn; HT-5 reads the unturned box and turn from the sampled transform
// instead. Flip is refused, and setTransform refuses until HT-5 writes Scale,
// Rotation and Position through the keying rules. No transform maths here:
// the kernel's TransformRules own it. Linux-safe.
import FlareCore
import SuiteKernel

extension HaloProject: TransformTarget {
    /// The selected layer's drawn box at the playhead, unturned; nil with no
    /// layer selected or one not drawn there.
    public var transformSelection: TransformBox? {
        guard let id = selectedLayer?.id, let r = viewerDrawList?.worldBox(of: id) else { return nil }
        return TransformBox(box: Rect(minX: r.x, minY: r.y, maxX: r.x + r.width, maxY: r.y + r.height))
    }

    /// Why nothing can be transformed: no layer selected.
    public var transformHelp: String? {
        selectedLayer == nil ? "Select a layer to transform." : nil
    }

    /// Halo has no mirrored layers yet.
    public var flipHelp: String? { "Flipping isn't in Halo yet." }

    /// Refused until HT-5 writes the box through the keying rules; changes nothing.
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        throw HaloEditError.notBuilt("Transform")
    }
}
