// StrokeSVG.swift (stroke-style SS-1 stub; SS-5 colour to cap, SS-7 dash): a stroke as SVG presentation attributes,
// as FlareCore's SVG export writes them (SVG 1.1 `stroke`, `stroke-opacity`, `stroke-width`, `stroke-linejoin`,
// `stroke-linecap`, `stroke-dasharray`, `stroke-dashoffset`).

public enum StrokeSVG {
    /// `stroke`'s attributes in writing order, `stroke-opacity` only below 1. Stub: `[]`; SS-5 fills this in.
    public static func attributes(_ stroke: VectorStroke) -> [(name: String, value: String)] { [] }
}
