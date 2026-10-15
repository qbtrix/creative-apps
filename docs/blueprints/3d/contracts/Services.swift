// Services.swift: one existential per contract, with .fake (blueprint part 6.5).
// W0 copies this into Sources/PrismModel/PrismServices.swift and adds `.live`,
// whose members start as NotBuilt stubs (Live/<Contract>.swift) and are each
// replaced whole by the feature that builds them. Invariant: PrismWorkspace
// reads services only through this struct, so swapping one member swaps the use case.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct PrismServices: Sendable {
    public var importing: any SceneImporting, primitives: any PrimitiveMaking, extruding: any ShapeExtruding
    public var glyphs: any GlyphOutlining, arranging: any SceneArranging, navigating: any ViewNavigating
    public var picking: any ViewportPicking, gizmo: any GizmoDragging, meshEditing: any MeshEditing
    public var materials: any MaterialEditing, lights: any LightEditing, cameras: any CameraDirecting
    public var keying: any PropertyKeying, easing: any KeyEasing, clock: any PlaybackClock
    public var history: any SceneHistory, files: any SceneFiles, exporting: any SceneExporting
    public var drawing: any FrameDrawing, rendering: any FrameRendering, sequences: any SequenceRendering
    public var handOff: any RenderHandingOff

    public static let fake = PrismServices(
        importing: FakeSceneImporting(), primitives: FakePrimitiveMaking(), extruding: FakeShapeExtruding(),
        glyphs: FakeGlyphOutlining(), arranging: FakeSceneArranging(), navigating: FakeViewNavigating(),
        picking: FakeViewportPicking(), gizmo: FakeGizmoDragging(), meshEditing: FakeMeshEditing(),
        materials: FakeMaterialEditing(), lights: FakeLightEditing(), cameras: FakeCameraDirecting(),
        keying: FakePropertyKeying(), easing: FakeKeyEasing(), clock: FakePlaybackClock(),
        history: FakeSceneHistory(), files: FakeSceneFiles(), exporting: FakeSceneExporting(),
        drawing: FakeFrameDrawing(), rendering: FakeFrameRendering(), sequences: FakeSequenceRendering(),
        handOff: FakeRenderHandingOff())

    /// What W0 ships as `.live` before any feature lands: every member a NotBuilt stub.
    public static let unbuilt = PrismServices(
        importing: NotBuilt("Import"), primitives: NotBuilt("Add"), extruding: NotBuilt("Extrude"),
        glyphs: NotBuilt("Text"), arranging: NotBuilt("Arrange"), navigating: NotBuilt("Navigate"),
        picking: NotBuilt("Select"), gizmo: NotBuilt("Transform"), meshEditing: NotBuilt("Edit Mesh"),
        materials: NotBuilt("Materials"), lights: NotBuilt("Lights"), cameras: NotBuilt("Cameras"),
        keying: NotBuilt("Keys"), easing: NotBuilt("Easing"), clock: NotBuilt("Playback"),
        history: NotBuilt("Undo"), files: NotBuilt("Save and Open"), exporting: NotBuilt("Export"),
        drawing: NotBuilt("Viewport"), rendering: NotBuilt("Render"), sequences: NotBuilt("Render"),
        handOff: NotBuilt("Send To"))
}

/// The W0 live stub: conforms to every contract, does nothing, and says why.
public struct NotBuilt: Sendable {
    public let area: String
    public init(_ area: String) { self.area = area }
    public var unavailableHelp: String? { "\(area) isn't built yet." }
}

extension NotBuilt: SceneImporting {
    public func canImport(_ format: PrismImportFormat) -> Bool { false }
    public func sidecarNames(in data: Data, format: PrismImportFormat) throws(PrismImportError) -> [String] {
        throw .unsupportedFormat(format.rawValue)
    }
    public func importModel(_ data: Data, format: PrismImportFormat, name: String,
                            sidecars: [String: Data]) throws(PrismImportError) -> PrismImportResult {
        throw .unsupportedFormat(format.rawValue)
    }
}
extension NotBuilt: PrimitiveMaking {
    public func mesh(for primitive: PrismPrimitive, id: PrismID, detail: Int) -> PrismMesh {
        PrismMesh(id: id, name: primitive.title, positions: [], faces: [])
    }
    public func light(_ kind: PrismLightKind) -> (PrismLight, PrismTransform) { (PrismLight(kind: kind, intensity: 0), .identity) }
}
extension NotBuilt: ShapeExtruding {
    public func extrude(_ outline: PrismOutline, _ extrusion: PrismExtrusion, id: PrismID,
                        name: String) throws(PrismEditError) -> PrismMesh { throw .outOfRange(unavailableHelp ?? "") }
}
extension NotBuilt: GlyphOutlining {
    public func outline(of text: String, fontName: String, size: Double) -> PrismOutline { PrismOutline(contours: []) }
}
extension NotBuilt: SceneArranging {
    public func worldMatrix(of node: PrismID, in scene: PrismScene, at frame: Int) -> Mat4? { nil }
    public func worldBounds(of nodes: [PrismID], in scene: PrismScene, at frame: Int) -> Box3 { .empty }
    public func reparent(_ node: PrismID, to parent: PrismID?, index: Int, keepWorld: Bool,
                         in scene: inout PrismScene, at frame: Int) throws(PrismEditError) { throw .outOfRange(unavailableHelp ?? "") }
}
extension NotBuilt: ViewNavigating {
    public func orbit(_ view: PrismViewCamera, dx: Double, dy: Double) -> PrismViewCamera { view }
    public func pan(_ view: PrismViewCamera, dx: Double, dy: Double, viewHeightPoints: Double) -> PrismViewCamera { view }
    public func dolly(_ view: PrismViewCamera, factor: Double) -> PrismViewCamera { view }
    public func frame(_ bounds: Box3, in view: PrismViewCamera, aspect: Double) -> PrismViewCamera { view }
    public func preset(_ preset: PrismViewPreset, from view: PrismViewCamera) -> PrismViewCamera { view }
    public func viewMatrix(for viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int) -> (view: Mat4, eye: Vec3)? { nil }
}
extension NotBuilt: ViewportPicking {
    public func ray(at point: ViewPoint, viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int,
                    aspect: Double) -> PrismRay? { nil }
    public func hit(_ ray: PrismRay, in scene: PrismScene, at frame: Int) -> PrismHit? { nil }
}
extension NotBuilt: GizmoDragging {
    public func begin(_ mode: PrismGizmoMode, handle: PrismGizmoHandle, node: PrismID, at point: ViewPoint,
                      viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int, aspect: Double) -> PrismGizmoDrag? { nil }
    public func transform(for drag: PrismGizmoDrag, to point: ViewPoint, viewpoint: PrismViewpoint,
                          in scene: PrismScene, at frame: Int, aspect: Double, snap: PrismSnap) -> PrismTransform {
        drag.startTransform
    }
}
extension NotBuilt: MeshEditing {
    public func unavailableHelp(for op: PrismMeshOpKind) -> String? { unavailableHelp }
    public func pick(_ ray: PrismRay, mesh: PrismMesh, world: Mat4, mode: PrismSelectMode) -> PrismMeshElement? { nil }
    public func apply(_ op: PrismMeshOp, to mesh: PrismMesh, selection: PrismMeshSelection,
                      mode: PrismSelectMode) throws(PrismEditError) -> (mesh: PrismMesh, selection: PrismMeshSelection) {
        throw .outOfRange(unavailableHelp ?? "")
    }
    public func loop(through edge: PrismEdge, in mesh: PrismMesh) -> [PrismEdge] { [edge] }
}
extension NotBuilt: MaterialEditing {
    public var presets: [PrismMaterial] { [] }
    public func update(_ material: PrismMaterial, in scene: inout PrismScene) throws(PrismEditError) { throw .outOfRange(unavailableHelp ?? "") }
    public func assign(_ material: PrismID, to nodes: [PrismID], in scene: inout PrismScene) throws(PrismEditError) {
        throw .outOfRange(unavailableHelp ?? "")
    }
}
extension NotBuilt: LightEditing {
    public func update(_ light: PrismLight, of node: PrismID, in scene: inout PrismScene) throws(PrismEditError) {
        throw .outOfRange(unavailableHelp ?? "")
    }
    public func setEnvironment(_ environment: PrismEnvironment, in scene: inout PrismScene) throws(PrismEditError) {
        throw .outOfRange(unavailableHelp ?? "")
    }
    public var rigNames: [String] { [] }
    public func rig(named name: String, around bounds: Box3) -> [(name: String, light: PrismLight, transform: PrismTransform)] { [] }
}
extension NotBuilt: CameraDirecting {
    public func camera(matching view: PrismViewCamera) -> (PrismCamera, PrismTransform) { (PrismCamera(), .identity) }
    public func setActiveCamera(_ node: PrismID?, in scene: inout PrismScene) throws(PrismEditError) { throw .outOfRange(unavailableHelp ?? "") }
    public func update(_ camera: PrismCamera, of node: PrismID, in scene: inout PrismScene) throws(PrismEditError) {
        throw .outOfRange(unavailableHelp ?? "")
    }
}
extension NotBuilt: PropertyKeying {
    public func value(of property: PrismProperty, node: PrismID, in scene: PrismScene, at frame: Int) -> Double? { nil }
    public func isAnimated(_ property: PrismProperty, node: PrismID, in scene: PrismScene) -> Bool { false }
    public func setValue(_ value: Double, of property: PrismProperty, node: PrismID, at frame: Int,
                         in scene: inout PrismScene) throws(PrismEditError) { throw .outOfRange(unavailableHelp ?? "") }
    public func toggleAnimation(_ property: PrismProperty, node: PrismID, at frame: Int,
                                in scene: inout PrismScene) throws(PrismEditError) { throw .outOfRange(unavailableHelp ?? "") }
    public func toggleKey(_ property: PrismProperty, node: PrismID, at frame: Int,
                          in scene: inout PrismScene) throws(PrismEditError) { throw .outOfRange(unavailableHelp ?? "") }
    public func keyFrames(of node: PrismID, in scene: PrismScene) -> [Int] { [] }
}
extension NotBuilt: KeyEasing {
    public func setEasing(_ easing: PrismEasing, for keys: [PrismKeyRef], in scene: inout PrismScene) throws(PrismEditError) {
        throw .outOfRange(unavailableHelp ?? "")
    }
}
extension NotBuilt: PlaybackClock {
    public func frame(at now: Double, startTime: Double, startFrame: Int, settings: PrismSceneSettings, loops: Bool) -> Int { startFrame }
}
extension NotBuilt: SceneHistory {
    public func record(_ before: PrismDocumentState, name: String, coalesceKey: String?, into history: inout PrismHistory) {}
    public func undo(_ current: PrismDocumentState, history: inout PrismHistory) -> PrismDocumentState? { nil }
    public func redo(_ current: PrismDocumentState, history: inout PrismHistory) -> PrismDocumentState? { nil }
}
extension NotBuilt: SceneFiles {
    public func encode(_ state: PrismDocumentState) throws(PrismFileError) -> PrismFilePackage { throw .damaged(unavailableHelp ?? "") }
    public func decode(_ package: PrismFilePackage) throws(PrismFileError) -> PrismDocumentState { throw .notAPrismFile }
}
extension NotBuilt: SceneExporting {
    public func canExport(_ format: PrismExportFormat) -> Bool { false }
    public func export(_ scene: PrismScene, format: PrismExportFormat, at frame: Int) throws(PrismFileError) -> Data {
        throw .unsupportedExport(format.rawValue)
    }
}
extension NotBuilt: FrameDrawing {
    public func drawList(_ scene: PrismScene, selection: [PrismID], viewpoint: PrismViewpoint, at frame: Int,
                         aspect: Double) -> PrismDrawList? { nil }
}
extension NotBuilt: FrameRendering {
    public func render(_ list: PrismDrawList, meshes: [PrismMesh], textures: [PrismTexture], width: Int, height: Int,
                       quality: PrismRenderQuality) throws(PrismRenderError) -> PrismImage { throw .sinkFailed(unavailableHelp ?? "") }
}
extension NotBuilt: SequenceRendering {
    public func problem(with plan: PrismRenderPlan, scene: PrismScene) -> PrismRenderError? { .sinkFailed(unavailableHelp ?? "") }
    public func run(_ plan: PrismRenderPlan, scene: PrismScene, viewpoint: PrismViewpoint, drawing: any FrameDrawing,
                    renderer: any FrameRendering, sink: any RenderSink, progress: @Sendable (Int) -> Void,
                    isCancelled: @Sendable () -> Bool) -> PrismRenderOutcome {
        .failed(frame: plan.frames.lowerBound, message: unavailableHelp ?? "")
    }
}
extension NotBuilt: RenderHandingOff {
    public func refusal(for target: PrismHandOffTarget, plan: PrismRenderPlan) -> String? { unavailableHelp }
    public func request(for target: PrismHandOffTarget, plan: PrismRenderPlan, outcome: PrismRenderOutcome,
                        settings: PrismSceneSettings, sourceDocument: String?) -> PrismHandOffRequest? { nil }
}
