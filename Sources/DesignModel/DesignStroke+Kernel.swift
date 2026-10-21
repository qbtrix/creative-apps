// DesignStroke+Kernel.swift (stroke-style DK-1 stubs, DK-6 bodies): Design's stroke seen as the kernel's
// `VectorStroke`, and the workspace as SuiteKernel's `StrokeTarget`. `DesignNode.vectorStroke` is the one way the
// views read a stroke (never `DesignStroke`'s fields): today's colour and width, with the default join and cap and
// no dash, until DK-5 makes `DesignStroke` the kernel's type. `strokeHelp`, `trimHelp` and `selectedStroke` are
// real now; `setStroke` throws `StrokeRules.notBuilt` until DK-6, which also registers the nine stroke commands.
// Until then `strokeChange` turns the stroke editor's intents into the inspector's `.stroke` style change.
// Linux-safe.
import SuiteKernel

extension DesignNode {
    /// This layer's stroke as the kernel's; nil when it has none.
    public var vectorStroke: VectorStroke? {
        stroke.map { VectorStroke(color: $0.color.kernelColor, width: $0.width) }
    }
}

/// Design's one adapter between its 0...255 colour and the kernel's 0...1 `FillColor`; the fill and the stroke
/// both go through it.
extension DesignColor {
    /// The kernel's colour as Design's, its opacity dropped; each part is `SampleRules.byte`, so out-of-range
    /// parts clamp and NaN is 0.
    init(kernel color: FillColor) {
        func byte(_ part: Double) -> UInt8 { UInt8(clamping: SampleRules.byte(part)) }
        self.init(byte(color.r), byte(color.g), byte(color.b))
    }

    /// This opaque colour as the kernel's.
    var kernelColor: FillColor {
        FillColor(r: Double(red) / 255, g: Double(green) / 255, b: Double(blue) / 255)
    }
}

extension DesignWorkspace: StrokeTarget {
    /// Why trim never runs in Design.
    public static let trimPathsHelp = "Trim paths are for animation, in Flare and Halo."

    /// "Open a design first." with no file; else the Stroke row's help (nothing selected, editing text, locked).
    public var strokeHelp: String? {
        isOpen ? styleHelp(.stroke) : "Open a design first."
    }

    public var trimHelp: String? { Self.trimPathsHelp }

    /// The primary selected layer's stroke.
    public var selectedStroke: VectorStroke? { selectedNode?.vectorStroke }

    /// Why the editor's dash rows can't act yet.
    public var strokeDashHelp: String? { StrokeRules.waitingCore }

    /// Why the Join and Cap chips can't act until DK-5 (`strokeChange` drops them); the editor's `styleHelp`.
    public static let joinCapHelp = "Design's strokes keep the default join and cap for now."

    /// `joinCapHelp` on a stroked layer; nil without a stroke, where the editor shows Add Stroke alone.
    public var strokeStyleHelp: String? { selectedStroke == nil ? nil : Self.joinCapHelp }

    /// Stub until DK-6: refuses with `StrokeRules.notBuilt` and changes nothing.
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        throw StrokeRules.notBuilt
    }

    /// The editor's `intent` as the inspector's style change on the selection, and whether it is a scrub's sample
    /// (preview it, land it at the end) rather than a whole edit. Nil for what Design's stroke can't hold until
    /// DK-5 (join, cap, dash, trim) and for a colour or width with no stroke to change.
    public func strokeChange(_ intent: StrokeIntent) -> (change: DesignStyleChange, scrub: Bool)? {
        let current = selectedNodes.lazy.compactMap(\.stroke).first
        switch intent {
        case .add: return (.stroke(.default), false)
        case .remove: return (.stroke(nil), false)
        case .width(let width, let drag):
            guard let current else { return nil }
            return (.stroke(DesignStroke(color: current.color, width: StrokeRules.clampedWidth(width))), drag != nil)
        case .color(let color, let drag):
            guard let current else { return nil }
            return (.stroke(DesignStroke(color: DesignColor(kernel: color), width: current.width)), drag != nil)
        case .join, .cap, .dash, .trim: return nil
        }
    }
}
