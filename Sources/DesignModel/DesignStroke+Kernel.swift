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
        stroke.map { VectorStroke(color: Self.fillColor($0.color), width: $0.width) }
    }

    /// An opaque 0...255 colour as the kernel's 0...1 one.
    static func fillColor(_ color: DesignColor) -> FillColor {
        FillColor(r: Double(color.red) / 255, g: Double(color.green) / 255, b: Double(color.blue) / 255)
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
            return (.stroke(DesignStroke(color: Self.designColor(color), width: current.width)), drag != nil)
        case .join, .cap, .dash, .trim: return nil
        }
    }

    /// A 0...1 kernel colour as Design's 0...255 one, its opacity dropped; out-of-range and NaN parts clamp.
    static func designColor(_ color: FillColor) -> DesignColor {
        func byte(_ part: Double) -> UInt8 { part.isNaN ? 0 : UInt8((min(max(part, 0), 1) * 255).rounded()) }
        return DesignColor(byte(color.r), byte(color.g), byte(color.b))
    }
}
