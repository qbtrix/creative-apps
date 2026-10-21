// DesignLoupe.swift (eyedropper DY-3): what the Eyedropper's loupe shows at the pointer, and the pick a click
// sends. `loupe(at:modifiers:size:)` answers only with the Eyedropper active on an open page and the pointer
// over the artboard: the pointer's page point, the colour `sampledColor` (DesignSample+Kernel) reads there as
// 8-bit sRGB (nil when nothing paints there), and whether the pick goes to the stroke (Option held) or the
// fill. `pick(at:toStroke:)` is a click's one call into `applySample`, its refusal as a DesignRefusal for the
// status line. Linux-safe.
import SuiteKernel

/// The Eyedropper's loupe at the pointer.
public struct DesignLoupe: Equatable, Sendable {
    /// The pointer on the page, in page points.
    public let point: DesignPoint
    /// The colour under the pointer; nil when nothing paints there.
    public let color: DesignColor?
    /// Option is held: a click sets the selection's stroke colour, not its fill.
    public let toStroke: Bool

    public init(point: DesignPoint, color: DesignColor?, toStroke: Bool) {
        (self.point, self.color, self.toStroke) = (point, color, toStroke)
    }
}

extension DesignWorkspace {
    /// The loupe at `point` (page points) with `modifiers` held, reading a `size` square; nil unless the
    /// Eyedropper is active on an open page and the pointer is over the artboard.
    public func loupe(at point: DesignPoint?, modifiers: DesignModifiers, size: SampleSize) -> DesignLoupe? {
        guard tool == .eyedropper, isOpen, let point, point.isFinite else { return nil }
        let read = sampledColor(at: Point(x: point.x, y: point.y), size: size)
        let color = read.map { color in
            DesignColor(
                UInt8(clamping: SampleRules.byte(color.r)), UInt8(clamping: SampleRules.byte(color.g)),
                UInt8(clamping: SampleRules.byte(color.b)))
        }
        return DesignLoupe(point: point, color: color, toStroke: modifiers.contains(.option))
    }

    /// A click of the Eyedropper at `point`: the colour there onto the selection's stroke or fill, one step.
    public mutating func pick(at point: DesignPoint, toStroke: Bool) throws(DesignRefusal) {
        do {
            try applySample(at: Point(x: point.x, y: point.y), toStroke: toStroke)
        } catch let refusal as DesignRefusal {
            throw refusal
        } catch {
            throw DesignRefusal.notBuilt("Picking a color")
        }
    }
}
