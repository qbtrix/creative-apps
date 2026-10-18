// CanvasMarks+Grid.swift: CanvasGrid (CM-8, #530), the grid mark a canvas
// preview draws to line something up with (Photo's Straighten). `cells` cells
// each way over a document rect: `cells - 1` hairlines across and down, none
// at the rect's edges, none at all when `cells` is 0 or less. The lines are
// paper at half strength over a one-pixel ink shadow, clipped to the rect, so
// they read over light and dark pixels alike. Like the other marks it sits in
// a CanvasViewport's overlay in document pixels at the canvas zoom, takes no
// click and is hidden from accessibility. The line math is
// `CanvasGrid.lines(in:cells:zoom:)`, pure, so CanvasGridTests checks it.
import SwiftUI

/// The view-space positions of a grid's interior lines.
public struct CanvasGridLines: Equatable, Sendable {
    /// The x of each vertical line, left to right.
    public let vertical: [Double]
    /// The y of each horizontal line, top to bottom.
    public let horizontal: [Double]

    public static let empty = CanvasGridLines(vertical: [], horizontal: [])
}

/// A grid of `cells` × `cells` over a document rect.
public struct CanvasGrid: View {
    private let rect: CGRect
    private let cells: Int
    private let zoom: Double
    @Environment(\.pixelLength) private var pixel

    /// `rect` in document pixels; `cells` along each side; `zoom` in points per pixel.
    public init(rect: CGRect, cells: Int, zoom: Double) {
        self.rect = rect
        self.cells = cells
        self.zoom = zoom
    }

    /// The interior lines of `cells` cells over `rect` at `zoom`, in view
    /// points: `cells - 1` each way, and none when `cells` is 0 or less or the
    /// zoom isn't a finite positive number.
    public static func lines(in rect: CGRect, cells: Int, zoom: Double) -> CanvasGridLines {
        guard cells > 0, zoom.isFinite, zoom > 0 else { return .empty }
        let count = Double(cells)
        let shares = (1..<cells).map { Double($0) / count }
        return CanvasGridLines(
            vertical: shares.map { (rect.minX + rect.width * $0) * zoom },
            horizontal: shares.map { (rect.minY + rect.height * $0) * zoom })
    }

    public var body: some View {
        let lines = Self.lines(in: rect, cells: cells, zoom: zoom)
        let top = rect.minY * zoom, bottom = rect.maxY * zoom
        let left = rect.minX * zoom, right = rect.maxX * zoom
        let path = Path { path in
            for x in lines.vertical {
                path.move(to: CGPoint(x: x, y: top))
                path.addLine(to: CGPoint(x: x, y: bottom))
            }
            for y in lines.horizontal {
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
            }
        }
        ZStack(alignment: .topLeading) {
            path.stroke(SuiteColor.overlayInk, lineWidth: 1).offset(x: pixel, y: pixel)
            path.stroke(SuiteColor.overlayPaper.opacity(0.5), lineWidth: 1)
        }
        .clipShape(Path(CGRect(x: left, y: top, width: right - left, height: bottom - top)))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
