// CanvasMarks.swift: marks an editor draws over document content inside a
// CanvasViewport's overlay, in document pixels at the canvas zoom: a
// selection's marching-ants outline, and a pending crop's frame with the
// outside dimmed and the rule-of-thirds lines. Black and white so they read on
// any pixels. They never take a click; the canvas gesture does.
import SwiftUI

/// A document rectangle at `zoom`, for stroking and filling.
private struct DocumentRect: Shape {
    let rect: CGRect
    let zoom: Double

    func path(in _: CGRect) -> Path {
        Path(CGRect(x: rect.minX * zoom, y: rect.minY * zoom, width: rect.width * zoom, height: rect.height * zoom))
    }
}

/// A selection's outline: a black line under white dashes.
public struct SelectionOutline: View {
    private let rect: CGRect
    private let zoom: Double

    /// `rect` in document pixels; `zoom` in points per pixel.
    public init(rect: CGRect, zoom: Double) {
        self.rect = rect
        self.zoom = zoom
    }

    public var body: some View {
        let shape = DocumentRect(rect: rect, zoom: zoom)
        ZStack {
            shape.stroke(SuiteColor.overlayInk, lineWidth: 1)
            shape.stroke(SuiteColor.overlayPaper, style: StrokeStyle(lineWidth: 1, dash: [SuiteSpacing.xs]))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A pending crop: everything outside `rect` dimmed, the rect framed in white
/// with its thirds marked.
public struct CropShade: View {
    private let rect: CGRect
    private let documentSize: CGSize
    private let zoom: Double

    public init(rect: CGRect, documentSize: CGSize, zoom: Double) {
        self.rect = rect
        self.documentSize = documentSize
        self.zoom = zoom
    }

    public var body: some View {
        let frame = DocumentRect(rect: rect, zoom: zoom)
        let whole = DocumentRect(rect: CGRect(origin: .zero, size: documentSize), zoom: zoom)
        ZStack {
            Path { path in
                path.addPath(whole.path(in: .zero))
                path.addPath(frame.path(in: .zero))
            }
            .fill(SuiteColor.cropShade, style: FillStyle(eoFill: true))
            Path { path in
                for third in [1.0 / 3, 2.0 / 3] {
                    let x = (rect.minX + rect.width * third) * zoom
                    let y = (rect.minY + rect.height * third) * zoom
                    path.move(to: CGPoint(x: x, y: rect.minY * zoom))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY * zoom))
                    path.move(to: CGPoint(x: rect.minX * zoom, y: y))
                    path.addLine(to: CGPoint(x: rect.maxX * zoom, y: y))
                }
            }
            .stroke(SuiteColor.overlayPaper.opacity(0.5), lineWidth: 1)
            frame.stroke(SuiteColor.overlayPaper, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
