// DesignServices.swift: the use cases a workspace runs on. `.live` is what the
// shipping app uses: each tier-1 use case's Live type (Live/). A Live type whose
// feature hasn't landed forwards to NotBuilt, as the tier-2 slots are, so the
// control is disabled with "<Feature> isn't built yet." and never acts. `.fake`
// is the fixture set the snapshots and the journeys launched with
// `-DesignServices fake` use. Two service sets are equal when their names are,
// so DesignWorkspace stays Equatable. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct DesignServices: Sendable, Equatable {
    public let name: String
    public var marquee: any MarqueeSelecting
    public var transforming: any SelectionTransforming
    public var aligning: any LayerAligning
    public var duplicating: any LayerDuplicating
    public var grouping: any LayerGrouping
    public var clipboard: any LayerClipboard
    public var ordering: any LayerOrdering
    public var styling: any StyleEditing
    public var framing: any ViewFraming
    public var filing: any DocumentFiling
    public var export: any ExportPlanning
    public var pen: any PathDrawing
    public var components: any ComponentLibrary
    public var variables: any VariableEditing

    public static func == (a: DesignServices, b: DesignServices) -> Bool { a.name == b.name }

    /// The fixture fakes for every tier-1 slot; export is `LiveExport` (planning is pure, so the
    /// fakes share it); pen, components and variables stay NotBuilt until D2-2 adds their fakes.
    public static let fake = DesignServices(
        name: "fake", marquee: FakeMarquee(), transforming: FakeTransforming(), aligning: FakeAligning(),
        duplicating: FakeDuplicating(), grouping: FakeGrouping(), clipboard: FakeClipboard(), ordering: FakeOrdering(),
        styling: FakeStyling(), framing: FakeFraming(), filing: FakeFiling(), export: LiveExport(),
        pen: NotBuilt("The Pen tool"), components: NotBuilt("Components"), variables: NotBuilt("Variables"))

    /// The shipping set: every tier-1 slot is its Live type. Marquee, transforming, aligning and
    /// framing act as their features define; `LiveFiling` wraps today's codec; the other five forward
    /// to NotBuilt with their feature's name until that feature fills its file. Export is
    /// `LiveExport` (design-export); pen, components and variables stay NotBuilt until D2-2.
    public static let live = DesignServices(
        name: "live", marquee: LiveMarquee(), transforming: LiveTransforming(), aligning: LiveAligning(),
        duplicating: LiveDuplicating(), grouping: LiveGrouping(), clipboard: LiveClipboard(), ordering: LiveOrdering(),
        styling: LiveStyling(), framing: LiveFraming(), filing: LiveFiling(), export: LiveExport(),
        pen: NotBuilt("The Pen tool"), components: NotBuilt("Components"), variables: NotBuilt("Variables"))
}
