// FontPickerRules+Size.swift: how the font picker's Size row reads and drags
// (findings #4778, #4779). The row shows whole points ("12 pt", not
// "12.00 pt"). Its bar drags over the text sizes people use, 1...200, while
// typing still reaches every size in TextRules.sizes, so 12 and 36 sit at
// visibly different places on the bar.
import Foundation

extension FontPickerRules {
    /// The places the Size row shows: sizes are whole points.
    public static let sizeDecimals = 0

    /// The sizes the Size bar spans; a typed size beyond it pins the bar to its end.
    public static let sizeBarRange: ClosedRange<Double> = 1...200

    /// Where `size` sits on the Size bar: clamped into `sizeBarRange`; not a number sits at its start.
    public static func sizeBarPosition(_ size: Double) -> Double {
        guard !size.isNaN else { return sizeBarRange.lowerBound }
        return min(max(size, sizeBarRange.lowerBound), sizeBarRange.upperBound)
    }
}
