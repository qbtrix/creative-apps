// FlareDocumentSetup+Kernel.swift (document-setup DS-14): Flare's one adapter between SuiteKernel's `DocumentSetup`
// and its scene. `documentSetup` reads the selected scene as pixels at 72 ppi, its background, its exact rate and its
// length in seconds; `applyDocumentSetup` writes a setup back through `SceneContracts.setCanvas` and `SetSceneTiming`
// as one "Document Settings" undo step: the background goes with the size, and the length is the setup's seconds in
// whole frames at the setup's rate (15 s at 30 fps is 450), so keys and labels stay on their frames. Flare's canvas has
// no anchor of its own: content keeps its stage coordinates whatever the anchor says. `document.read-settings` and
// `document.set-settings` forward to `DocumentSetupCommands` through `SetupTarget`. Linux-safe.
import FlareCore
import SuiteKernel

extension DocumentSetup {
    /// A Flare preset's setup: its size in pixels on white, its whole rate and its length in seconds.
    public init(_ preset: CanvasPreset) {
        let rate = FrameRate(whole: preset.fps)
        self.init(width: preset.width, height: preset.height, frameRate: rate,
                  durationSeconds: rate.seconds(ofFrame: preset.durationFrames))
    }
}

extension DocumentBackground {
    /// A scene's background: white, transparent at alpha 0, else its "#RRGGBB".
    public init(_ color: FlareColor) {
        let hex = NewDocumentSpec.hex(color)
        self = color.a <= 0 ? .transparent : hex == "#FFFFFF" ? .white : .color(hex: hex)
    }

    /// The scene color this background names; nil for a hex that names none.
    public var flareColor: FlareColor? {
        switch self {
        case .white: .white
        case .transparent: FlareColor(r: 1, g: 1, b: 1, a: 0)
        case .color(let hex): NewDocumentSpec.color(hex: String(hex.prefix(7)))
        }
    }
}

extension NewDocumentSpec {
    /// The spec the shared New sheet's setup makes: its pixel size, rate (24 when untimed), length in whole frames
    /// and background, under the preset of that size and rate if one matches.
    public init(_ setup: DocumentSetup) {
        let pixels = setup.pixelSize, rate = setup.frameRate ?? FrameRate(whole: 24)
        self.init(preset: .hd1080)
        (width, height, fps) = (Double(pixels.width), Double(pixels.height), rate)
        durationFrames = rate.frames(forDuration: setup.durationSeconds ?? rate.seconds(ofFrame: durationFrames))
        background = setup.background.flareColor ?? FlareColor(r: .nan, g: 0, b: 0)
        preset = CanvasPreset.all.first { $0.width == width && $0.height == height && FrameRate(whole: $0.fps) == rate }
    }
}

extension FlareWorkspace {
    /// The longest length the sheet offers, in seconds: 100 000 frames at 240 fps rounded down.
    public static let maxSeconds: Double = 400

    /// What a new animation allows: the format's longest side, the kernel's common rates and `maxSeconds`.
    public static let newDocumentLimits = DocumentLimits(maxSide: Int(NewDocumentSpec.maxSide), rates: FrameRate.common,
                                                         maxSeconds: maxSeconds)

    /// The selected scene's setup; a new animation's when nothing is open.
    public var documentSetup: DocumentSetup {
        guard let scene = selectedScene else { return DocumentSetup(.hd1080) }
        return DocumentSetup(width: scene.width, height: scene.height, background: DocumentBackground(scene.background),
                             frameRate: scene.frameRate, durationSeconds: scene.frameRate.seconds(ofFrame: scene.durationFrames))
    }

    /// The new limits, widened to hold the open scene's own rate and length.
    public var documentLimits: DocumentLimits {
        let setup = documentSetup, rate = setup.frameRate ?? FrameRate(whole: 24)
        let rates = FrameRate.common.contains(rate) ? FrameRate.common : FrameRate.common + [rate]
        return DocumentLimits(maxSide: Int(NewDocumentSpec.maxSide), rates: rates,
                              maxSeconds: max(Self.maxSeconds, setup.durationSeconds ?? 0))
    }

    /// Writes `setup` to the selected scene as one "Document Settings" step: size and background through
    /// `setCanvas`, rate and length through `SetSceneTiming`. A problem, a length out of range or one that cuts off a
    /// label changes nothing but `layerError`. `anchor` is accepted and unused: Flare content keeps its coordinates.
    public mutating func applyDocumentSetup(_ setup: DocumentSetup, anchor _: BoxAnchor = .center) {
        guard let scene = selectedScene else { return refuse(.noDocument) }
        if let problem = setup.problems(documentLimits).first { return refuse(.refused(problem.text)) }
        guard let background = setup.background.flareColor else { return refuse(.refused("Pick a valid background color.")) }
        let rate = setup.frameRate ?? scene.frameRate, exact = rate.sceneRate
        let frames = setup.durationSeconds.map { rate.frames(forDuration: $0) } ?? scene.durationFrames
        let range = NewDocumentSpec.durationRange
        guard range.contains(frames) else {
            return refuse(.refused("Duration must be \(range.lowerBound) to \(range.upperBound) frames."))
        }
        if let last = scene.labels.values.max(), last > frames {
            return refuse(.refused("Length must reach frame \(last), where a label sits."))
        }
        let pixels = setup.pixelSize, scenes = services.scenes
        applyGroup("Document Settings") {
            try scenes.setCanvas(scene.id, width: Double(pixels.width), height: Double(pixels.height),
                                 background: background, in: &$0)
            try $0.perform(SetSceneTiming(sceneID: scene.id, fps: exact.nominal, durationFrames: frames, rate: exact))
        }
    }

    /// The workspace as `DocumentSetupCommands` sees it, written back once a set succeeds.
    final class SetupTarget: DocumentSetupTarget {
        var workspace: FlareWorkspace
        init(_ workspace: FlareWorkspace) { self.workspace = workspace }
        var documentSetup: DocumentSetup { workspace.documentSetup }
        var documentLimits: DocumentLimits { workspace.documentLimits }
        func apply(_ setup: DocumentSetup, anchor: BoxAnchor) throws {
            workspace.applyDocumentSetup(setup, anchor: anchor)
            if let error = workspace.layerError {
                throw CatalogError.failed(id: "document.set-settings", message: error.message)
            }
        }
    }

    /// `document.read-settings` and `document.set-settings`, the kernel's specs on the selected scene.
    static let documentSetupCommands: [CommandSpec<FlareWorkspace>] = DocumentSetupCommands.specs.map { spec in
        .typed(spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
               result: spec.result, example: spec.example,
               availability: { noScene($0).map(Availability.unavailable) ?? .available }) { w, p in
            let target = SetupTarget(w)
            let reading = try DocumentSetupCommands.run(spec.id, p, on: target)
            w = target.workspace
            return reading
        }
    }
}
