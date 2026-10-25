// HaloDocumentSetup+Kernel.swift (document-setup DS-12): Halo's adapter onto SuiteKernel's DocumentSetup, for
// the shared sheet, document.read-settings / set-settings and composition.new. Linux-safe: no UI imports.
import SuiteKernel

extension HaloComposition {
    /// The composition as a setup: px at 72 ppi, its rate, seconds and background.
    public var documentSetup: DocumentSetup {
        DocumentSetup(width: Double(width), height: Double(height), background: background, frameRate: frameRate,
                      durationSeconds: durationSeconds)
    }

    /// The composition at `s`, `frames` long, root layers moved by `shift`. Keys, spans and the playhead keep
    /// their times (a rate change keeps seconds); a layer that ran to the old end runs to the new one.
    func applying(_ s: CompositionSettings, frames: Int, shift: Point) -> HaloComposition {
        let old = frameRate, rate = s.frameRate, end = durationFrames
        let retime: (Int) -> Int = { rate == old ? $0 : rate.frame(atSeconds: old.seconds(ofFrame: $0)) }
        var next = HaloComposition(id: id, name: name, width: s.width, height: s.height, frameRate: rate, durationFrames: frames)
        next.background = s.background
        next.playheadFrame = min(max(0, retime(playheadFrame)), frames - 1)
        next.layers = layers.map { layer in
            var l = layer
            l.inFrame = min(max(0, retime(layer.inFrame)), frames - 1)
            l.outFrame = max(l.inFrame + 1, layer.outFrame >= end ? frames : min(retime(layer.outFrame), frames))
            l.tracks = layer.tracks.mapValues { keys in
                keys.reduce(into: []) { out, key in
                    var k = key
                    k.frame = retime(key.frame)
                    if out.last?.frame == k.frame { out.removeLast() }
                    out.append(k)
                }
            }
            guard layer.parentID == nil else { return l }
            l.rect = layer.rect.map { HaloLayerRect(x: $0.x + shift.x, y: $0.y + shift.y, width: $0.width, height: $0.height) }
            let before = layer.bounds(in: self), after = l.bounds(in: next)
            let moved = (x: after.x - before.x, y: after.y - before.y)
            for (key, by) in [("x", shift.x), ("y", shift.y), ("anchorX", moved.x), ("anchorY", moved.y)] where by != 0 {
                l.tracks[key] = l.tracks[key]?.map { var k = $0; k.value += by; return k }
            }
            return l
        }
        return next
    }
}

extension HaloProject {
    public var documentSetup: DocumentSetup? { selectedComposition?.documentSetup }

    /// Applies `setup` to the selected composition, old content kept at `anchor`, as one "Document Settings"
    /// step; false with no composition or a setup with a problem (CompositionSettings checks it against `limits`).
    @discardableResult
    public mutating func applySetup(_ setup: DocumentSetup, anchor: BoxAnchor = .center) -> Bool {
        guard let id = selectedCompositionID, let old = selectedComposition else { return false }
        let settings = CompositionSettings(name: old.name, setup: setup)
        guard let frames = settings.durationFrames else { return false }
        let shift = DocumentSetupCommands.offset(from: old.documentSetup, to: setup, anchor: anchor)
        return edit("Document Settings", control: "halo.composition.settings") { doc in
            guard let index = doc.compositions.firstIndex(where: { $0.id == id }) else { return }
            doc.compositions[index] = old.applying(settings, frames: frames, shift: shift)
        }
    }

    /// The kernel's document.read-settings and document.set-settings over the selected composition.
    static let documentSetupSpecs: [CommandSpec<HaloProject>] = DocumentSetupCommands.specs.map { kernel in
        .typed(kernel.id, title: kernel.title, summary: kernel.summary, kind: kernel.kind, params: JSONValue.self,
                      schema: kernel.params, result: kernel.result, example: kernel.example,
                      availability: { $0.unavailableHelp(for: .duplicateComposition).map(Availability.unavailable) ?? .available }
        ) { p, json in try p.runDocumentSetup(kernel.id, json) }
    }

    mutating func runDocumentSetup(_ id: String, _ params: JSONValue) throws -> JSONValue {
        if let why = unavailableHelp(for: .duplicateComposition) { throw CatalogError.unavailable(id: id, why: why) }
        guard let target = HaloSetupTarget(self) else { throw CatalogError.unavailable(id: id, why: "There is no composition.") }
        let answer = try DocumentSetupCommands.run(id, params, on: target)
        self = target.project
        return answer
    }

    /// composition.new's params: the kernel's setup fields, and the old `seconds` and `fps`, over the suggested settings.
    struct SetupNewOptions: Decodable, Sendable {
        var name: String?; var width, height, resolution, duration, seconds: Double?; var unit: LengthUnit?
        var background: DocumentBackground?; var frameRate: FrameRate?; var fps: Int?
        func settings(over base: CompositionSettings) -> CompositionSettings {
            let was = base.setup
            let setup = DocumentSetup(width: width ?? was.width, height: height ?? was.height, unit: unit ?? was.unit,
                                      resolution: resolution ?? was.resolution, background: background ?? was.background,
                                      frameRate: frameRate ?? fps.map(FrameRate.init(whole:)) ?? was.frameRate,
                                      durationSeconds: duration ?? seconds ?? was.durationSeconds)
            return CompositionSettings(name: name ?? base.name, setup: setup)
        }
    }

    /// The kernel's setup schema, every field optional, plus `name` and the old `seconds` and `fps`.
    static let newSetupSchema: ParamSchema = {
        var schema = DocumentSetupCommands.setupSchema
        guard case .object(var top) = schema.json, case .object(var properties)? = top["properties"] else { return schema }
        properties["name"] = ParamSchema.string("The composition's name; a taken one gets a number.").json
        properties["seconds"] = ParamSchema.number("Length in seconds; duration's older name.", minimum: 0).json
        properties["fps"] = ParamSchema.integer("A whole frame rate; frameRate's older form.", minimum: 1).json
        (top["properties"], top["required"]) = (.object(properties), .array([]))
        schema.json = .object(top)
        return schema
    }()
}

/// The selected composition as the kernel's DocumentSetupTarget: a copy of the project the set writes into.
final class HaloSetupTarget: DocumentSetupTarget {
    private(set) var project: HaloProject
    let documentSetup: DocumentSetup
    var documentLimits: DocumentLimits { CompositionSettings.limits }
    init?(_ project: HaloProject) {
        guard let setup = project.documentSetup else { return nil }
        (self.project, documentSetup) = (project, setup)
    }
    func apply(_ setup: DocumentSetup, anchor: BoxAnchor) throws {
        guard project.applySetup(setup, anchor: anchor) else {
            throw CatalogError.failed(id: "document.set-settings", message: "The composition couldn't take those settings.")
        }
    }
}
