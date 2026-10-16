// Rules.swift: rules the fakes and the live types share, kept once so the
// duplicate-code gate never sees two copies (blueprint part 6.3). W0 copies
// this file into Sources/PrismModel/Live/PrismRules.swift; the live types call
// it and the fakes call it too. Invariants: pure functions of values; a
// missing node, mesh or material yields nil or a default, never a trap.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

public enum PrismRules {
    /// What follows the first `needle` in `hay`, or nil (FoundationEssentials has no range(of:)).
    public static func after(_ needle: String, in hay: Substring) -> Substring? {
        let n = Array(needle)
        guard !n.isEmpty else { return hay }
        var i = hay.startIndex
        while i < hay.endIndex {
            if hay[i...].starts(with: n) { return hay[hay.index(i, offsetBy: n.count)...] }
            i = hay.index(after: i)
        }
        return nil
    }

    /// Text without leading and trailing white space (FoundationEssentials has no trimming).
    public static func trimmed(_ s: String) -> String {
        String(String(s.drop(while: \.isWhitespace).reversed()).drop(while: \.isWhitespace).reversed())
    }

    /// The value of a track at a frame: the base value with no keys; the first or last key's value
    /// outside the keys; else eased between the keys around `frame` with the earlier key's easing.
    public static func sample(_ track: [PrismKey]?, base: Double, at frame: Int) -> Double {
        guard let keys = track, let first = keys.first, let last = keys.last else { return base }
        if frame <= first.frame { return first.value }
        if frame >= last.frame { return last.value }
        for (a, b) in zip(keys, keys.dropFirst()) where frame >= a.frame && frame < b.frame {
            let span = Double(b.frame - a.frame)
            guard span > 0 else { return a.value }
            let t = a.easing.value(at: Double(frame - a.frame) / span)
            return a.value + (b.value - a.value) * t
        }
        return last.value
    }

    /// The base (not animated) value of a property on a node.
    public static func base(_ property: PrismProperty, of node: PrismNode) -> Double? {
        guard property.applies(to: node.kind) else { return nil }
        let t = node.transform
        switch property {
        case .positionX: return t.position.x
        case .positionY: return t.position.y
        case .positionZ: return t.position.z
        case .rotationX: return t.rotation.x
        case .rotationY: return t.rotation.y
        case .rotationZ: return t.rotation.z
        case .scaleX: return t.scale.x
        case .scaleY: return t.scale.y
        case .scaleZ: return t.scale.z
        case .lightIntensity: return node.light?.intensity
        case .cameraFieldOfView:
            if case let .perspective(fov)? = node.camera?.projection { return fov }
            return nil
        }
    }

    /// Writes a base value; ranges: scale not 0 (kept at ±0.0001), intensity ≥ 0, field of view 1...179.
    public static func setBase(_ property: PrismProperty, _ value: Double, on node: inout PrismNode) throws(PrismEditError) {
        guard property.applies(to: node.kind) else { throw .notAnimatable(property, node.kind) }
        guard value.isFinite else { throw .notANumber(property) }
        let v = clamp(property, value)
        switch property {
        case .positionX: node.transform.position.x = v
        case .positionY: node.transform.position.y = v
        case .positionZ: node.transform.position.z = v
        case .rotationX: node.transform.rotation.x = v
        case .rotationY: node.transform.rotation.y = v
        case .rotationZ: node.transform.rotation.z = v
        case .scaleX: node.transform.scale.x = v
        case .scaleY: node.transform.scale.y = v
        case .scaleZ: node.transform.scale.z = v
        case .lightIntensity: node.light?.intensity = v
        case .cameraFieldOfView: node.camera?.projection = .perspective(fieldOfViewDegrees: v)
        }
    }

    public static func clamp(_ property: PrismProperty, _ v: Double) -> Double {
        switch property {
        case .scaleX, .scaleY, .scaleZ: return abs(v) < 0.0001 ? (v < 0 ? -0.0001 : 0.0001) : v
        case .lightIntensity: return max(0, v)
        case .cameraFieldOfView: return min(179, max(1, v))
        default: return v
        }
    }

    public static func value(_ property: PrismProperty, of node: PrismNode, at frame: Int) -> Double? {
        guard let b = base(property, of: node) else { return nil }
        return sample(node.tracks[property.rawValue], base: b, at: frame)
    }

    /// The node's local transform at a frame, keys applied.
    public static func localTransform(of node: PrismNode, at frame: Int) -> PrismTransform {
        func v(_ p: PrismProperty) -> Double { value(p, of: node, at: frame) ?? 0 }
        return PrismTransform(position: Vec3(v(.positionX), v(.positionY), v(.positionZ)),
                              rotation: Vec3(v(.rotationX), v(.rotationY), v(.rotationZ)),
                              scale: Vec3(v(.scaleX), v(.scaleY), v(.scaleZ)))
    }

    /// Parent chain matrices multiplied root first; nil for a missing node. Stops at 256 levels (a cycle guard).
    public static func world(_ id: PrismID, in scene: PrismScene, at frame: Int) -> Mat4? {
        guard var node = scene.node(id) else { return nil }
        var m = localTransform(of: node, at: frame).matrix
        var depth = 0
        while let p = node.parentID, let parent = scene.node(p), depth < 256 {
            m = localTransform(of: parent, at: frame).matrix * m
            node = parent; depth += 1
        }
        return m
    }

    /// True when making `parent` the parent of `node` would make a cycle.
    public static func wouldCycle(_ node: PrismID, under parent: PrismID?, in scene: PrismScene) -> Bool {
        var cursor = parent, depth = 0
        while let c = cursor, depth < 4096 {
            if c == node { return true }
            cursor = scene.node(c)?.parentID; depth += 1
        }
        return false
    }

    /// The ids of `id` and everything under it.
    public static func subtree(_ id: PrismID, in scene: PrismScene) -> [PrismID] {
        var out = [id], i = 0
        while i < out.count {
            let current = out[i]
            out += scene.children(of: current).map(\.id).filter { !out.contains($0) }
            i += 1
        }
        return out
    }

    public static func worldBounds(_ ids: [PrismID], in scene: PrismScene, at frame: Int) -> Box3 {
        var box = Box3.empty
        for id in ids {
            for n in subtree(id, in: scene) {
                guard let node = scene.node(n), node.isVisible, let mesh = scene.mesh(node.meshID),
                      let w = world(n, in: scene, at: frame) else { continue }
                box = box.union(mesh.bounds.transformed(by: w))
            }
        }
        return box
    }

    /// A right-handed look-at view matrix (camera looks down -Z, +Y up).
    public static func lookAt(eye: Vec3, target: Vec3, up: Vec3 = Vec3(0, 1, 0)) -> Mat4? {
        guard let f = (target - eye).normalized else { return nil }
        let s = (f.cross(up).normalized ?? f.cross(Vec3(0, 0, 1)).normalized) ?? Vec3(1, 0, 0)
        let u = s.cross(f)
        return Mat4([s.x, u.x, -f.x, 0, s.y, u.y, -f.y, 0, s.z, u.z, -f.z, 0,
                     -s.dot(eye), -u.dot(eye), f.dot(eye), 1])
    }

    /// A key ref is valid when its node and track exist and a key sits on that frame.
    public static func hasKey(_ ref: PrismKeyRef, in scene: PrismScene) -> Bool {
        scene.node(ref.node)?.tracks[ref.property.rawValue]?.contains { $0.frame == ref.frame } ?? false
    }

    /// Every way a decoded document can be damaged; nil when it is sound.
    public static func damage(in state: PrismDocumentState) -> String? {
        let s = state.scene
        if let p = s.meshes.lazy.compactMap(\.problem).first { return p }
        if Set(s.nodes.map(\.id)).count != s.nodes.count { return "two objects share an id." }
        if s.textures.contains(where: { !$0.isValid }) { return "a texture has the wrong size." }
        for n in s.nodes {
            if let m = n.meshID, s.mesh(m) == nil { return "\(n.name) points at a mesh that isn't there." }
            if let p = n.parentID, s.node(p) == nil { return "\(n.name) points at a parent that isn't there." }
            if wouldCycle(n.id, under: n.parentID, in: s) { return "\(n.name) is inside itself." }
        }
        return nil
    }
}
