// Live/LiveKeying.swift: the one write-back rule for edits at a playhead (one-document OD-5, rule 1 of 4). A keyed
// property edited at a playhead gets a key there holding the asked-for value (replacing one already there), so the
// canvas shows what was asked and other frames keep their keys; no track or no playhead edits the rest pose (the
// first key is a deliberate act); a rest-pose move carries the subtree's x and y keys with it. Values are the node's own, what its keys hold; `moved(by:at:)` adds a shown delta
// to them. The only file in DesignModel that knows the rule. Linux-safe.
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
