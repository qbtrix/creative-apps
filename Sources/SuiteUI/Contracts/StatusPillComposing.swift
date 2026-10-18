// StatusPillComposing.swift: UC14, the status pills under a canvas (zoom,
// document size, then the trailing pills), and FakeStatusPillComposing, which
// prints the raw zoom ("2.0×") on purpose (the live rule reads
// ViewerZoom.percentText). Foundation only; from
// docs/blueprints/suiteui/contracts/Contracts.swift, with a size that isn't a
// whole number in range reading 0 instead of trapping. PlaneExtent lives in
// ContractTypes.swift. The live rule is SuiteStatusPills (EC-6b of the
// editor-chrome packet).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum PillStyle: Hashable, Sendable { case plain, toggle(isOn: Bool), warning }

public struct StatusPill: Hashable, Sendable {
    public var text: String
    public var style: PillStyle
    public init(text: String, style: PillStyle = .plain) { self.text = text; self.style = style }
}

public protocol StatusPillComposing: Sendable {
    /// Zoom first ("200%", "–" for a zoom that isn't a number), then "1920 × 1080", then `trailing` in order.
    func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill]
}

/// Prints the raw zoom ("2.0×").
public struct FakeStatusPillComposing: StatusPillComposing {
    public init() {}
    public func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill] {
        [StatusPill(text: "\(zoom)×"), StatusPill(text: StatusPillSize.text(documentSize))] + trailing
    }
}

/// "1920 × 1080": each side truncated to a whole number; one that isn't finite or doesn't fit an Int reads 0.
enum StatusPillSize {
    static func text(_ size: PlaneExtent) -> String { "\(whole(size.width)) × \(whole(size.height))" }
    private static func whole(_ value: Double) -> Int { Int(exactly: value.rounded(.towardZero)) ?? 0 }
}
