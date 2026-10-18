// LiveKeyframes+Edit.swift: the live key moves and removes (docs/blueprints/flare/features/live-keys.md, task KY-6).
// A summary key (no property) stands for every track keyed at its frame. A move is FlareCore's `MoveKeyframe(owner:)`
// per key, leading-edge keys first, tried on a copy of the engine so one that lands a key on another throws and changes
// nothing. No key moves before frame 0, or past the last frame of its scene or symbol, where it would never play (a
// symbol edited in place has its own length, flare.md LM-0c1). Several keys move as one "Move Keyframe" step, or merge
// into the drag's entry under `coalesceKey`: a coalesced drag of several keys is one undo entry but holds one command
// per key per step, since FlareCore merges only into the entry's last command. A remove is `RemoveKeyframe(owner:)` per
// key, grouped as one "Delete Keyframe". Agrees with `FakeKeyframes` on scenes, except that a scene key moved past the
// last frame throws a key sentence where the fake throws `invalidFrame`; the `KeyframeEditing` conformance is
// in LiveKeyframes+Frames.swift.
import FlareCore

extension LiveKeyframes {
    public func moveKeys(_ keys: Set<KeyRef>, by delta: Int, owner: LayerOwner,
                         coalesceKey: String?, in engine: inout CommandEngine) throws {
        let length = try Self.length(of: owner, in: engine.document)
        // A key past the owner's last frame would never play (#636).
        let pastEnd: CommandError = if case .symbol = owner { .invalidDocument(Self.pastSymbolEnd) } else { .invalidDocument(Self.pastSceneEnd) }
        try KernelKeys.move(keys, by: delta, owner: owner, coalesceKey: coalesceKey, from: 0, before: { _ in length },
                            pastRange: { _ in delta < 0 ? CommandError.invalidDocument(Self.beforeFrameZero) : pastEnd }, in: &engine)
    }

    public func removeKeys(_ keys: Set<KeyRef>, owner: LayerOwner, in engine: inout CommandEngine) throws {
        try KernelKeys.remove(keys, owner: owner, in: &engine)
    }

    static let beforeFrameZero = "A key can't move before frame 0."
    static let pastSceneEnd = "A key can't move past the scene's last frame."
    static let pastSymbolEnd = "A key can't move past the symbol's last frame."
    static let insertPastSymbolEnd = "A symbol can't get longer yet, so frames can't be inserted before its last key."

    /// The owner's length in frames, its scene's or its symbol's; a missing owner throws.
    static func length(of owner: LayerOwner, in document: Document) throws -> Int {
        switch owner {
        case .scene(let id):
            guard let scene = document.scenes.first(where: { $0.id == id }) else { throw CommandError.sceneNotFound(id) }
            return scene.durationFrames
        case .symbol(let id):
            guard let symbol = document.symbols.first(where: { $0.id == id }) else { throw CommandError.symbolNotFound(id) }
            return symbol.durationFrames
        }
    }
}
