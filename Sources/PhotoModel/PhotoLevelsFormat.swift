// PhotoLevelsFormat.swift: how the Levels Black and White fields show their
// points: as a percent of the tonal range, 0% pure black and 100% pure white,
// so the numbers carry a unit like the other adjustment rows (#1631). The
// stored point stays a fraction in levelsRange; the field shows it times 100
// at `decimals` places, which still shows every levelsStep value apart (one
// thousandth is a tenth of a percent), and a typed percent goes back through
// `point(percent:)`, where AdjustmentSettings clamps and snaps it. `text`
// spells a point as its percent without trailing zeros, the way the field's
// typing draft reads; the bar pads to `decimals` ("0.0%"). Linux-safe.
public enum PhotoLevelsFormat {
    /// The fields' unit.
    public static let unit = "%"
    /// What the fields scrub over: levelsRange in percent.
    public static let range: ClosedRange<Double> =
        percent(AdjustmentSettings.levelsRange.lowerBound)...percent(AdjustmentSettings.levelsRange.upperBound)
    /// The places that show every levelsStep value apart, in percent.
    public static let decimals = max(AdjustmentSettings.levelsDecimals - 2, 0)

    /// A stored point as the percent its field shows.
    public static func percent(_ point: Float) -> Double {
        Double(point) * 100
    }

    /// The point a typed or dragged percent asks for; the settings snap it.
    public static func point(percent: Double) -> Float {
        Float(percent / 100)
    }

    /// A point as text: its percent rounded to `decimals` places, halves away
    /// from zero, no trailing zeros, then the unit ("0%", "50.5%", "100%").
    public static func text(_ point: Float) -> String {
        var scale = 1.0
        for _ in 0..<decimals { scale *= 10 }
        let value = percent(point)
        guard value.isFinite else { return "–" + unit }
        let units = Int64((value * scale).rounded())
        let whole = units / Int64(scale)
        let fraction = abs(units % Int64(scale))
        guard fraction != 0 else { return "\(whole)" + unit }
        var digits = String(fraction)
        digits = String(repeating: "0", count: max(decimals - digits.count, 0)) + digits
        while digits.hasSuffix("0") { digits.removeLast() }
        return "\(whole).\(digits)" + unit
    }
}
