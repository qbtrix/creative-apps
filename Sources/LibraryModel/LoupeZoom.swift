// LoupeZoom.swift: the loupe's zoom steps and the View menu's zoom titles.
// `LoupeZoom` and the stored `loupeZoom` live in LibraryCatalog.swift; this
// file adds the scale each zoom draws at, Zoom In and Zoom Out through
// `steps` (12.5% to 800%, fit counting as the scale the view measured), and
// the titles that read Larger and Smaller Thumbnails in the grid. A scale
// that isn't a positive finite number never becomes the zoom. Linux-safe.

extension LoupeZoom {
    /// The scales Zoom In and Zoom Out step through, smallest first; 1 is 100%.
    public static let steps: [Double] = [0.125, 0.25, 0.5, 1, 2, 4, 8]

    /// The scale this zoom draws at, for a fit scale the view measured. A fit
    /// that isn't a positive finite number draws at 100%; so does a bad scale.
    public func scale(fit: Double) -> Double {
        let fitScale = Self.isUsable(fit) ? fit : 1
        switch self {
        case .fit: return fitScale
        case .actual: return 1
        case .scale(let scale): return Self.isUsable(scale) ? scale : fitScale
        }
    }

    static func isUsable(_ scale: Double) -> Bool {
        scale.isFinite && scale > 0
    }
}

extension LibraryCatalog {
    /// Sets the loupe's zoom; a scale of 1 is `.actual`, and a scale that
    /// isn't a positive finite number changes nothing.
    public mutating func zoomLoupe(_ zoom: LoupeZoom) {
        if case .scale(let scale) = zoom {
            guard LoupeZoom.isUsable(scale) else { return }
            loupeZoom = scale == 1 ? .actual : zoom
        } else {
            loupeZoom = zoom
        }
    }

    /// The next step above (positive) or below the current scale; fit counts
    /// as its scale. Moves `steps` steps, staying put past either end.
    public mutating func stepZoom(by steps: Int, fitScale: Double) {
        let count = min(steps.magnitude, UInt(LoupeZoom.steps.count))
        for _ in 0..<count {
            let current = loupeZoom.scale(fit: fitScale)
            let target = steps > 0
                ? LoupeZoom.steps.first { $0 > current * 1.0001 }
                : LoupeZoom.steps.last { $0 < current / 1.0001 }
            guard let target else { return }
            loupeZoom = target == 1 ? .actual : .scale(target)
        }
    }

    /// "Larger Thumbnails" in the grid, "Zoom In" in the loupe.
    public var zoomInTitle: String {
        mode == .grid ? "Larger Thumbnails" : "Zoom In"
    }

    /// "Smaller Thumbnails" in the grid, "Zoom Out" in the loupe.
    public var zoomOutTitle: String {
        mode == .grid ? "Smaller Thumbnails" : "Zoom Out"
    }
}
