// PhotoAdjustPreview.swift (adjust-everywhere AJ-9): what a FilterSheet's
// Preview shows. A copy of the workspace, scaled so its longest side is at
// most FilterRules.previewSide, takes the sheet's catalog command with its
// sizes in pixels scaled the same way and the selection's rectangle scaled
// with it; the picture comes back as sRGB bytes. The workspace itself never
// changes. `adjustCommand` is the command and params a sheet's filter or kind
// runs as. Linux-safe.
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace {
    /// The picture after catalog command `id` with `params`, on a copy no larger than `side` on its longest side;
    /// nil with no image open or when the command can't run.
    public func adjustPreview(_ id: String, _ params: [String: JSONValue],
                              side: Int = FilterRules.previewSide) -> DecodedImage? {
        guard let canvas, side > 0 else { return nil }
        var copy = self, values = params
        let longest = max(canvas.width, canvas.height)
        if longest > side {
            let s = Double(side) / Double(longest)
            func scaled(_ v: Int) -> Int { Int((Double(v) * s).rounded()) }
            let rect = selection
            guard (try? copy.resizeImage(width: max(scaled(canvas.width), 1), height: max(scaled(canvas.height), 1)))
                != nil else { return nil }
            if let r = rect { copy.setSelection(PixelRect(x: scaled(r.x), y: scaled(r.y), width: max(scaled(r.width), 1),
                                                          height: max(scaled(r.height), 1))) }
            for key in ["radius", "distance"] { if case .number(let v)? = values[key] { values[key] = .number(v * s) } }
        }
        guard (try? Self.catalog.run(id, params: .object(values), on: &copy)) != nil,
              let picture = try? copy.composite(), let bytes = try? picture.rgba8() else { return nil }
        return DecodedImage(rgba8: bytes, width: picture.width, height: picture.height)
    }

    /// The catalog command and params that run `filter`, as a filter sheet's OK and Preview send them.
    public static func adjustCommand(_ filter: ImagingFilter) -> (id: String, params: [String: JSONValue]) {
        let p: [String: Double]
        switch filter {
        case .gaussianBlur(let r): p = ["radius": r]
        case .motionBlur(let a, let d): p = ["degrees": a, "distance": d]
        case .sharpen(let a, let r, let t): p = ["amount": a, "radius": r, "threshold": t]
        case .reduceNoise(let s, let d): p = ["strength": s, "detail": d]
        case .addNoise(let a, let m, let seed):
            return ("filter.\(filter.id)", ["amount": .number(a), "monochrome": .bool(m), "seed": .number(Double(seed))])
        }
        return ("filter.\(filter.id)", p.mapValues { .number($0) })
    }

    /// The catalog command and params that set `kind` on what the inspector edits.
    public static func adjustCommand(_ kind: ImagingKind) -> (id: String, params: [String: JSONValue]) {
        guard case .blackAndWhite(let w) = kind else { return ("adjust.invert", [:]) }
        let weights: [String: Double] = ["red": w.red, "yellow": w.yellow, "green": w.green,
                                         "cyan": w.cyan, "blue": w.blue, "magenta": w.magenta]
        return ("adjust.black-and-white", ["weights": .object(weights.mapValues { .number($0) })])
    }
}
