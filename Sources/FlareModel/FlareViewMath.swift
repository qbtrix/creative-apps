// FlareViewMath.swift: the stage's view math (stage-edit SE-2, docs/blueprints/flare.md 3.4 and J14). Zoom In and
// Zoom Out step through `FlareZoom.steps`, clamped to 10%...3200%; the zoom readout says "Fit" or a whole percent;
// a guide's readout names its axis and scene position ("y 300"). SuiteUI's ZoomMath steps the same range but lives
// in a macOS-only target, so the Model keeps its own stops (with no 150%, so 100% zooms in to 200%).
import FlareCore

public enum FlareZoom {
    /// The zoom range, in points per scene point: 10% to 3200%.
    public static let range: ClosedRange<Double> = 0.1...32

    /// The stops Zoom In and Zoom Out step through, smallest first.
    public static let steps: [Double] = [0.1, 0.25, 1.0 / 3, 0.5, 2.0 / 3, 1, 2, 3, 4, 6, 8, 12, 16, 32]

    /// The next step above `zoom`, or the largest; 100% for a zoom that isn't a positive finite number.
    public static func zoomIn(_ zoom: Double) -> Double {
        guard zoom.isFinite, zoom > 0 else { return 1 }
        return steps.first { $0 > zoom * 1.001 } ?? range.upperBound
    }

    /// The next step below `zoom`, or the smallest; 100% for a zoom that isn't a positive finite number.
    public static func zoomOut(_ zoom: Double) -> Double {
        guard zoom.isFinite, zoom > 0 else { return 1 }
        return steps.last { $0 < zoom * 0.999 } ?? range.lowerBound
    }

    /// "Fit" for nil (the stage fits its window), else a whole percent ("200%"); "–" when it isn't a positive
    /// finite number.
    public static func readout(_ zoom: Double?) -> String {
        guard let zoom else { return "Fit" }
        guard zoom.isFinite, zoom > 0 else { return "–" }
        return "\(FlareWorkspace.whole(min(zoom, 10_000) * 100))%"
    }
}

extension FlareWorkspace {
    /// Guide `index` of the selected scene as its mark reads it: "y 300" for a horizontal guide at 300, "x 120" for
    /// a vertical one; nil when there is no such guide.
    public func guideReadout(at index: Int) -> String? {
        guard guides.indices.contains(index) else { return nil }
        let guide = guides[index]
        return "\(guide.axis == .horizontal ? "y" : "x") \(Self.whole(guide.position))"
    }
}
