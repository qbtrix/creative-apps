// StatusPillComposing.swift: UC14 (SJ6), the text and style of each status
// pill in a ViewerStatusBar, and FakeStatusPillComposing, which prints the raw
// zoom ("2.0×") on purpose (the live rule reads ViewerZoom.percentText).
// Foundation only; verbatim from
// docs/blueprints/suiteui/contracts/Contracts.swift. PillStyle is the
// contract's Foundation twin of the view's StatusPillStyle; EC-6a maps one
// onto the other. The live rule is SuiteStatusPills.
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
        [StatusPill(text: "\(zoom)×"), StatusPill(text: "\(Int(documentSize.width)) × \(Int(documentSize.height))")] + trailing
    }
}
