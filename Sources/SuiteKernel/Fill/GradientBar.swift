// GradientBar.swift (gradient-fill, #4047): the gradient editor's stop bar as numbers, so the drawing and the drag
// read one mapping. The bar is inset half a handle each side, so offsets 0...1 run from handle/2 to width - handle/2
// and the end stops' handles stay inside the editor's column. The colour row names the selected stop ("Stop 2 · 50%").
public enum GradientBar {
    /// The x a stop at `offset` is centred at in a bar `width` wide whose handles are `handle` across.
    public static func x(of offset: Double, width: Double, handle: Double) -> Double {
        handle / 2 + min(max(offset, 0), 1) * run(width: width, handle: handle)
    }

    /// The offset under `x`, clamped to 0...1; 0 in a bar no wider than a handle.
    public static func offset(at x: Double, width: Double, handle: Double) -> Double {
        let run = run(width: width, handle: handle)
        guard run > 0 else { return 0 }
        return min(max((x - handle / 2) / run, 0), 1)
    }

    /// The colour row's label for stop `index`: "Stop 2 · 50%"; "Color" for a solid or a stop it doesn't have.
    public static func stopLabel(_ index: Int, of fill: Fill) -> String {
        guard GradientRules.type(of: fill) != .solid, fill.stops.indices.contains(index) else { return "Color" }
        return "Stop \(index + 1) · \(Int((fill.stops[index].offset * 100).rounded()))%"
    }

    /// The length offsets 0...1 span: the bar less a handle.
    private static func run(width: Double, handle: Double) -> Double { max(width - handle, 0) }
}
