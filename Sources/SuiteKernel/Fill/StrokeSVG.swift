// StrokeSVG.swift (stroke-style SS-1 stub; SS-5 colour to cap; SS-7 dash): a stroke as SVG presentation attributes,
// as FlareCore's SVG export writes them (SVG 1.1 `stroke`, `stroke-opacity`, `stroke-width`, `stroke-linejoin`,
// `stroke-linecap`, `stroke-dasharray`, `stroke-dashoffset`). Colour bytes come from `SampleRules.hex`.

public enum StrokeSVG {
    /// `stroke`'s attributes in writing order, `stroke-opacity` only below 1: the colour as "#rrggbb", the width
    /// clamped to `StrokeRules.widths`, then join and cap, then `stroke-dasharray` (the pattern, space-separated)
    /// and `stroke-dashoffset` (the phase) when the stroke is dashed, as FlareCore's SVG export writes them.
    public static func attributes(_ stroke: VectorStroke) -> [(name: String, value: String)] {
        var out = [(name: "stroke", value: SampleRules.hex(stroke.color).lowercased())]
        let alpha = stroke.color.a.isNaN ? 0 : min(max(stroke.color.a, 0), 1)
        if alpha < 1 { out.append((name: "stroke-opacity", value: number(alpha))) }
        out.append((name: "stroke-width", value: number(StrokeRules.clampedWidth(stroke.width))))
        out.append((name: "stroke-linejoin", value: stroke.join.rawValue))
        out.append((name: "stroke-linecap", value: stroke.cap.rawValue))
        if !stroke.dash.isEmpty {
            out.append((name: "stroke-dasharray", value: stroke.dash.map(number).joined(separator: " ")))
            out.append((name: "stroke-dashoffset", value: number(stroke.dashPhase)))
        }
        return out
    }

    /// `value` rounded to 4 decimals, a whole number without ".0", as FlareCore's SVG export writes numbers;
    /// "0" for a value that isn't finite (callers pass clamped widths and alphas).
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let rounded = (value * 10_000).rounded() / 10_000
        if rounded == 0 { return "0" }
        return rounded == rounded.rounded() && abs(rounded) < 1e15 ? String(Int(rounded)) : String(rounded)
    }
}
