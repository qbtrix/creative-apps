// Contracts.swift: one protocol per Prism use case (blueprint part 6.2).
// W0 copies this file into Sources/PrismModel/Contracts/PrismContracts.swift.
// Rules every conformance keeps:
// - Reads take values; writes take the scene `inout` and throw a typed error,
//   changing nothing when they throw.
// - No contract records undo: PrismWorkspace.edit(_:_:) does, so fakes and live
//   types are tested without a workspace.
// - `unavailableHelp` is nil once the service works; a W0 live stub returns the
//   reason, and every control that needs the service is disabled with it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public protocol PrismService: Sendable {
    /// Nil when the service can act; else the sentence a disabled control shows.
    var unavailableHelp: String? { get }
}

// MARK: Bring things in

/// UC1 Import a model file (glTF/GLB, OBJ, STL, PLY in core; USD and USDZ through the macOS importer).
public protocol SceneImporting: PrismService {
    func canImport(_ format: PrismImportFormat) -> Bool
    /// Files the model points at (glTF buffers and images, an OBJ's .mtl), so the app can read
    /// them from the same folder before `importModel`.
    func sidecarNames(in data: Data, format: PrismImportFormat) throws(PrismImportError) -> [String]
    func importModel(_ data: Data, format: PrismImportFormat, name: String,
                     sidecars: [String: Data]) throws(PrismImportError) -> PrismImportResult
}

/// UC2 Add a primitive or an empty, a light or a camera.
public protocol PrimitiveMaking: PrismService {
    /// A mesh of about `detail` segments around (spheres, cylinders, cones, tori); 1 unit across.
    func mesh(for primitive: PrismPrimitive, id: PrismID, detail: Int) -> PrismMesh
    /// The default light of a kind (`PrismLightKind.v1`), placed 4 units up and aimed at the origin.
    func light(_ kind: PrismLightKind) -> (PrismLight, PrismTransform)
}

/// UC3 Extrude text or vector art into a solid with depth and a bevel.
public protocol ShapeExtruding: PrismService {
    func extrude(_ outline: PrismOutline, _ extrusion: PrismExtrusion, id: PrismID,
                 name: String) throws(PrismEditError) -> PrismMesh
}

/// UC3b Read vector art (SVG 1.1 paths, basic shapes and solid fills; Design's pasteboard SVG) as shapes.
public protocol VectorArtReading: PrismService {
    /// Filled closed shapes in document order, y up, in SVG user units; skipped features as warnings.
    func shapes(fromSVG data: Data) throws(PrismImportError) -> (shapes: [PrismVectorShape], warnings: [String])
}

/// UC3c Decode an image (PNG, JPEG, HEIC; Radiance HDR and OpenEXR for environments) for a texture or the
/// environment; the macOS live type uses ImageIO. Anything it can't read throws `.unreadableImage`.
public protocol ImageDecoding: PrismService {
    func decode(_ data: Data, name: String, id: PrismID) throws(PrismImportError) -> PrismTexture
}

/// UC22 Evaluate a mesh's modifiers (subdivision, mirror) for the viewport, render and export.
public protocol ModifierEvaluating: PrismService {
    /// The mesh after `modifiers` in order; throws `.outOfRange` with the reason for a result over
    /// `PrismLimits.maximumTriangles` (the workspace clamps the level before calling, so a person sees the row's reason).
    func evaluate(_ mesh: PrismMesh, modifiers: [PrismModifier], forRender: Bool) throws(PrismEditError) -> PrismMesh
}

/// UC3 (platform half) Glyph outlines for a string; the macOS live type uses Core Text.
public protocol GlyphOutlining: PrismService {
    /// The string's outline at `size` units per em, baseline at y = 0, left edge at x = 0.
    func outline(of text: String, fontName: String, size: Double) -> PrismOutline
}

/// UC21 Model: edit a mesh's vertices, edges and faces (tier 1 by research R1, R3, R9).
public protocol MeshEditing: PrismService {
    /// Nil when this operation can run, else why not (a fake may leave some to the live engine).
    func unavailableHelp(for op: PrismMeshOpKind) -> String?
    /// The element under a ray in a mesh placed at `world`: the nearest face hit, or in vertex and
    /// edge mode the vertex or edge of that face nearest the hit point.
    func pick(_ ray: PrismRay, mesh: PrismMesh, world: Mat4, mode: PrismSelectMode) -> PrismMeshElement?
    /// Applies an operation to the selection; returns the new mesh and what is selected after it
    /// (the new faces after an extrude or inset, the new loop after a loop cut). Refuses with
    /// `.nothingSelected` on an empty selection, or `.outOfRange` with the reason.
    func apply(_ op: PrismMeshOp, to mesh: PrismMesh, selection: PrismMeshSelection,
               mode: PrismSelectMode) throws(PrismEditError) -> (mesh: PrismMesh, selection: PrismMeshSelection)
    /// The edge loop through an edge (Option-click selects it), walked both ways across valence-4
    /// vertices; it stops at a pole (valence ≠ 4) or a boundary, so on a cube it is the edge alone.
    func loop(through edge: PrismEdge, in mesh: PrismMesh) -> [PrismEdge]
}

// MARK: Arrange

/// UC4 Where things are: local and world transforms at a frame, parenting.
public protocol SceneArranging: PrismService {
    func worldMatrix(of node: PrismID, in scene: PrismScene, at frame: Int) -> Mat4?
    /// World-space bounds of a node and its children at a frame; empty for lights, cameras and groups with nothing.
    func worldBounds(of nodes: [PrismID], in scene: PrismScene, at frame: Int) -> Box3
    /// Moves `node` under `parent` (nil: the scene root) at the outliner position `index`.
    /// With `keepWorld` the node stays where it is on screen. A cycle is refused.
    func reparent(_ node: PrismID, to parent: PrismID?, index: Int, keepWorld: Bool,
                  in scene: inout PrismScene, at frame: Int) throws(PrismEditError)
}

/// UC5 Orbit, pan, dolly and frame the free view. Pure camera math.
public protocol ViewNavigating: PrismService {
    /// Drag deltas in points; 0.25° per point.
    func orbit(_ view: PrismViewCamera, dx: Double, dy: Double) -> PrismViewCamera
    /// Moves the target in the view plane by a fraction of the view's height.
    func pan(_ view: PrismViewCamera, dx: Double, dy: Double, viewHeightPoints: Double) -> PrismViewCamera
    /// Scroll or pinch: factor > 1 moves closer; clamped to the view camera's distance limits.
    func dolly(_ view: PrismViewCamera, factor: Double) -> PrismViewCamera
    /// Fits `bounds` in the view at `aspect` with a 10% margin; an empty box resets to the default view.
    func frame(_ bounds: Box3, in view: PrismViewCamera, aspect: Double) -> PrismViewCamera
    func preset(_ preset: PrismViewPreset, from view: PrismViewCamera) -> PrismViewCamera
    /// View matrix and eye for a viewpoint (the free view, or a scene camera at a frame).
    func viewMatrix(for viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int) -> (view: Mat4, eye: Vec3)?
}

/// UC6 Click to select: the ray under the pointer and what it hits first.
public protocol ViewportPicking: PrismService {
    func ray(at point: ViewPoint, viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int,
             aspect: Double) -> PrismRay?
    /// The nearest visible mesh node the ray hits, by triangle; nil for empty space.
    func hit(_ ray: PrismRay, in scene: PrismScene, at frame: Int) -> PrismHit?
}

/// UC7 Move, rotate and scale with the on-canvas gizmo.
public protocol GizmoDragging: PrismService {
    /// Starts a drag on a handle of the selected node's gizmo; nil if the node is gone.
    func begin(_ mode: PrismGizmoMode, handle: PrismGizmoHandle, node: PrismID, at point: ViewPoint,
               viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int, aspect: Double) -> PrismGizmoDrag?
    /// The node's new local transform for the pointer at `point`. Never writes the scene.
    func transform(for drag: PrismGizmoDrag, to point: ViewPoint, viewpoint: PrismViewpoint,
                   in scene: PrismScene, at frame: Int, aspect: Double, snap: PrismSnap) -> PrismTransform
}

// MARK: Look

/// UC8 Give an object a material and edit it.
public protocol MaterialEditing: PrismService {
    /// The starting looks offered in the material picker: Matte, Plastic, Rubber, Metal, Chrome, Gold, Glow.
    var presets: [PrismMaterial] { get }
    /// Replaces the material with the same id after clamping metallic and roughness to 0...1
    /// and emissive strength to 0...100; refuses an unknown id.
    func update(_ material: PrismMaterial, in scene: inout PrismScene) throws(PrismEditError)
    /// Assigns a material to mesh nodes; refuses a node that is not a mesh.
    func assign(_ material: PrismID, to nodes: [PrismID], in scene: inout PrismScene) throws(PrismEditError)
}

/// UC9 Light the scene: edit a light, the environment, or apply a lighting preset.
public protocol LightEditing: PrismService {
    func update(_ light: PrismLight, of node: PrismID, in scene: inout PrismScene) throws(PrismEditError)
    func setEnvironment(_ environment: PrismEnvironment, in scene: inout PrismScene) throws(PrismEditError)
    /// "Three-Point", "Studio Soft", "Rim": the lights a preset adds around `bounds`.
    var rigNames: [String] { get }
    func rig(named name: String, around bounds: Box3) -> [(name: String, light: PrismLight, transform: PrismTransform)]
}

/// UC10 Frame the shot: scene cameras, the active camera, a camera from the view.
public protocol CameraDirecting: PrismService {
    /// A camera that sees exactly what the free view sees.
    func camera(matching view: PrismViewCamera) -> (PrismCamera, PrismTransform)
    func setActiveCamera(_ node: PrismID?, in scene: inout PrismScene) throws(PrismEditError)
    func update(_ camera: PrismCamera, of node: PrismID, in scene: inout PrismScene) throws(PrismEditError)
}

// MARK: Animate

/// UC11 Key properties on the timeline.
public protocol PropertyKeying: PrismService {
    func value(of property: PrismProperty, node: PrismID, in scene: PrismScene, at frame: Int) -> Double?
    func isAnimated(_ property: PrismProperty, node: PrismID, in scene: PrismScene) -> Bool
    /// Sets a value: on an animated property it adds or moves the key at `frame`;
    /// on one that is not animated it sets the base value (no key).
    func setValue(_ value: Double, of property: PrismProperty, node: PrismID, at frame: Int,
                  in scene: inout PrismScene) throws(PrismEditError)
    /// Stopwatch: on keys the current value at `frame` and at the last frame; off removes the track.
    func toggleAnimation(_ property: PrismProperty, node: PrismID, at frame: Int,
                         in scene: inout PrismScene) throws(PrismEditError)
    /// Key-here diamond: adds a key at `frame`, or removes the one there.
    func toggleKey(_ property: PrismProperty, node: PrismID, at frame: Int,
                   in scene: inout PrismScene) throws(PrismEditError)
    /// Every key's frame for a node (the timeline lane), sorted, no repeats.
    func keyFrames(of node: PrismID, in scene: PrismScene) -> [Int]
}

/// UC12 Ease keys.
public protocol KeyEasing: PrismService {
    func setEasing(_ easing: PrismEasing, for keys: [PrismKeyRef], in scene: inout PrismScene) throws(PrismEditError)
}

/// UC13 Play: the clock that maps wall time to frames.
public protocol PlaybackClock: PrismService {
    /// The frame to show at `now` seconds for playback started at `startTime` from `startFrame`.
    func frame(at now: Double, startTime: Double, startFrame: Int, settings: PrismSceneSettings, loops: Bool) -> Int
}

// MARK: Keep work

/// UC14 Undo and redo: whole-document steps with names.
public protocol SceneHistory: PrismService {
    /// Records `before` as one step named `name`; a step with the same `coalesceKey` as the
    /// last one merges into it (a drag or a scrub). Always clears redo.
    func record(_ before: PrismDocumentState, name: String, coalesceKey: String?, into history: inout PrismHistory)
    func undo(_ current: PrismDocumentState, history: inout PrismHistory) -> PrismDocumentState?
    func redo(_ current: PrismDocumentState, history: inout PrismHistory) -> PrismDocumentState?
}

/// The undo stack the workspace stores. 100 steps.
public struct PrismHistory: Sendable, Hashable {
    public struct Step: Sendable, Hashable {
        public var name: String, coalesceKey: String?, state: PrismDocumentState
        public init(name: String, coalesceKey: String?, state: PrismDocumentState) {
            self.name = name; self.coalesceKey = coalesceKey; self.state = state
        }
    }
    public var undo: [Step], redo: [Step], coalescing: Bool
    public init(undo: [Step] = [], redo: [Step] = [], coalescing: Bool = false) {
        self.undo = undo; self.redo = redo; self.coalescing = coalescing
    }
    public static let limit = 100
    public var undoTitle: String? { undo.last.map { "Undo \($0.name)" } }
    public var redoTitle: String? { redo.last.map { "Redo \($0.name)" } }
}

/// UC15 Save and open a .prism package.
public protocol SceneFiles: PrismService {
    func encode(_ state: PrismDocumentState) throws(PrismFileError) -> PrismFilePackage
    /// Refuses a package that isn't Prism's, is newer, is damaged (any mesh `problem`, a missing
    /// buffer, an id used twice, a parent cycle) or is over `PrismFilePackage.maximumBytes`.
    func decode(_ package: PrismFilePackage) throws(PrismFileError) -> PrismDocumentState
}

/// UC16 Export the scene as a model file for other tools and the web.
public protocol SceneExporting: PrismService {
    func canExport(_ format: PrismExportFormat) -> Bool
    /// The scene at `frame` (keys baked to that frame); glb carries materials and textures,
    /// obj and stl geometry only, usdz geometry and materials.
    func export(_ scene: PrismScene, format: PrismExportFormat, at frame: Int) throws(PrismFileError) -> Data
}

// MARK: Draw and render

/// UC17 What the viewport draws at a frame from a viewpoint.
public protocol FrameDrawing: PrismService {
    func drawList(_ scene: PrismScene, selection: [PrismID], viewpoint: PrismViewpoint, at frame: Int,
                  aspect: Double) -> PrismDrawList?
}

/// UC18 Render one frame to pixels. Core holds the reference renderer (Linux); the macOS
/// live type renders the same draw list offscreen with the viewport's engine.
public protocol FrameRendering: PrismService {
    func render(_ list: PrismDrawList, meshes: [PrismMesh], textures: [PrismTexture], width: Int, height: Int,
                quality: PrismRenderQuality) throws(PrismRenderError) -> PrismImage
}

/// Where rendered frames go: the PNG writer, the movie writer, or a counting sink in tests.
public protocol RenderSink: Sendable {
    func begin(_ plan: PrismRenderPlan) throws(PrismRenderError)
    func write(_ image: PrismImage, index: Int, plan: PrismRenderPlan) throws(PrismRenderError)
    /// The files written, in order.
    func finish(_ plan: PrismRenderPlan) throws(PrismRenderError) -> [String]
    func cancel(_ plan: PrismRenderPlan)
}

/// UC19 Render a frame range to files.
public protocol SequenceRendering: PrismService {
    /// Checks a plan against the scene: nil when it can run, else the error the sheet shows.
    func problem(with plan: PrismRenderPlan, scene: PrismScene) -> PrismRenderError?
    func run(_ plan: PrismRenderPlan, scene: PrismScene, viewpoint: PrismViewpoint, drawing: any FrameDrawing,
             renderer: any FrameRendering, sink: any RenderSink, progress: @Sendable (Int) -> Void, isCancelled: @Sendable () -> Bool) -> PrismRenderOutcome
}

/// UC20 Send a finished render to Halo, Flare or Design (the suite carries it).
public protocol RenderHandingOff: PrismService {
    /// Nil when the target can take this outcome, else why not ("Halo takes image sequences from version …").
    func refusal(for target: PrismHandOffTarget, plan: PrismRenderPlan) -> String?
    func request(for target: PrismHandOffTarget, plan: PrismRenderPlan, outcome: PrismRenderOutcome,
                 settings: PrismSceneSettings, sourceDocument: String?) -> PrismHandOffRequest?
}
