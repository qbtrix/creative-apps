// DesignSample+Kernel.swift (eyedropper DY-1 stubs, DY-5 bodies): Design's adapter onto SuiteKernel's
// SampleTarget (Sample/SampleCommands.swift), so the Eyedropper tool, `color.sample` and `color.pick` read a
// colour the same way. A vector document samples what it paints: the topmost visible painted layer at the point
// (its fill, its gradient's colour there through GradientRules, or its stroke), never the selection and never
// pixels. An apply sets the selection's fill, or its stroke with Option, as one named step. Linux-safe.
import SuiteKernel

extension DesignWorkspace: SampleTarget {
    /// Why nothing can be sampled now; nil once a document is open.
    public var sampleHelp: String? {
        isOpen ? nil : "Open a design first."
    }

    /// The colour of the topmost visible painted layer at `point` (page points); nil on empty canvas.
    /// DY-1 stub: reads nothing until DY-5.
    public func sampledColor(at point: Point, size: SampleSize) -> FillColor? {
        nil
    }

    /// Sets the selection's fill (or its stroke when `toStroke`) to the colour at `point`, one "Fill" or
    /// "Stroke" step. DY-1 stub: refuses, changing nothing, until DY-5.
    public mutating func applySample(at point: Point, toStroke: Bool) throws {
        throw DesignRefusal.notBuilt("Picking a color")
    }
}
