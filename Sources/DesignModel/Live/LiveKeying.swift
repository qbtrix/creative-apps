// Live/LiveKeying.swift: the one write-back rule for edits at a playhead (one-document OD-5, rule 1 of 4). A keyed
// property edited at a playhead gets a key there holding the asked-for value (replacing one already there), so the
// canvas shows what was asked and other frames keep their keys; no track or no playhead edits the rest pose (the
// first key is a deliberate act); a rest-pose move carries the subtree's x and y keys with it. Values are the node's own, what its keys hold; `moved(by:at:)` adds a shown delta
// to them. A keyed layer that changes parent at a playhead (Group, Ungroup, Move Layer) has its x and y keys rebased by
// its old containers' shown offset minus its new ones', so it shows where it did there (`rebased(from:at:)`); a layer
// with no keys on an axis is not rebased on it and jumps by that offset (keying it would be a hidden first key).
// The only file in DesignModel that knows the rule. Linux-safe.
import SuiteKernel

extension DesignNode {
    /// This node with `property` set to `value`: a key at `playhead` when the property has a track and a
    /// playhead is set, else the rest pose (x and y move the subtree and its keys).
    public func writing(_ property: DesignKeyProperty, _ value: Double, at playhead: Int?) -> DesignNode {
        var node = self
        if let playhead, keys(property, at: playhead), var time, var track = time.tracks[property] {
            if let index = track.firstIndex(where: { $0.frame == playhead }) {
                track[index].value = value
            } else {
                _ = KeyRules.toggleKey(&track, at: playhead, value: value, leaving: .propertyGoesStatic)
            }
            time.tracks[property] = track
            node.time = time
            return node
        }
        switch property {
        case .x: node.translate(by: DesignPoint(x: value - frame.x, y: 0), carryingKeys: true)
        case .y: node.translate(by: DesignPoint(x: 0, y: value - frame.y), carryingKeys: true)
        case .opacity: node.opacity = value
        }
        return node
    }

    /// This node moved by `delta` as it shows at `playhead`: each axis through `writing`, from its own value there.
    /// An axis with no track moves the rest pose by the raw delta, the subtree's keys with it.
    public func moved(by delta: DesignPoint, at playhead: Int?) -> DesignNode {
        let (keyedX, keyedY) = (keys(.x, at: playhead), keys(.y, at: playhead))
        var node = self
        node.translate(by: DesignPoint(x: keyedX ? 0 : delta.x, y: keyedY ? 0 : delta.y), carryingKeys: true)
        if keyedX, delta.x != 0 { node = node.writing(.x, ownValue(.x, at: playhead) + delta.x, at: playhead) }
        if keyedY, delta.y != 0 { node = node.writing(.y, ownValue(.y, at: playhead) + delta.y, at: playhead) }
        return node
    }

    /// Whether an edit of `property` at `playhead` keys: a playhead is set and the property has a track.
    func keys(_ property: DesignKeyProperty, at playhead: Int?) -> Bool {
        playhead != nil && time?.tracks[property]?.isEmpty == false
    }

    /// `property`'s own value at `playhead`: its keys' value there, else the rest pose.
    func ownValue(_ property: DesignKeyProperty, at playhead: Int?) -> Double {
        let rest = switch property {
        case .x: frame.x
        case .y: frame.y
        case .opacity: opacity
        }
        guard let playhead else { return rest }
        return time?.value(of: property, at: Double(playhead)) ?? rest
    }
}

extension DesignPage {
    /// The page as it shows at `playhead`, or itself with none.
    func shown(at playhead: Int?) -> DesignPage { playhead.map { sampled(at: Double($0)) } ?? self }
}

extension [DesignNode] {
    /// These nodes after a reparent of `old` at `playhead`: each keyed layer whose parent changed has its x and y keys
    /// shifted by its old containers' shown offset at the playhead minus its new ones', so it shows where it did.
    /// No playhead rebases nothing.
    func rebased(from old: [DesignNode], at playhead: Int?) -> [DesignNode] {
        guard let playhead else { return self }
        let frame = Double(playhead)
        var before: [String: (parent: String?, offset: DesignPoint)] = [:]
        func record(_ nodes: [DesignNode], _ parent: String?, _ offset: DesignPoint) {
            for node in nodes {
                before[node.id] = (parent, offset)
                record(node.children, node.id, offset + node.ownOffset(at: frame))
            }
        }
        record(old, nil, DesignPoint(x: 0, y: 0))
        func rebase(_ nodes: [DesignNode], _ parent: String?, _ offset: DesignPoint) -> [DesignNode] {
            nodes.map { node in
                var node = node
                if let was = before[node.id], was.parent != parent, let time = node.time {
                    node.time = time.translated(by: was.offset - offset)
                }
                node.children = rebase(node.children, node.id, offset + node.ownOffset(at: frame))
                return node
            }
        }
        return rebase(self, nil, DesignPoint(x: 0, y: 0))
    }
}

extension DesignNode {
    /// How far this node's own keys move it from its rest pose at `frame` (zero when still).
    func ownOffset(at frame: Double) -> DesignPoint {
        DesignPoint(x: (time?.value(of: .x, at: frame) ?? self.frame.x) - self.frame.x,
                    y: (time?.value(of: .y, at: frame) ?? self.frame.y) - self.frame.y)
    }
}

private func + (a: DesignPoint, b: DesignPoint) -> DesignPoint { DesignPoint(x: a.x + b.x, y: a.y + b.y) }
private func - (a: DesignPoint, b: DesignPoint) -> DesignPoint { DesignPoint(x: a.x - b.x, y: a.y - b.y) }
