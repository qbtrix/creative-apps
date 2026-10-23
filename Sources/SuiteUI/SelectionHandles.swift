// SelectionHandles.swift (editor-kernel EK-5): a selection box in a
// CanvasViewport's overlay (CanvasMarks family, docs/design.md Stage marks):
// a 1 pt accent outline, eight `selectionHandle` squares and a rotate knob on
// a stem, placed where the kernel's `BoxMath.handles` says, fixed on screen.
// Each handle is an accessibility element (`suite.handles.topLeft`, ...) that
// reports hover; the hovered one fills. The geometry is static so tests read it.
import SuiteKernel
import SwiftUI

/// One handle's mark in view points: which handle, and its square.
public struct SelectionHandleMark: Equatable, Sendable {
    public let handle: EditorHandle
    public let frame: CGRect

    public init(handle: EditorHandle, frame: CGRect) {
        self.handle = handle
        self.frame = frame
    }
}

/// A selection box with its eight handles and rotate knob over the canvas.
public struct SelectionHandles: View {
    private let box: Rect
    private let handles: [EditorHandle: Rect]
    private let zoom: Double
    private let hovered: EditorHandle?
    private let onHover: @MainActor (EditorHandle?) -> Void

    /// `box` and `handles` (from `BoxMath.handles`) in document pixels; `zoom`
    /// in points per pixel; `hovered` draws filled; `onHover` gets the handle
    /// the pointer enters, and nil when it leaves one.
    public init(box: Rect, handles: [EditorHandle: Rect], zoom: Double, hovered: EditorHandle? = nil,
                onHover: @escaping @MainActor (EditorHandle?) -> Void = { _ in }) {
        self.box = box
        self.handles = handles
        self.zoom = zoom
        self.hovered = hovered
        self.onHover = onHover
    }

    public var body: some View {
        let marks = Self.marks(handles: handles, zoom: zoom)
        ZStack(alignment: .topLeading) {
            Path(Self.viewRect(box, zoom: zoom)).stroke(SuiteColor.accent, lineWidth: 1)
            Self.stem(marks).stroke(SuiteColor.accent, lineWidth: 1)
            ForEach(marks, id: \.handle) { mark in
                handleView(mark)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.handles")
    }

    private func handleView(_ mark: SelectionHandleMark) -> some View {
        let shape = mark.handle == .rotate ? AnyShape(Circle()) : AnyShape(Rectangle())
        let name = Self.name(mark.handle)
        return shape.fill(mark.handle == hovered ? SuiteColor.accent : SuiteColor.overlayPaper)
            .overlay { shape.stroke(SuiteColor.accent, lineWidth: 1) }
            .frame(width: mark.frame.width, height: mark.frame.height)
            .frame(width: SuiteSize.selectionHandleHit, height: SuiteSize.selectionHandleHit)
            .contentShape(Rectangle())
            .onHover { inside in onHover(inside ? mark.handle : nil) }
            .position(x: mark.frame.midX, y: mark.frame.midY)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: name))
            .accessibilityIdentifier("suite.handles.\(name)")
    }

    /// The handle's name as its case reads (`topLeft`, `rotate`): the words a
    /// status line shows for the handle under the pointer.
    nonisolated public static func name(_ handle: EditorHandle) -> String { String(describing: handle) }

    /// `rect` in view points at `zoom` (a non-finite or non-positive zoom draws at 1).
    nonisolated public static func viewRect(_ rect: Rect, zoom: Double) -> CGRect {
        let s = MotionPathMarks.scale(zoom)
        return CGRect(x: rect.minX * s, y: rect.minY * s, width: rect.width * s, height: rect.height * s)
    }

    /// One mark per handle in `handles` (never `.inside`), in `EditorHandle`
    /// order: a `selectionHandle` square centred on that handle's rect at
    /// `zoom`, the same size at every zoom. A non-finite rect draws nothing.
    nonisolated public static func marks(handles: [EditorHandle: Rect], zoom: Double) -> [SelectionHandleMark] {
        let side = SuiteSize.selectionHandle
        return EditorHandle.allCases.compactMap { handle in
            guard handle != .inside, let rect = handles[handle] else { return nil }
            let view = viewRect(rect, zoom: zoom)
            guard [view.midX, view.midY].allSatisfy(\.isFinite) else { return nil }
            return SelectionHandleMark(
                handle: handle, frame: CGRect(x: view.midX - side / 2, y: view.midY - side / 2, width: side, height: side))
        }
    }

    /// The rotate knob's stem: from the top handle's centre to the knob's,
    /// when both are marked.
    nonisolated public static func stem(_ marks: [SelectionHandleMark]) -> Path {
        var path = Path()
        guard let top = marks.first(where: { $0.handle == .top }),
              let knob = marks.first(where: { $0.handle == .rotate }) else { return path }
        path.move(to: CGPoint(x: top.frame.midX, y: top.frame.midY))
        path.addLine(to: CGPoint(x: knob.frame.midX, y: knob.frame.midY))
        return path
    }
}
