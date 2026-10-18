// CanvasMarks+Grid.swift: a grid over document content inside a
// CanvasViewport's overlay, the lines a horizon is lined up with while
// straightening (canvas-marks CM-8, #530). `cells` cells each way: cells - 1
// hairlines across and down, white at 50% over a 1 px black shadow so they
// read on light and dark pixels, clipped to the rect. Lines are 1 pt at any
// zoom. Like the other marks it never takes a click and is hidden from
// accessibility.
import SwiftUI

/// Where a grid's lines fall, in view points at the canvas zoom.
public struct CanvasGridLines: Equatable, Sendable {
    /// The x of each vertical line, left to right.
    public let vertical: [CGFloat]
    /// The y of each horizontal line, top to bottom.
    public let horizontal: [CGFloat]
}

/// A `cells` × `cells` grid over a document rectangle.
public struct CanvasGrid: View {
    private let rect: CGRect
    private let cells: Int
    private let zoom: Double
    @Environment(\.pixelLength) private var pixel

    /// `rect` in document pixels; `cells` along each side (0 or less draws
    /// nothing); `zoom` in points per pixel.
    public init(rect: CGRect, cells: Int, zoom: Double) {
        self.rect = rect
        self.cells = cells
        self.zoom = zoom
    }

    /// The lines of a `cells` grid over `rect` at `zoom`: cells - 1 each way,
    /// none when `cells` is 0 or less or the rect or zoom isn't finite.
    /// Pure math, so nonisolated: the View conformance would otherwise make it
    /// main-actor and trap when called off the main thread (a test worker).
    public nonisolated static func lines(rect: CGRect, cells: Int, zoom: Double) -> CanvasGridLines {
        let finite = [rect.minX, rect.minY, rect.width, rect.height, zoom].allSatisfy(\.isFinite)
        guard cells > 0, finite else { return CanvasGridLines(vertical: [], horizontal: []) }
        let shares = (1..<cells).map { Double($0) / Double(cells) }
        return CanvasGridLines(
            vertical: shares.map { (rect.minX + rect.width * $0) * zoom },
            horizontal: shares.map { (rect.minY + rect.height * $0) * zoom })
    }

    public var body: some View {
        let lines = Self.lines(rect: rect, cells: cells, zoom: zoom)
        let frame = GridFrame(rect: rect, zoom: zoom)
        let view = frame.path(in: .zero).boundingRect
        let path = Path { path in
            for x in lines.vertical {
                path.move(to: CGPoint(x: x, y: view.minY))
                path.addLine(to: CGPoint(x: x, y: view.maxY))
            }
            for y in lines.horizontal {
                path.move(to: CGPoint(x: view.minX, y: y))
                path.addLine(to: CGPoint(x: view.maxX, y: y))
            }
        }
        // One device pixel down and right: the ink shadow under each line.
        ZStack(alignment: .topLeading) {
            path.stroke(SuiteColor.overlayInk, lineWidth: 1).offset(x: pixel, y: pixel)
            path.stroke(SuiteColor.overlayPaper.opacity(0.5), lineWidth: 1)
        }
        .clipShape(frame)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The grid's document rectangle at `zoom`, in view points: its clip.
private struct GridFrame: Shape {
    let rect: CGRect
    let zoom: Double

    func path(in _: CGRect) -> Path {
        let scaled = CGRect(x: rect.minX * zoom, y: rect.minY * zoom, width: rect.width * zoom, height: rect.height * zoom)
        return Path(scaled.isNull || scaled.isInfinite ? .zero : scaled.standardized)
    }
}
