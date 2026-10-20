// DesignStroke+Kernel.swift (stroke-style DK-1 stubs; DK-6 fills the bodies): a node's stroke read as the
// kernel's VectorStroke, and the workspace as the kernel's StrokeTarget. The readouts are real: the stroke help is
// today's style help, the selection's stroke is the primary node's, and trim says it belongs to the animation apps.
// `setStroke` throws `StrokeRules.notBuilt` until DK-6, so the Join, Cap and Dash pickers stay off with a reason.
// The signatures here never change; DK-6 only replaces the bodies. Linux-safe.
import SuiteKernel

extension DesignNode {
    /// This node's stroke as the kernel's VectorStroke: its colour (0...1, opaque) and width, with the
    /// kernel's default join and cap until DesignStroke carries them; nil when the node draws none.
    public var vectorStroke: VectorStroke? {
        stroke.map { stroke in
            let c = stroke.color
            let color = FillColor(r: Double(c.red) / 255, g: Double(c.green) / 255, b: Double(c.blue) / 255, a: 1)
            return VectorStroke(color: color, width: stroke.width)
        }
    }
}

extension DesignColor {
    /// `color`'s red, green and blue in 0...255, rounded; a channel out of 0...1 or NaN clamps. Alpha is dropped.
    public init(_ color: FillColor) {
        self.init(Self.channel(color.r), Self.channel(color.g), Self.channel(color.b))
    }

    private static func channel(_ value: Double) -> UInt8 {
        value.isNaN ? 0 : UInt8(min(max(value, 0), 1) * 255 + 0.5)
    }
}

extension DesignWorkspace: StrokeTarget {
    /// Why trim never shows in Design: it animates a stroke along its path.
    static let designTrimHelp = "Trim paths are for animation, in Flare and Halo."
    /// Why Join and Cap can't act on a stroked selection until DK-6 builds the stroke commands.
    static let strokeStylesHelp = NotBuilt("Stroke styles").help
    /// Why a stroke style can't act on a selection that has no stroke.
    static let addStrokeFirstHelp = "Add a stroke first."

    /// Why the selection's stroke can't change; nil when it can (today's Stroke row help).
    public var strokeHelp: String? { styleHelp(.stroke) }
    public var trimHelp: String? { Self.designTrimHelp }
    /// The primary selected node's stroke; nil with nothing selected or no stroke.
    public var selectedStroke: VectorStroke? { selectedNode?.vectorStroke }

    /// Sets `stroke` on every selected node as one step named `name`, a run of one `drag` being one step.
    /// Stub: throws `StrokeRules.notBuilt` until DK-6.
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        throw StrokeRules.notBuilt
    }

    /// Why the Stroke editor's Join and Cap pickers are off; nil once they can act (DK-6).
    public var strokeStyleHelp: String? {
        strokeHelp ?? (selectedStroke == nil ? Self.addStrokeFirstHelp : Self.strokeStylesHelp)
    }

    /// Why the Dash picker is off: as Join and Cap, then creative-core's missing dash fields.
    public var strokeDashHelp: String? {
        strokeHelp ?? (selectedStroke == nil ? Self.addStrokeFirstHelp : StrokeRules.waitingCore)
    }
}
