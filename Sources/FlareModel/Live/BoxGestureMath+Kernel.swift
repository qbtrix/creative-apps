// BoxGestureMath+Kernel.swift: AT-f1 of adopt-kernel-transform (#1938). Flare numbers its box handles 0...7
// clockwise from the top-left; that ring is the kernel's `EditorHandle` order, so the numbering, the corner and edge
// tests and each handle's spot on the box come from SuiteKernel. The scale math itself stays in BoxGestureMath: it
// mirrors through the fixed handle and skips a zero axis, which the kernel's `BoxMath.resized` doesn't.
import FlareCore
import SuiteKernel

extension BoxGestureMath {
    /// The kernel's eight resize handles in its own order, clockwise from the top-left: Flare's 0...7.
    private static let ring = EditorHandle.allCases.filter { $0 != .inside && $0 != .rotate }

    /// Flare's handle `h` (taken mod 8) as the kernel's handle.
    public static func editorHandle(_ h: Int) -> EditorHandle {
        let i = ((h % 8) + 8) % 8
        return ring.indices.contains(i) ? ring[i] : .topLeft
    }

    /// The kernel's `handle` as Flare's 0...7; nil for `.inside` and `.rotate`, which Flare doesn't number.
    public static func flareHandle(_ handle: EditorHandle) -> Int? { ring.firstIndex(of: handle) }

    /// The handle across the box from `handle`, four steps round the ring; `handle` itself for `.inside` and `.rotate`.
    public static func opposite(_ handle: EditorHandle) -> EditorHandle {
        flareHandle(handle).map { editorHandle($0 + 4) } ?? handle
    }

    /// True for the top and bottom edges, which drag only the y axis.
    public static func movesOnlyY(_ handle: EditorHandle) -> Bool { handle == .top || handle == .bottom }

    /// True for the left and right edges, which drag only the x axis.
    public static func movesOnlyX(_ handle: EditorHandle) -> Bool { handle == .left || handle == .right }

    /// Where the kernel draws `handle` on `box`: the centre of its 0-size square.
    static func spot(_ handle: EditorHandle, on box: Rect) -> Point {
        guard let square = BoxMath.handles(of: box, size: 0)[handle] else { return Point(x: box.minX, y: box.minY) }
        return Point(x: (square.minX + square.maxX) / 2, y: (square.minY + square.maxY) / 2)
    }
}
