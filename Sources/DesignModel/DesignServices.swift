// DesignServices.swift: the use cases a workspace runs on. `.live` is what the
// shipping app uses: each use case's live type once its feature lands, and
// NotBuilt before that, so the control is disabled with "<Feature> isn't built
// yet." and never acts. Two service sets are equal when their names are, so
// DesignWorkspace stays Equatable. Linux-safe.
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

    /// D0-2's `.live`: every slot NotBuilt. D0-2b replaces the tier-1 slots with the Live stubs
    /// (`LiveFiling` alone wraps today's codec; the others forward to NotBuilt) and D2-2 the tier-2 ones.
    public static let live = DesignServices(
        name: "live", marquee: NotBuilt("Marquee selection"), transforming: NotBuilt("Editing several layers"),
        aligning: NotBuilt("Aligning several layers"), duplicating: NotBuilt("Duplicate"), grouping: NotBuilt("Group"),
        clipboard: NotBuilt("Copy and paste"), ordering: NotBuilt("Reordering layers"), styling: NotBuilt("Style editing"),
        framing: NotBuilt("Zoom to Selection"), filing: NotBuilt("Saving"), export: NotBuilt("Export"),
        pen: NotBuilt("The Pen tool"), components: NotBuilt("Components"), variables: NotBuilt("Variables"))
}
