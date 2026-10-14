// Live stubs (W0). In the repo each is its own file, Live/<Name>.swift, which
// its feature later replaces whole. A stub changes nothing, draws nothing,
// and says why in `unavailableHelp`, so every control that needs it is
// disabled with that text.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveFrameDrawing: FrameDrawing {
    public init() {}
    public var unavailableHelp: String? { "Layers don't draw in the viewer yet (#37)." }
    public func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList {
        HaloDrawList(width: composition.width, height: composition.height, frame: frame, items: [])
    }
}

public struct LiveLayerPlacing: LayerPlacing {
    public init() {}
    public var unavailableHelp: String? { "Layer transforms arrive with the layer inspector (#38)." }
    public func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double? { nil }
    public func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix? { nil }
    public func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] { [] }
}

public struct LivePropertyKeying: PropertyKeying {
    public init() {}
    public var unavailableHelp: String? { "Keys arrive with the layer inspector (#38)." }
    public func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] { [] }
    public func setValue(_ value: Double, for property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func toggleAnimation(_ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func toggleKey(_ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func setParent(_ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Parenting")
    }
}

public struct LiveViewerDragging: ViewerDragging {
    public init() {}
    public var unavailableHelp: String? { "Dragging a layer to key it arrives with #207." }
    public func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String? { nil }
    public func commitMove(_ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Dragging")
    }
}

public struct LiveKeyEasing: KeyEasing {
    public init() {}
    public var unavailableHelp: String? { "Easing arrives with #428." }
    public func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef] { [] }
    public func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing? { nil }
    public func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Easing")
    }
}

public struct LiveProjectHistory: ProjectHistory {
    public init() {}
    public var unavailableHelp: String? { "Undo arrives with #208." }
    public var limit: Int { 0 }
    public func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {}
    public func endCoalescing(in history: inout HaloHistory) {}
    public func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? { nil }
    public func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? { nil }
}

public struct LiveProjectFiles: ProjectFiles {
    public init() {}
    public var unavailableHelp: String? { "Saving and opening projects arrive with #209." }
    public func encode(_ state: HaloDocumentState) throws -> Data { throw HaloEditError.notBuilt("Saving") }
    public func decode(_ data: Data) throws -> HaloDocumentState { throw HaloEditError.notBuilt("Opening") }
}

public struct LivePlaybackClock: PlaybackClock {
    public init() {}
    public var unavailableHelp: String? { "Playback arrives with #37." }
    public func tick(startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool) -> HaloPlaybackTick {
        HaloPlaybackTick(frame: max(0, startFrame), ended: true)
    }
}

public struct LiveFrameRendering: FrameRendering {
    public init() {}
    public var unavailableHelp: String? { "Render Frame arrives with #451." }
    public func render(_ list: HaloDrawList, width: Int, height: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        throw HaloEditError.notBuilt("Rendering")
    }
}

public struct LiveCompositionRendering: CompositionRendering {
    public init() {}
    public var unavailableHelp: String? { "Render… arrives with #429." }
    public func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        throw HaloEditError.notBuilt("Render")
    }
    public func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        .failed(frame: 0, message: HaloEditError.notBuilt("Render").message)
    }
}
