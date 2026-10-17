// FlarePaint.swift: fill and stroke on the workspace (inspector-timeline IT-2). IT-0 declares the signatures as stubs
// (lead.md rule 18): the read is a fixed readout of FlareCore's default stroke, and every setter changes nothing and
// says why in `paintError`. IT-2 fills the bodies in through `services.properties` without changing a signature.
import FlareCore

/// The selection's fill and stroke as the inspector shows them. A nil value reads as Mixed.
public struct PaintReadout: Sendable, Equatable {
    public var fillHex: String?, fillIsGradient: Bool
    public var strokeHex: String?, strokeWidth: Double?, cap: Stroke.Cap?, join: Stroke.Join?

    public init(fillHex: String?, fillIsGradient: Bool, strokeHex: String?, strokeWidth: Double?,
                cap: Stroke.Cap?, join: Stroke.Join?) {
        (self.fillHex, self.fillIsGradient) = (fillHex, fillIsGradient)
        (self.strokeHex, self.strokeWidth, self.cap, self.join) = (strokeHex, strokeWidth, cap, join)
    }
}

extension FlareWorkspace {
    /// What a paint setter says until IT-2 lands.
    public static let paintNotBuilt = "Fill and stroke editing isn't built yet."

    /// Stub (IT-0): nil with no layer selected, else a black fill and FlareCore's default stroke.
    public var paint: PaintReadout? {
        guard selectedLayerID != nil else { return nil }
        let stroke = Stroke()
        return PaintReadout(fillHex: "000000", fillIsGradient: false, strokeHex: "000000",
                            strokeWidth: stroke.width, cap: stroke.cap, join: stroke.join)
    }

    /// Sets the selection's solid fill; refuses a bad hex with a reason. Stub (IT-0): changes nothing.
    public mutating func setFill(hex: String) { paintError = Self.paintNotBuilt }

    /// Sets the stroke width, called once on the bar's release. Stub (IT-0): changes nothing.
    public mutating func setStrokeWidth(_ width: Double) { paintError = Self.paintNotBuilt }

    /// Sets the stroke cap. Stub (IT-0): changes nothing.
    public mutating func setStrokeCap(_ cap: Stroke.Cap) { paintError = Self.paintNotBuilt }

    /// Sets the stroke join. Stub (IT-0): changes nothing.
    public mutating func setStrokeJoin(_ join: Stroke.Join) { paintError = Self.paintNotBuilt }

    /// Sets the stroke color; refuses a bad hex with a reason. Stub (IT-0): changes nothing.
    public mutating func setStrokeColor(hex: String) { paintError = Self.paintNotBuilt }
}
