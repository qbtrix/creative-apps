// HaloProject.swift: the state behind Halo's window (motion graphics). Holds
// the project's compositions, the selected one and the selected layer in it.
// Each composition keeps its own playhead (HaloTimeline.swift).
// The document part (compositions, selection, id counters) is one stored
// `document`; beside it sit the services and every other stored state v1
// needs, each written only by the file its comment names. Stored state is
// `public internal(set)`: HaloModel's extensions write their own property,
// HaloApp can't. `==` compares everything but `services`.
// Linux-safe: no UI imports. HaloApp changes it only through the methods here.
// The selected layer, when set, is always a layer of the selected composition.
// Composition ids are never reused and names stay unique; once a project has a
// composition it always keeps at least one. A refused rename of a known
// composition stays in `refusedRename` until a rename succeeds or it is
// dismissed.
import CoreRaster
import FlareCore

/// A composition: a sized, timed canvas that layers play in. Codable, so a
/// project file holds it as it is, playhead included.
public struct HaloComposition: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var width: Int
    public var height: Int
    public var framesPerSecond: Int
    public var durationFrames: Int
    /// The composition's layers, top first.
    public var layers: [HaloLayer]
    /// The frame the viewer shows, in 0..<durationFrames; HaloProject's
    /// `scrub(to:)` keeps it there.
    public var playheadFrame: Int = 0

    public init(
        id: String, name: String, width: Int, height: Int, framesPerSecond: Int, durationFrames: Int,
        layers: [HaloLayer] = []
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.durationFrames = durationFrames
        self.layers = layers
    }

    /// Length in seconds; 0 when the frame rate is not positive.
    public var durationSeconds: Double {
        framesPerSecond > 0 ? Double(durationFrames) / Double(framesPerSecond) : 0
    }

    /// The layer count as the viewer's readout shows it ("3 layers").
    public var layerSummary: String {
        switch layers.count {
        case 0: "No layers"
        case 1: "1 layer"
        default: "\(layers.count) layers"
        }
    }
}

public struct HaloProject: Sendable, Equatable {
    /// Compositions, selection and the id counters: what undo restores and a
    /// file holds. Only this file writes it.
    public internal(set) var document = HaloDocumentState()
    /// The use cases' implementations; `.live` in the app, `.fake` in tests.
    public internal(set) var services: HaloServices
    /// Undo and redo steps; written by `HaloHistory.swift` and `edit`.
    public internal(set) var history = HaloHistory()
    /// The transport's state; written by `HaloPlayback.swift`.
    public internal(set) var playback = HaloPlaybackState()
    /// A layer being dragged in the viewer; written by `HaloViewerDrag.swift`.
    public internal(set) var viewerDrag: HaloViewerDragState?
    /// The keys picked for easing; written by `HaloKeySelection.swift`.
    public internal(set) var selectedKeys: Set<HaloKeyRef> = []
    /// The project file's name, path and status; written by `HaloFiles.swift`.
    public internal(set) var file = HaloFileState()
    /// The frame Render Frame shows; written by `HaloRenderFrame.swift`.
    public internal(set) var renderedFrame: HaloShownFrame?
    /// A running or finished render; written by `HaloRenderJob.swift`.
    public internal(set) var renderJob: HaloRenderJobState?
    /// A refused edit's control and message, shown under that control.
    public internal(set) var refusal: HaloRefusal?
    /// The last refused rename, so the window can show why; nil once handled.
    public internal(set) var refusedRename: RefusedRename?

    /// A project on the live services, as the app ships.
    public init() { self.init(services: .live) }

    public init(services: HaloServices) { self.services = services }

    /// Every stored value but `services`, which hold no state of their own.
    public static func == (a: HaloProject, b: HaloProject) -> Bool {
        a.document == b.document && a.history == b.history && a.playback == b.playback
            && a.viewerDrag == b.viewerDrag && a.selectedKeys == b.selectedKeys && a.file == b.file
            && a.renderedFrame == b.renderedFrame && a.renderJob == b.renderJob && a.refusal == b.refusal
            && a.refusedRename == b.refusedRename
    }

    /// The compositions, in sidebar order.
    public var compositions: [HaloComposition] { document.compositions }
    public var selectedCompositionID: String? { document.selectedCompositionID }
    /// Always a layer of the selected composition, or nil.
    public var selectedLayerID: String? { document.selectedLayerID }

    public var selectedComposition: HaloComposition? {
        document.compositions.first { $0.id == selectedCompositionID }
    }

    public var selectedLayer: HaloLayer? {
        selectedComposition?.layers.first { $0.id == selectedLayerID }
    }

    /// Whether Layer > New can add a layer: only with a composition selected.
    public var canAddLayer: Bool { selectedComposition != nil }

    /// What the New Composition sheet starts with: 1080p, 30 fps, 10 seconds,
    /// named after the next id ("Comp 3").
    public var suggestedSettings: CompositionSettings {
        CompositionSettings(name: uniqueName("Comp \(document.nextCompositionNumber)"))
    }

    /// Whether Delete can remove a composition: never the last one.
    public var canDeleteComposition: Bool { document.compositions.count > 1 }

    /// Adds a composition with the suggested settings and selects it.
    public mutating func newComposition() {
        newComposition(suggestedSettings)
    }

    /// Adds a composition from valid `settings` and selects it; a taken name gets a number.
    @discardableResult
    public mutating func newComposition(_ settings: CompositionSettings) -> Bool {
        guard let frames = settings.durationFrames else { return false }
        let comp = HaloComposition(
            id: takeCompositionID(), name: uniqueName(settings.name.normalizedName), width: settings.width,
            height: settings.height, framesPerSecond: settings.framesPerSecond, durationFrames: frames)
        document.compositions.append(comp)
        document.selectedCompositionID = comp.id
        document.selectedLayerID = nil
        return true
    }

    /// Copies a composition and its layers in under the original, named
    /// "<name> copy" ("<name> copy 2", ...), and selects the copy; a copied
    /// layer's parent is the copy of its parent. An unknown id is refused.
    @discardableResult
    public mutating func duplicateComposition(_ id: String) -> Bool {
        guard let index = document.compositions.firstIndex(where: { $0.id == id }) else { return false }
        let original = document.compositions[index]
        let newID = takeCompositionID()
        var newIDs: [String: String] = [:]
        for layer in original.layers {
            let suffix = layer.id.hasPrefix(original.id) ? String(layer.id.dropFirst(original.id.count)) : "-\(layer.id)"
            newIDs[layer.id] = newID + suffix
        }
        // Each copied layer follows the copy of its parent, never the original.
        let layers = original.layers.map { layer in
            var copy = layer.withID(newIDs[layer.id] ?? newID + "-\(layer.id)")
            copy.parentID = layer.parentID.flatMap { newIDs[$0] }
            return copy
        }
        let copy = HaloComposition(
            id: newID, name: uniqueName("\(original.name) copy"), width: original.width, height: original.height,
            framesPerSecond: original.framesPerSecond, durationFrames: original.durationFrames, layers: layers)
        document.compositions.insert(copy, at: index + 1)
        document.selectedCompositionID = newID
        document.selectedLayerID = nil
        return true
    }

    /// Renames a composition; an empty or taken name, or an unknown id, is
    /// refused. Refusing a known composition keeps the typed name and the
    /// reason in `refusedRename`; a rename that succeeds clears it.
    @discardableResult
    public mutating func renameComposition(_ id: String, to name: String) -> Bool {
        guard let index = document.compositions.firstIndex(where: { $0.id == id }) else { return false }
        if let problem = renameProblem(id, to: name) {
            refusedRename = RefusedRename(id: id, name: name, problem: problem)
            return false
        }
        document.compositions[index].name = name.normalizedName
        refusedRename = nil
        return true
    }

    /// Why renaming composition `id` to `name` would be refused, as the alert
    /// says it; nil when the rename would succeed. Names that look the same
    /// (whitespace, invisible format characters, letter case, composed or
    /// decomposed accents) count as taken.
    public func renameProblem(_ id: String, to name: String) -> String? {
        let name = name.normalizedName
        guard document.compositions.contains(where: { $0.id == id }) else { return "The composition no longer exists." }
        if name.isEmpty { return "Enter a name for the composition." }
        let key = name.nameKey
        if document.compositions.contains(where: { $0.id != id && $0.name.nameKey == key }) {
            return "“\(name)” is already used by another composition. Choose a different name."
        }
        return nil
    }

    /// Forgets the refused rename, as when the user cancels it.
    public mutating func dismissRefusedRename() {
        refusedRename = nil
    }

    /// Deletes a composition, never the last one; deleting the selected one
    /// selects its neighbor below (or above, at the end).
    @discardableResult
    public mutating func deleteComposition(_ id: String) -> Bool {
        guard canDeleteComposition, let index = document.compositions.firstIndex(where: { $0.id == id }) else { return false }
        document.compositions.remove(at: index)
        if refusedRename?.id == id { refusedRename = nil }
        if selectedCompositionID == id {
            document.selectedCompositionID = document.compositions[min(index, document.compositions.count - 1)].id
            document.selectedLayerID = nil
        }
        return true
    }

    /// The next unused composition id.
    private mutating func takeCompositionID() -> String {
        defer { document.nextCompositionNumber += 1 }
        return "comp-\(document.nextCompositionNumber)"
    }

    /// `base`, or `base` with the first free number after it ("Comp 1 copy 2").
    /// Names compare as `renameProblem` compares them, so a look-alike is taken.
    private func uniqueName(_ base: String) -> String {
        let keys = Set(document.compositions.map(\.name.nameKey))
        guard keys.contains(base.nameKey) else { return base }
        var number = 2
        while keys.contains("\(base) \(number)".nameKey) { number += 1 }
        return "\(base) \(number)"
    }

    /// Selects a composition by id. An unknown id is ignored; selecting
    /// another composition clears the layer selection.
    public mutating func selectComposition(_ id: String) {
        guard document.compositions.contains(where: { $0.id == id }), id != selectedCompositionID else { return }
        document.selectedCompositionID = id
        document.selectedLayerID = nil
    }

    /// Adds a layer of `kind` on top of the selected composition, spanning its
    /// whole duration and named by kind ("Solid 1", "Solid 2"), and selects
    /// it. Does nothing with no composition selected.
    public mutating func newLayer(_ kind: HaloLayerKind) {
        guard let index = document.compositions.firstIndex(where: { $0.id == selectedCompositionID }) else { return }
        let comp = document.compositions[index]
        let number = comp.layers.filter { $0.kind == kind }.count + 1
        let layer = HaloLayer(
            id: "\(comp.id)-layer-\(comp.layers.count + 1)", name: "\(kind.title) \(number)", kind: kind,
            inFrame: 0, outFrame: comp.durationFrames, color: kind.defaultColor)
        document.compositions[index].layers.insert(layer, at: 0)
        document.selectedLayerID = layer.id
    }

    /// Selects a layer of the selected composition by id. An unknown id is
    /// ignored.
    public mutating func selectLayer(_ id: String) {
        if selectedComposition?.layers.contains(where: { $0.id == id }) == true { document.selectedLayerID = id }
    }

    /// Sets the selected layer's opacity; HaloLayer clamps it to 0...1. NaN is
    /// ignored here, so a bad inspector entry keeps the current opacity.
    public mutating func setSelectedLayerOpacity(_ opacity: Double) {
        guard !opacity.isNaN else { return }
        updateSelectedLayer { $0.opacity = opacity }
    }

    /// Sets how the selected layer blends with the layers under it.
    public mutating func setSelectedLayerBlendMode(_ mode: BlendMode) {
        updateSelectedLayer { $0.blendMode = mode }
    }

    /// Changes the selected composition in place; nothing without one. The
    /// timeline's methods (HaloTimeline.swift) go through here.
    mutating func updateSelectedComposition(_ change: (inout HaloComposition) -> Void) {
        guard let c = document.compositions.firstIndex(where: { $0.id == selectedCompositionID }) else { return }
        change(&document.compositions[c])
    }

    private mutating func updateSelectedLayer(_ change: (inout HaloLayer) -> Void) {
        guard let c = document.compositions.firstIndex(where: { $0.id == selectedCompositionID }),
            let l = document.compositions[c].layers.firstIndex(where: { $0.id == selectedLayerID })
        else { return }
        change(&document.compositions[c].layers[l])
    }
}

/// The frame Render Frame shows and the composition it was made from.
/// render-out computes staleness as `source != selectedComposition`, so a
/// scrub, a tick or any edit makes it stale with no stored flag.
public struct HaloShownFrame: Sendable, Equatable {
    public var frame: HaloRenderedFrame
    public var source: HaloComposition
    public init(frame: HaloRenderedFrame, source: HaloComposition) { self.frame = frame; self.source = source }
}

/// The transport: whether it plays, whether it loops, and where and when
/// play began, so each tick asks `PlaybackClock` for the frame.
public struct HaloPlaybackState: Sendable, Equatable {
    public var playing: Bool
    public var loops: Bool
    public var startFrame: Int
    /// Seconds on the app's clock when play began.
    public var startTime: Double
    /// The frame the last tick showed.
    public var lastFrame: Int
    public init(playing: Bool = false, loops: Bool = true, startFrame: Int = 0, startTime: Double = 0, lastFrame: Int = 0) {
        self.playing = playing; self.loops = loops; self.startFrame = startFrame
        self.startTime = startTime; self.lastFrame = lastFrame
    }
}

/// A layer being dragged in the viewer: where the drag began and how far it
/// has moved, in composition pixels. Nothing is recorded until mouse-up.
public struct HaloViewerDragState: Sendable, Equatable {
    public var layerID: String
    public var start: HaloPoint
    public var delta: HaloPoint
    public init(layerID: String, start: HaloPoint, delta: HaloPoint = HaloPoint(x: 0, y: 0)) {
        self.layerID = layerID; self.start = start; self.delta = delta
    }
}

/// A project in File > Open Recent: its name and where it is.
public struct HaloRecentFile: Sendable, Hashable, Codable {
    public var name: String
    public var path: String
    public init(name: String, path: String) { self.name = name; self.path = path }
}

/// The project file: its name and path once saved or opened, whether it has
/// unsaved edits, an open in progress, the last error, and the recent list.
public struct HaloFileState: Sendable, Equatable {
    /// Nil until the project is saved or opened ("Untitled Project").
    public var name: String?
    public var path: String?
    public var unsaved: Bool
    public var opening: Bool
    /// The last open or save error's message; nil once handled.
    public var error: String?
    /// Newest first.
    public var recent: [HaloRecentFile]
    public init(
        name: String? = nil, path: String? = nil, unsaved: Bool = false, opening: Bool = false, error: String? = nil,
        recent: [HaloRecentFile] = []
    ) {
        self.name = name; self.path = path; self.unsaved = unsaved; self.opening = opening
        self.error = error; self.recent = recent
    }
}

/// A render to files: what was asked, the plan, the frames written so far
/// and, once done, how it ended.
public struct HaloRenderJobState: Sendable, Equatable {
    public var settings: HaloRenderSettings
    public var plan: HaloRenderPlan?
    /// Frames written so far.
    public var progress: Int
    public var outcome: HaloRenderOutcome?
    public init(
        settings: HaloRenderSettings, plan: HaloRenderPlan? = nil, progress: Int = 0, outcome: HaloRenderOutcome? = nil
    ) {
        self.settings = settings; self.plan = plan; self.progress = progress; self.outcome = outcome
    }
}
