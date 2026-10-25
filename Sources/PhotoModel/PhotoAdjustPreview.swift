// PhotoAdjustPreview.swift (adjust-everywhere AJ-9): what a FilterSheet's
// Preview shows. A copy of the workspace, scaled so its longest side is at
// most FilterRules.previewSide, takes the sheet's catalog command with its
// sizes in pixels scaled the same way and the selection's rectangle scaled
// with it; the picture comes back as sRGB bytes. The workspace itself never
// changes. Linux-safe.
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
}
