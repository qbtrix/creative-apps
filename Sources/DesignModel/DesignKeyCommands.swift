// DesignKeyCommands.swift (one-document OD-8): Design's keys as commands, so the afterglow CLI, MCP and the window's
// key buttons run one path. keyframe.set, .remove, .move and .set-easing edit one key on a layer's x, y or opacity
// track as one undo step named the command's title; they never touch the rest pose or the document's rate and length.
// Set is the deliberate act that starts a track, so it writes the key directly rather than through the playhead
// write-back rule (Live/LiveKeying.swift), which edits the rest pose of an unkeyed property. time.sample reads a layer
// as the canvas shows it at a frame, its containers' keyed offsets included. time.playhead moves the shown frame:
// shown state, no undo step, no change to the file. Easing names are the kernel's EasePreset list. Ids follow the
// ledger's lowercase-dash style (Tests/command-ids/design.txt), as Flare's and Halo's do. The inspector's key button
// and the Animate menu add no id: they run keyframe.set and keyframe.remove. The button's state is KeyRules.state at
// the playhead; its stopwatch (`keyAnimate`) is KeyRules.toggleAnimated's pair of keys, its diamond (`keyToggle`) sets
// or removes the key there. The menu's Set Key and Remove Key (`menuKeys`) act on every row of the one selected layer.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension DesignWorkspace {
    /// Moves the shown frame, clamped to the document's frames; nil shows the rest pose. Assignment only: a playback
    /// tick calls it every frame, so it ends no drag or text edit and records nothing.
    public mutating func setPlayhead(_ frame: Int?) {
        playhead = frame.map { Swift.min(Swift.max($0, 0), Swift.max(time.durationFrames - 1, 0)) }
    }

    /// Sets a key of `value` on node `id`'s `property` at `frame`, keeping the easing of a key already there.
    public mutating func setKey(_ id: String, _ property: DesignKeyProperty, at frame: Int, to value: Double) throws {
        guard value.isFinite, frame >= 0 else { throw DesignRefusal.unchanged }
        let value = property == .opacity ? Swift.min(Swift.max(value, 0), 1) : value
        try editTrack(id, property, named: "Set Key") { track in
            let easing = track.first { $0.frame == frame }?.easing ?? .linear
            track.removeAll { $0.frame == frame }
            track.append(Keyframe(frame: frame, value: value, easing: easing))
        }
    }

    /// Removes the key at `frame`; the track's other keys stay.
    public mutating func removeKey(_ id: String, _ property: DesignKeyProperty, at frame: Int) throws {
        try editTrack(id, property, named: "Remove Key") { track in
            guard track.contains(where: { $0.frame == frame }) else { throw DesignRefusal.unchanged }
            KeyRules.removeKeys(&track, [frame], leaving: .singleStays)
        }
    }

    /// Moves the key at `from` to `to`; refused when another key is there.
    public mutating func moveKey(_ id: String, _ property: DesignKeyProperty, from: Int, to: Int) throws {
        try editTrack(id, property, named: "Move Key") { track in
            guard track.contains(where: { $0.frame == from }) else { throw DesignRefusal.unchanged }
            var tracks = [property.rawValue: track]
            try KeyRules.moveKeys(&tracks, [from], by: to - from, clampedTo: 0...Int.max)
            track = tracks[property.rawValue] ?? track
        }
    }

    /// Sets the easing from the key at `frame` to the next one.
    public mutating func setKeyEasing(_ id: String, _ property: DesignKeyProperty, at frame: Int, _ easing: Easing) throws {
        try editTrack(id, property, named: "Set Easing") { track in
            guard let index = track.firstIndex(where: { $0.frame == frame }) else { throw DesignRefusal.unchanged }
            track[index].easing = easing
        }
    }

    /// Node `id` as it shows at `frame`: its page sampled there, so its containers' offsets count.
    public func sampledNode(_ id: String, at frame: Int) -> DesignNode? {
        pages.first { $0.nodes.node(id) != nil }?.sampled(at: Double(frame)).nodes.node(id)
    }

    /// Changes node `id`'s `property` track as the one step `name`; a change that leaves it as it was refuses.
    private mutating func editTrack(
        _ id: String, _ property: DesignKeyProperty, named name: String, _ change: (inout [Keyframe]) throws -> Void
    ) throws {
        guard let node = findNode(id) else { throw DesignRefusal.unknownID(id) }
        var tracks = node.time?.tracks ?? [:]
        let old = tracks[property] ?? []
        var track = old
        try change(&track)
        guard track != old else { throw DesignRefusal.unchanged }
        tracks[property] = track
        let time = DesignNodeTime(tracks: tracks)
        try editNode(id, named: name) { $0.time = time }
    }

    /// The key commands' params: the layer, the property, the key's frame, and what each command adds.
    struct KeyParams: Codable, Sendable { var node, property: String; var frame: Int; var value: Double?; var to: Int?; var easing: String? }
    struct SampleAtParams: Codable, Sendable { var node: String; var frame: Int }
    struct PlayheadParams: Codable, Sendable { var frame: Int? }
    struct Sampled: Encodable, Sendable { var x, y, opacity: Double }

    /// A key edit's reason: off with no file or mid text edit (as Rename Page); the edits of a key need one to exist.
    static func keyHelp(_ w: DesignWorkspace) -> Availability { reason(renamePageHelp(w)) }
    static func keyedHelp(_ w: DesignWorkspace) -> Availability {
        reason(renamePageHelp(w) ?? (w.isStill ? "Set a key first." : nil))
    }

    /// One key command: the layer, property and frame params plus `extra`, run as `run`.
    static func key(
        _ id: String, _ title: String, _ summary: String, _ extra: [String: ParamSchema], example: [String: JSONValue],
        _ availability: @escaping @Sendable (DesignWorkspace) -> Availability,
        _ run: @escaping @Sendable (inout DesignWorkspace, KeyParams, DesignKeyProperty) throws -> Void
    ) -> CommandSpec<DesignWorkspace> {
        let base: [String: ParamSchema] = [
            "node": .string("The layer's id."),
            "property": .string("The keyed property.", oneOf: DesignKeyProperty.allCases.map(\.rawValue)),
            "frame": .integer("The key's frame.", minimum: 0)]
        let all = base.merging(extra) { a, _ in a }
        let sample: [String: JSONValue] = ["node": .string("node-2"), "property": .string("x"), "frame": .number(0)]
        return .typed(id, title: title, summary: summary, kind: .edit, params: KeyParams.self,
                      schema: .object(all, required: all.keys.sorted()), example: .object(sample.merging(example) { _, b in b }),
                      availability: availability
        ) { w, p in
            guard let property = DesignKeyProperty(rawValue: p.property) else { throw DesignRefusal.unknownID(p.property) }
            try run(&w, p, property)
            return JSONValue.object([:])
        }
    }

    static let keySpecs: [CommandSpec<DesignWorkspace>] = [
        key("keyframe.set", "Set Key", "Sets a key on a layer's x, y or opacity at a frame, replacing one there; the rest pose stays.",
            ["value": .number("Page points for x and y, 0 to 1 for opacity.")], example: ["frame": .number(60), "value": .number(47)],
            keyHelp) { w, p, property in try w.setKey(p.node, property, at: p.frame, to: p.value ?? .nan) },
        key("keyframe.remove", "Remove Key", "Removes the key at a frame; the track's other keys stay.", [:], example: [:],
            keyedHelp) { w, p, property in try w.removeKey(p.node, property, at: p.frame) },
        key("keyframe.move", "Move Key", "Moves the key at a frame to another frame that holds no key.",
            ["to": .integer("The frame it moves to.", minimum: 0)], example: ["to": .number(30)],
            keyedHelp) { w, p, property in try w.moveKey(p.node, property, from: p.frame, to: p.to ?? p.frame) },
        key("keyframe.set-easing", "Set Easing", "Sets how the value eases from the key at a frame to the next key.",
            ["easing": .string("The easing preset.", oneOf: EasePreset.allCases.map(\.rawValue))],
            example: ["easing": .string("easeInOut")], keyedHelp) { w, p, property in
                guard let preset = EasePreset(rawValue: p.easing ?? "") else { throw DesignRefusal.unchanged }
                try w.setKeyEasing(p.node, property, at: p.frame, preset.easing)
            },
        .typed("time.sample", title: "Sample", summary: "Reads a layer's x, y and opacity as the canvas shows them at a frame.",
               kind: .query, params: SampleAtParams.self,
               schema: .object(["node": .string("The layer's id."), "frame": .integer("The frame to read.", minimum: 0)],
                               required: ["frame", "node"]),
               result: .object(["x": .number("Left, in page points."), "y": .number("Top, in page points."),
                                "opacity": .number("0 to 1.")], required: ["opacity", "x", "y"]),
               example: .object(["node": .string("node-2"), "frame": .number(30)]), availability: openHelp
        ) { w, p in
            guard let node = w.sampledNode(p.node, at: p.frame) else { throw DesignRefusal.unknownID(p.node) }
            return Sampled(x: node.frame.x, y: node.frame.y, opacity: node.opacity)
        },
        .typed("time.playhead", title: "Playhead", summary: "Shows the document at a frame, or its rest pose with no frame; changes nothing in the file.",
               kind: .view, params: PlayheadParams.self,
               schema: .object(["frame": .optional(.integer("The frame to show; past the end shows the last, left out the rest pose.", minimum: 0))],
                               required: ["frame"]),
               example: .object(["frame": .number(60)]), availability: openHelp
        ) { w, p in w.setPlayhead(p.frame); return JSONValue.object([:]) },
    ]
}

extension DesignWorkspace {
    /// The key button's presence on layer `id`'s `property` row at the playhead (frame 0 with none); nil with no layer.
    public func keyState(_ id: String, _ property: DesignKeyProperty) -> KeyState? {
        findNode(id).map { KeyRules.state($0.time?.tracks[property] ?? [], at: playhead ?? 0) }
    }

    /// The command a press of that button runs: keyframe.remove when a key sits at the frame, else keyframe.set with
    /// the layer's own value there (its rest value while unkeyed), so the first press starts the track.
    public func keyToggle(_ id: String, _ property: DesignKeyProperty) -> (id: String, params: JSONValue)? {
        guard let node = findNode(id), let state = keyState(id, property) else { return nil }
        let frame = playhead ?? 0
        var params: [String: JSONValue] = ["node": .string(id), "property": .string(property.rawValue), "frame": .number(Double(frame))]
        if state == .keyedHere { return ("keyframe.remove", .object(params)) }
        let rest = switch property { case .x: node.frame.x; case .y: node.frame.y; case .opacity: node.opacity }
        params["value"] = .number(node.time?.value(of: property, at: Double(frame)) ?? rest)
        return ("keyframe.set", .object(params))
    }

    /// The commands the row's stopwatch runs. On a row that isn't animated: keyframe.set at the playhead and at the
    /// last frame, both holding the value shown there (KeyRules.toggleAnimated's pair; one key when they are the same
    /// frame). On an animated row: keyframe.remove on every key but the first, which stays as the row's held value.
    // ponytail: one undo step per key; a one-step keyframe.animate id is the upgrade.
    public func keyAnimate(_ id: String, _ property: DesignKeyProperty) -> [(id: String, params: JSONValue)]? {
        guard let node = findNode(id), let first = keyToggle(id, property) else { return nil }
        let track = node.time?.tracks[property] ?? []
        func params(_ frame: Int, _ value: Double? = nil) -> JSONValue {
            var p: [String: JSONValue] = ["node": .string(id), "property": .string(property.rawValue), "frame": .number(Double(frame))]
            if let value { p["value"] = .number(value) }
            return .object(p)
        }
        guard keyState(id, property) == .notAnimated else {
            return track.dropFirst().map { ("keyframe.remove", params($0.frame)) }
        }
        let last = Swift.max(time.durationFrames - 1, 0)
        guard case .object(let p) = first.params, case .number(let at)? = p["frame"], case .number(let value)? = p["value"]
        else { return [first] }
        return Int(at) == last ? [first] : [first, ("keyframe.set", params(last, value))]
    }

    /// The Animate menu's Set Key (`removing` false) or Remove Key on the one selected layer: keyframe.set on each
    /// row with no key at the playhead, or keyframe.remove on each row keyed there. Empty when there is nothing to do.
    public func menuKeys(removing: Bool) -> [(id: String, params: JSONValue)] {
        guard !hasMultipleSelection, let node = selectedNode else { return [] }
        let at = playhead ?? 0
        return DesignKeyProperty.allCases.compactMap { property in
            guard let command = keyToggle(node.id, property) else { return nil }
            if removing { return command.id == "keyframe.remove" ? command : nil }
            let keyed = node.time?.tracks[property]?.contains { $0.frame == at } ?? false
            return keyed ? nil : command
        }
    }
}
