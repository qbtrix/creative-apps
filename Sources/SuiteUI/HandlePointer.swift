// HandlePointer.swift: which way a selection handle's resize pointer points
// (transform-tools TT-u, #4628). A box turned `degrees` clockwise carries its
// handles round with it, so the top handle of a box turned 90° sits on the
// right and resizes sideways. `direction` names the handle that sits where
// this one now sits, rounded to the nearest of the eight (every 45°); the
// editor turns that into a frame-resize pointer. A rotate zone has none.
// No SwiftUI types, so the math is tested on its own (HandlePointerTests).
import SuiteKernel

public enum HandlePointer {
    /// The eight resize handles clockwise from the top edge, 45° apart.
    static let ring: [HandleKind] = [.top, .topRight, .right, .bottomRight, .bottom, .bottomLeft, .left, .topLeft]

    /// The handle position `kind` points at once the box is turned `degrees` clockwise, to the
    /// nearest 45°; nil for a rotate zone. A non-finite turn counts as none.
    public static func direction(_ kind: HandleKind, degrees: Double) -> HandleKind? {
        guard let start = ring.firstIndex(of: kind) else { return nil }
        let turn = degrees.isFinite ? degrees.truncatingRemainder(dividingBy: 360) : 0
        let steps = Int((turn / 45).rounded())
        let index = ((start + steps) % ring.count + ring.count) % ring.count
        return ring.indices.contains(index) ? ring[index] : nil
    }

    /// The drawn mark for the resize handle `kind` (its hover fill); nil for a rotate zone.
    public static func mark(_ kind: HandleKind) -> EditorHandle? {
        guard ring.contains(kind) else { return nil }
        return EditorHandle.allCases.first { String(describing: $0) == kind.rawValue }
    }
}
