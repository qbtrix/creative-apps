// NotBuilt.swift: what FlareServices holds for a member whose fake has not landed (docs/blueprints/flare.md,
// 6.3). It conforms to every contract: reads are empty and writes throw it, carrying `reason`, so the
// control shows disabled with that reason and the document never changes.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

public struct NotBuilt: Error, Hashable, Sendable, CustomStringConvertible {
    public var reason: String
    public init(reason: String) { self.reason = reason }
    public var description: String { reason }
}

extension NotBuilt: SceneEditing {
    public func newDocument(_: CanvasPreset) -> Document { Document() }
    public func addScene(_: CanvasPreset, in _: inout CommandEngine) throws -> String { throw self }
    public func renameScene(_: String, to _: String, in _: inout CommandEngine) throws { throw self }
    public func removeScene(_: String, in _: inout CommandEngine) throws { throw self }
    public func reorderScene(_: String, to _: Int, in _: inout CommandEngine) throws { throw self }
    public func setCanvas(_: String, width _: Double, height _: Double, background _: FlareColor, in _: inout CommandEngine) throws { throw self }
    public func setTiming(_: String, fps _: Int, durationFrames _: Int, in _: inout CommandEngine) throws { throw self }
    public func addGuide(_: Guide.Axis, at _: Double, sceneID _: String, in _: inout CommandEngine) throws -> Int { throw self }
    public func moveGuide(at _: Int, to _: Double, sceneID _: String, coalesceKey _: String?, in _: inout CommandEngine) throws { throw self }
    public func removeGuide(at _: Int, sceneID _: String, in _: inout CommandEngine) throws { throw self }
}

extension NotBuilt: StageRendering, StageHitTesting {
    public func drawList(_: Document, sceneID _: String, frame _: Int, editing _: String?) -> StageDrawList {
        StageDrawList(width: 0, height: 0, background: FlareColor(r: 1, g: 1, b: 1), items: [])
    }
    public func hit(_: Document, sceneID _: String, frame _: Int, at _: Point, tolerance _: Double) -> StageAddress? { nil }
    public func marquee(_: Document, sceneID _: String, frame _: Int, rect _: Rect) -> [StageAddress] { [] }
    public func bounds(_: Document, sceneID _: String, frame _: Int, of _: [StageAddress]) -> Rect? { nil }
}

extension NotBuilt: ShapeBuilding {
    public func unavailableHelp(for _: FlareTool) -> String? { reason }
    public func draft(_: FlareTool, from _: Point, to _: Point, modifiers _: DragModifiers, previous _: ShapeDraft?) -> ShapeDraft? { nil }
    public func commit(_: ShapeDraft, sceneID _: String, aboveLayerID _: String?, in _: inout CommandEngine) throws -> String { throw self }
    public func boxResult(_: BoxGesture, layers _: [String], document _: Document, sceneID _: String,
                          frame _: Int, box _: Rect) -> [String: [String: Double]] { [:] }
    public func commitBox(_: BoxGesture, layers _: [String], sceneID _: String, frame _: Int, box _: Rect,
                          autoKey _: Bool, in _: inout CommandEngine) throws { throw self }
    public func setPath(_: FlarePath, of _: StageAddress, in _: inout CommandEngine) throws { throw self }
    public func translate(_: [StageAddress], dx _: Double, dy _: Double, in _: inout CommandEngine) throws { throw self }
    public func delete(_: [StageAddress], in _: inout CommandEngine) throws { throw self }
    public func duplicate(layers _: [String], owner _: LayerOwner, in _: inout CommandEngine) throws -> [String] { throw self }
    public func copy(layers _: [String], owner _: LayerOwner, from _: Document) throws -> Data { throw self }
    public func paste(_: Data, owner _: LayerOwner, aboveLayerID _: String?, offset _: Double, in _: inout CommandEngine) throws -> [String] { throw self }
}

extension NotBuilt: PropertyAnimating, KeyframeEditing, KeyframeEasing, OnionSkinning {
    public func properties(_: Document, owner _: LayerOwner, layerIDs _: [String], frame _: Int) -> [AnimatedProperty] { [] }
    public func setValue(_: Double, of _: String, owner _: LayerOwner, layerIDs _: [String], frame _: Int,
                         autoKey _: Bool, coalesceKey _: String?, in _: inout CommandEngine) throws { throw self }
    public func toggleAnimated(_: String, owner _: LayerOwner, layerID _: String, frame _: Int, lastFrame _: Int, in _: inout CommandEngine) throws { throw self }
    public func toggleKey(_: String, owner _: LayerOwner, layerID _: String, frame _: Int, in _: inout CommandEngine) throws { throw self }
    public func setFill(_: Fill, of _: [StageAddress], in _: inout CommandEngine) throws { throw self }
    public func setStroke(_: Stroke?, of _: [StageAddress], in _: inout CommandEngine) throws { throw self }
    public func rows(_: Document, owner _: LayerOwner) -> [TimelineRow] { [] }
    public func labels(_: Document, sceneID _: String) -> [String: Int] { [:] }
    public func moveKeys(_: Set<KeyRef>, by _: Int, owner _: LayerOwner, coalesceKey _: String?, in _: inout CommandEngine) throws { throw self }
    public func removeKeys(_: Set<KeyRef>, owner _: LayerOwner, in _: inout CommandEngine) throws { throw self }
    public func insertFrames(_: Int, at _: Int, layerIDs _: [String], owner _: LayerOwner, in _: inout CommandEngine) throws { throw self }
    public func removeFrames(_: Int, at _: Int, layerIDs _: [String], owner _: LayerOwner, in _: inout CommandEngine) throws { throw self }
    public func setLabel(_: String?, at _: Int, sceneID _: String, in _: inout CommandEngine) throws { throw self }
    public var presets: [EasingPreset] { [] }
    public func curve(_: Easing, count _: Int) -> [Point] { [] }
    public func setEasing(_: Easing, at _: KeyRef, owner _: LayerOwner, coalesceKey _: String?, in _: inout CommandEngine) throws { throw self }
    public func ghosts(_: Document, sceneID _: String, layerIDs _: [String], frame _: Int, settings _: OnionSettings) -> [Ghost] { [] }
    public func motionPath(_: Document, owner _: LayerOwner, layerID _: String) -> [Point] { [] }
}

extension NotBuilt: LibraryManaging {
    public func symbols(_: Document) -> [SymbolSummary] { [] }
    public func swatches(_: Document) -> [Swatch] { [] }
    public func convertToSymbol(_: [String], sceneID _: String, name _: String, in _: inout CommandEngine) throws -> String { throw self }
    public func placeInstance(of _: String, at _: Point, owner _: LayerOwner, layerID _: String, in _: inout CommandEngine) throws -> StageAddress { throw self }
    public func setInstanceTransform(_: Transform, at _: StageAddress, coalesceKey _: String?, in _: inout CommandEngine) throws { throw self }
    public func setInstancePlayback(_: Instance.LoopMode, firstFrame _: Int, at _: StageAddress, in _: inout CommandEngine) throws { throw self }
    public func renameSymbol(_: String, to _: String, in _: inout CommandEngine) throws { throw self }
    public func removeSymbol(_: String, in _: inout CommandEngine) throws { throw self }
    public func addSwatch(_: Swatch, in _: inout CommandEngine) throws { throw self }
    public func removeSwatch(_: String, in _: inout CommandEngine) throws { throw self }
}

extension NotBuilt: StateMachineEditing, StateMachinePreviewing {
    public func machines(_: Document) -> [StateMachine] { [] }
    public func issues(_: Document, machineID _: String) -> [MachineIssue] { [] }
    public func addMachine(named _: String, firstState _: MachineState, in _: inout CommandEngine) throws -> String { throw self }
    public func renameMachine(_: String, to _: String, in _: inout CommandEngine) throws { throw self }
    public func removeMachine(_: String, in _: inout CommandEngine) throws { throw self }
    public func addState(_: MachineState, to _: String, in _: inout CommandEngine) throws { throw self }
    public func updateState(_: MachineState, in _: String, in _: inout CommandEngine) throws { throw self }
    public func removeState(_: String, from _: String, in _: inout CommandEngine) throws { throw self }
    public func addTransition(_: FlareTransition, to _: String, in _: inout CommandEngine) throws { throw self }
    public func updateTransition(at _: Int, to _: FlareTransition, in _: String, in _: inout CommandEngine) throws { throw self }
    public func removeTransition(at _: Int, from _: String, in _: inout CommandEngine) throws { throw self }
    public func addInput(_: MachineInput, to _: String, in _: inout CommandEngine) throws { throw self }
    public func updateInput(_: MachineInput, in _: String, in _: inout CommandEngine) throws { throw self }
    public func removeInput(named _: String, from _: String, in _: inout CommandEngine) throws { throw self }
    public func setInitialState(_: String, of _: String, in _: inout CommandEngine) throws { throw self }
    public func start(_: Document, machineID _: String) throws -> MachinePreview { throw self }
    public func set(_: String, to _: InputValue, _ preview: MachinePreview, in _: Document) -> MachinePreview { preview }
    public func fire(_: String, _ preview: MachinePreview, in _: Document) -> MachinePreview { preview }
    public func advance(_ preview: MachinePreview, frames _: Int, in _: Document) -> MachinePreview { preview }
}

extension NotBuilt: Exporting, AnimationAssisting {
    public func warnings(_: Document, options _: ExportOptions) -> [String] { [] }
    public func export(_: Document, options _: ExportOptions, rasterizer _: any FrameRasterizing,
                       progress _: @Sendable (Double) -> Void) async throws -> ExportResult { throw self }
    public var unavailableHelp: String? { reason }
    public func propose(_: String, document _: Document, selection _: [StageAddress], frame _: Int) async throws -> AssistProposal { throw self }
}
