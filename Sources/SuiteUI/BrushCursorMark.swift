// BrushCursorMark.swift: the brush cursor in the CanvasMarks family (#953): a
// ring of a document-pixel diameter at the zoom, ink over a paper halo. It
// takes no clicks and is hidden from accessibility.
import SwiftUI

public struct BrushCursorMark: View {
    private let point: CGPoint?
    private let diameter: Double, zoom: Double

    public init(point: CGPoint?, diameter: Double, zoom: Double) { (self.point, self.diameter, self.zoom) = (point, diameter, zoom) }

    /// The ring's box in view points, centred on `point` at `zoom`; nil without a point.
    public nonisolated static func frame(point: CGPoint?, diameter: Double, zoom: Double) -> CGRect? {
        guard let point else { return nil }
        let side = max(diameter, 0) * zoom
        return CGRect(x: point.x * zoom - side / 2, y: point.y * zoom - side / 2, width: side, height: side)
    }

    public var body: some View {
        if let ring = Self.frame(point: point, diameter: diameter, zoom: zoom) {
            let shape = Path(ellipseIn: ring)
            ZStack {
                shape.stroke(SuiteColor.overlayPaper, lineWidth: SuiteSize.pointMarkPaper)
                shape.stroke(SuiteColor.overlayInk, lineWidth: SuiteSize.pointMarkInk)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
