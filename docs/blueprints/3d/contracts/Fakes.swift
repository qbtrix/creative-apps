// Fakes.swift: one small, predictable fake per contract (blueprint part 6.4).
// W0 splits this file into Sources/PrismModel/Fakes/Fake<Contract>.swift.
// Each fake keeps its contract's rules (typed refusals, no change on throw)
// and differs from the live type only where its header says so. Shared rules
// come from PrismRules, never copied.
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

/// Differs: reads a tiny text stand-in, not real files. "cube" → one cube; "two cubes" → two;
/// "empty" → .empty; "broken" → .damaged; a gltf names "scene.bin" as its sidecar.
public struct FakeSceneImporting: SceneImporting {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func canImport(_ format: PrismImportFormat) -> Bool { format.isCore }
    public func sidecarNames(in data: Data, format: PrismImportFormat) throws(PrismImportError) -> [String] {
        guard canImport(format) else { throw .unsupportedFormat(format.rawValue) }
        return format == .gltf ? ["scene.bin"] : []
    }
    public func importModel(_ data: Data, format: PrismImportFormat, name: String,
                            sidecars: [String: Data]) throws(PrismImportError) -> PrismImportResult {
        guard canImport(format) else { throw .unsupportedFormat(format.rawValue) }
        if format == .gltf && sidecars["scene.bin"] == nil { throw .missingSidecar("scene.bin") }
        let text = PrismRules.trimmed(String(decoding: data, as: UTF8.self))
        let count: Int
        switch text {
        case "cube": count = 1
        case "two cubes": count = 2
        case "empty", "": throw .empty
        default: throw .damaged("the stand-in text \"\(text.prefix(20))\" isn't one the fake reads.")
        }
        let maker = FakePrimitiveMaking()
        var nodes: [PrismNode] = [], meshes: [PrismMesh] = []
        for i in 0..<count {
            let mesh = maker.mesh(for: .cube, id: PrismID("import-mesh-\(i)"), detail: 1)
            meshes.append(mesh)
            nodes.append(PrismNode(id: PrismID("import-node-\(i)"), name: count == 1 ? name : "\(name) \(i + 1)",
                                   kind: .mesh, transform: PrismTransform(position: Vec3(Double(i) * 2, 0, 0)),
                                   meshID: mesh.id, materialID: PrismID("import-mat")))
        }
        let warnings = format == .obj ? ["Skipped the .mtl file's textures: the fake reads no images."] : []
        return PrismImportResult(nodes: nodes, meshes: meshes,
                                 materials: [PrismMaterial(id: PrismID("import-mat"), name: "\(name) Material")],
                                 textures: [], warnings: warnings)
    }
}

/// Matches live in shape and size (1 unit across, centered); normals are left empty (flat shading).
public struct FakePrimitiveMaking: PrimitiveMaking {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func mesh(for primitive: PrismPrimitive, id: PrismID, detail: Int) -> PrismMesh {
        let n = Swift.max(3, Swift.min(256, detail < 3 ? 24 : detail))
        switch primitive {
        case .cube:
            let p = (0..<8).map { i in Vec3(i & 1 == 0 ? -0.5 : 0.5, i & 2 == 0 ? -0.5 : 0.5, i & 4 == 0 ? -0.5 : 0.5) }
            let f: [[UInt32]] = [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
            return PrismMesh(id: id, name: "Cube", positions: p, faces: f)
        case .plane:
            return PrismMesh(id: id, name: "Plane", positions: [Vec3(-0.5, 0, -0.5), Vec3(0.5, 0, -0.5),
                                                                  Vec3(0.5, 0, 0.5), Vec3(-0.5, 0, 0.5)],
                             faces: [[0, 3, 2, 1]])
        case .sphere:
            let rings = Swift.max(2, n / 2)
            let profile = (0...rings).map { r -> Vec2 in
                let a = Double.pi * Double(r) / Double(rings)
                return Vec2(0.5 * sin(a), 0.5 * cos(a))
            }
            return lathe(profile, segments: n, id: id, name: "Sphere", smooth: true)
        case .cylinder:
            return lathe([Vec2(0, 0.5), Vec2(0.5, 0.5), Vec2(0.5, -0.5), Vec2(0, -0.5)], segments: n, id: id,
                         name: "Cylinder", smooth: false)
        case .cone:
            return lathe([Vec2(0, 0.5), Vec2(0.5, -0.5), Vec2(0, -0.5)], segments: n, id: id, name: "Cone", smooth: false)
        case .torus:
            var p: [Vec3] = [], f: [[UInt32]] = []
            let m = Swift.max(3, n / 2)
            for i in 0..<n { for j in 0..<m {
                let u = 2 * Double.pi * Double(i) / Double(n), v = 2 * Double.pi * Double(j) / Double(m)
                let r = 0.375 + 0.125 * cos(v)
                p.append(Vec3(r * cos(u), 0.125 * sin(v), r * sin(u)))
                let a = i * m + j, b = ((i + 1) % n) * m + j, c = ((i + 1) % n) * m + (j + 1) % m, d = i * m + (j + 1) % m
                f.append([UInt32(a), UInt32(d), UInt32(c), UInt32(b)])
            } }
            return PrismMesh(id: id, name: "Torus", positions: p, faces: f, smooth: true)
        }
    }
    public func light(_ kind: PrismLightKind) -> (PrismLight, PrismTransform) {
        let intensity: Double = switch kind { case .directional: 3; case .point, .spot: 800; case .area: 20 }
        // .area is not offered in v1 (PrismLightKind.v1); the value is kept for files.
        return (PrismLight(kind: kind, intensity: intensity),
                PrismTransform(position: Vec3(0, 4, 0), rotation: Vec3(-90, 0, 0)))
    }

    /// Revolves a profile (x = radius, y = height; poles where x = 0) around +Y.
    private func lathe(_ profile: [Vec2], segments n: Int, id: PrismID, name: String, smooth: Bool) -> PrismMesh {
        var p: [Vec3] = [], f: [[UInt32]] = []
        var ringStart: [Int] = []
        for q in profile {
            ringStart.append(p.count)
            if q.x == 0 { p.append(Vec3(0, q.y, 0)); continue }
            for i in 0..<n {
                let a = 2 * Double.pi * Double(i) / Double(n)
                p.append(Vec3(q.x * cos(a), q.y, q.x * sin(a)))
            }
        }
        for k in 0..<(profile.count - 1) {
            let (top, bottom) = (profile[k], profile[k + 1])
            let (s0, s1) = (ringStart[k], ringStart[k + 1])
            for i in 0..<n {
                let j = (i + 1) % n
                switch (top.x == 0, bottom.x == 0) {
                case (true, true): continue
                case (true, false): f.append([UInt32(s0), UInt32(s1 + j), UInt32(s1 + i)])
                case (false, true): f.append([UInt32(s0 + i), UInt32(s0 + j), UInt32(s1)])
                case (false, false): f.append([UInt32(s0 + i), UInt32(s0 + j), UInt32(s1 + j), UInt32(s1 + i)])
                }
            }
        }
        return PrismMesh(id: id, name: name, positions: p, faces: f, smooth: smooth)
    }
}

/// Differs: no bevel, and caps are fans (exact for convex contours); holes are ignored.
public struct FakeShapeExtruding: ShapeExtruding {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func extrude(_ outline: PrismOutline, _ extrusion: PrismExtrusion, id: PrismID,
                        name: String) throws(PrismEditError) -> PrismMesh {
        guard !outline.isEmpty else { throw .emptyOutline }
        guard extrusion.depth > 0, extrusion.depth.isFinite else { throw .outOfRange("Depth must be more than 0.") }
        var p: [Vec3] = [], f: [[UInt32]] = []
        for c in outline.contours where c.count >= 3 && signedArea(c) > 0 {
            let base = p.count, n = c.count
            p += c.map { Vec3($0.x, $0.y, extrusion.depth / 2) } + c.map { Vec3($0.x, $0.y, -extrusion.depth / 2) }
            f.append((0..<n).map { UInt32(base + $0) })
            f.append((0..<n).reversed().map { UInt32(base + n + $0) })
            for i in 0..<n {
                let j = (i + 1) % n
                f.append([UInt32(base + i), UInt32(base + n + i), UInt32(base + n + j), UInt32(base + j)])
            }
        }
        guard !f.isEmpty else { throw .emptyOutline }
        return PrismMesh(id: id, name: name, positions: p, faces: f)
    }
    private func signedArea(_ c: [Vec2]) -> Double {
        zip(c, c.dropFirst() + c.prefix(1)).reduce(0) { $0 + ($1.0.x * $1.1.y - $1.1.x * $1.0.y) } / 2
    }
}

/// Differs: every non-space character is a 0.6 × 0.7 em box; the advance is 0.7 em.
public struct FakeGlyphOutlining: GlyphOutlining {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func outline(of text: String, fontName: String, size: Double) -> PrismOutline {
        var contours: [[Vec2]] = []
        for (i, ch) in text.enumerated() where !ch.isWhitespace {
            let x = Double(i) * 0.7 * size
            contours.append([Vec2(x, 0), Vec2(x + 0.6 * size, 0), Vec2(x + 0.6 * size, 0.7 * size), Vec2(x, 0.7 * size)])
        }
        return PrismOutline(contours: contours)
    }
}

public struct FakeSceneArranging: SceneArranging {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func worldMatrix(of node: PrismID, in scene: PrismScene, at frame: Int) -> Mat4? {
        PrismRules.world(node, in: scene, at: frame)
    }
    public func worldBounds(of nodes: [PrismID], in scene: PrismScene, at frame: Int) -> Box3 {
        PrismRules.worldBounds(nodes, in: scene, at: frame)
    }
    public func reparent(_ node: PrismID, to parent: PrismID?, index: Int, keepWorld: Bool,
                         in scene: inout PrismScene, at frame: Int) throws(PrismEditError) {
        guard let i = scene.nodes.firstIndex(where: { $0.id == node }) else { throw .noSuchNode(node) }
        if let p = parent, scene.node(p) == nil { throw .noSuchNode(p) }
        if PrismRules.wouldCycle(node, under: parent, in: scene) { throw .parentCycle }
        var copy = scene
        var moved = copy.nodes[i]
        // Differs: keepWorld keeps the world position only (rotation and scale of parents are not undone).
        if keepWorld, let before = PrismRules.world(node, in: scene, at: frame) {
            let parentWorld = parent.flatMap { PrismRules.world($0, in: scene, at: frame) } ?? .identity
            if let inv = parentWorld.affineInverse {
                moved.transform.position = inv.transformPoint(Vec3(before[0, 3], before[1, 3], before[2, 3]))
            }
        }
        moved.parentID = parent
        let subtree = PrismRules.subtree(node, in: scene)
        let block = [moved] + copy.nodes.filter { subtree.contains($0.id) && $0.id != node }
        copy.nodes.removeAll { subtree.contains($0.id) }
        let siblings = copy.nodes.enumerated().filter { $0.element.parentID == parent }.map(\.offset)
        let at: Int
        if index < siblings.count, index >= 0 { at = siblings[index] }
        else if let lastSibling = siblings.last {
            at = (PrismRules.subtree(copy.nodes[lastSibling].id, in: copy).compactMap { id in
                copy.nodes.firstIndex { $0.id == id } }.max() ?? lastSibling) + 1
        } else if let p = parent, let pi = copy.nodes.firstIndex(where: { $0.id == p }) { at = pi + 1 }
        else { at = copy.nodes.count }
        copy.nodes.insert(contentsOf: block, at: Swift.min(at, copy.nodes.count))
        scene = copy
    }
}

/// Matches live: the same math, which lives in PrismRules once live lands (part 6.3).
public struct FakeViewNavigating: ViewNavigating {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func orbit(_ view: PrismViewCamera, dx: Double, dy: Double) -> PrismViewCamera {
        var v = view
        v.yawDegrees = (v.yawDegrees - dx * 0.25).truncatingRemainder(dividingBy: 360)
        v.pitchDegrees = Swift.min(89.9, Swift.max(-89.9, v.pitchDegrees - dy * 0.25))
        return v
    }
    public func pan(_ view: PrismViewCamera, dx: Double, dy: Double, viewHeightPoints: Double) -> PrismViewCamera {
        guard viewHeightPoints > 0 else { return view }
        let worldHeight = 2 * view.distance * tan(view.fieldOfViewDegrees * .pi / 360)
        let perPoint = worldHeight / viewHeightPoints
        let q = Quat(axis: Vec3(0, 1, 0), degrees: view.yawDegrees) * Quat(axis: Vec3(1, 0, 0), degrees: view.pitchDegrees)
        var v = view
        v.target = v.target - q.rotate(Vec3(1, 0, 0)) * (dx * perPoint) + q.rotate(Vec3(0, 1, 0)) * (dy * perPoint)
        return v
    }
    public func dolly(_ view: PrismViewCamera, factor: Double) -> PrismViewCamera {
        guard factor > 0, factor.isFinite else { return view }
        var v = view
        v.distance = Swift.min(PrismViewCamera.maximumDistance, Swift.max(PrismViewCamera.minimumDistance, v.distance / factor))
        return v
    }
    public func frame(_ bounds: Box3, in view: PrismViewCamera, aspect: Double) -> PrismViewCamera {
        guard !bounds.isEmpty else { return PrismViewCamera() }
        let radius = Swift.max(bounds.size.length / 2, 0.01) * 1.1
        let half = view.fieldOfViewDegrees * .pi / 360
        let fit = Swift.min(half, atan(tan(half) * Swift.max(aspect, 0.01)))
        var v = view
        v.target = bounds.center
        v.distance = Swift.min(PrismViewCamera.maximumDistance, radius / Swift.max(sin(fit), 0.01))
        return v
    }
    public func preset(_ preset: PrismViewPreset, from view: PrismViewCamera) -> PrismViewCamera {
        var v = view
        let (yaw, pitch, ortho): (Double, Double, Bool) = switch preset {
        case .front: (0, 0, true)
        case .back: (180, 0, true)
        case .left: (-90, 0, true)
        case .right: (90, 0, true)
        case .top: (0, -89.9, true)
        case .bottom: (0, 89.9, true)
        case .perspective: (35, -25, false)
        }
        v.yawDegrees = yaw; v.pitchDegrees = pitch; v.isOrthographic = ortho
        return v
    }
    public func viewMatrix(for viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int) -> (view: Mat4, eye: Vec3)? {
        switch viewpoint {
        case let .free(v):
            return PrismRules.lookAt(eye: v.eye, target: v.target).map { ($0, v.eye) }
        case let .camera(id):
            guard scene.node(id)?.kind == .camera, let w = PrismRules.world(id, in: scene, at: frame),
                  let inv = w.affineInverse else { return nil }
            return (inv, Vec3(w[0, 3], w[1, 3], w[2, 3]))
        }
    }
}

/// Differs: hits world bounding boxes, not triangles.
public struct FakeViewportPicking: ViewportPicking {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func ray(at point: ViewPoint, viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int,
                    aspect: Double) -> PrismRay? {
        guard let (view, eye) = FakeViewNavigating().viewMatrix(for: viewpoint, in: scene, at: frame),
              let world = view.affineInverse else { return nil }
        let fov: Double
        switch viewpoint {
        case let .free(v): fov = v.fieldOfViewDegrees
        case let .camera(id):
            if case let .perspective(f)? = scene.node(id)?.camera?.projection { fov = f } else { fov = 40 }
        }
        let t = tan(fov * .pi / 360)
        let dir = Vec3((point.x * 2 - 1) * t * aspect, (1 - point.y * 2) * t, -1)
        guard let d = world.transformDirection(dir).normalized else { return nil }
        return PrismRay(origin: eye, direction: d)
    }
    public func hit(_ ray: PrismRay, in scene: PrismScene, at frame: Int) -> PrismHit? {
        var best: PrismHit?
        for node in scene.nodes where node.kind == .mesh && node.isVisible {
            let box = PrismRules.worldBounds([node.id], in: scene, at: frame)
            guard let t = Self.slab(ray, box), t >= 0, t < (best?.distance ?? .infinity) else { continue }
            best = PrismHit(node: node.id, distance: t, point: ray.origin + ray.direction * t)
        }
        return best
    }
    static func slab(_ r: PrismRay, _ b: Box3) -> Double? {
        guard !b.isEmpty else { return nil }
        var lo = -Double.infinity, hi = Double.infinity
        for (o, d, mn, mx) in [(r.origin.x, r.direction.x, b.min.x, b.max.x), (r.origin.y, r.direction.y, b.min.y, b.max.y),
                               (r.origin.z, r.direction.z, b.min.z, b.max.z)] {
            if abs(d) < 1e-12 { if o < mn || o > mx { return nil }; continue }
            let (t1, t2) = ((mn - o) / d, (mx - o) / d)
            lo = Swift.max(lo, Swift.min(t1, t2)); hi = Swift.min(hi, Swift.max(t1, t2))
        }
        return lo <= hi && hi >= 0 ? Swift.max(lo, 0) : nil
    }
}

/// Differs: screen deltas map linearly (10 units, 360° or ×3 per full view width), not by projection.
public struct FakeGizmoDragging: GizmoDragging {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func begin(_ mode: PrismGizmoMode, handle: PrismGizmoHandle, node: PrismID, at point: ViewPoint,
                      viewpoint: PrismViewpoint, in scene: PrismScene, at frame: Int, aspect: Double) -> PrismGizmoDrag? {
        guard let n = scene.node(node), let w = PrismRules.world(node, in: scene, at: frame) else { return nil }
        return PrismGizmoDrag(node: node, mode: mode, handle: handle, start: point,
                              startTransform: PrismRules.localTransform(of: n, at: frame),
                              startWorldPoint: Vec3(w[0, 3], w[1, 3], w[2, 3]))
    }
    public func transform(for drag: PrismGizmoDrag, to point: ViewPoint, viewpoint: PrismViewpoint,
                          in scene: PrismScene, at frame: Int, aspect: Double, snap: PrismSnap) -> PrismTransform {
        let dx = point.x - drag.start.x, dy = drag.start.y - point.y
        var t = drag.startTransform
        func snapped(_ v: Double, _ step: Double) -> Double { step > 0 ? (v / step).rounded() * step : v }
        func axisVector(_ a: PrismAxis) -> Vec3 { a == .x ? Vec3(1, 0, 0) : a == .y ? Vec3(0, 1, 0) : Vec3(0, 0, 1) }
        switch drag.mode {
        case .move:
            let delta: Vec3 = switch drag.handle {
            case let .axis(a): axisVector(a) * ((a == .y ? dy : dx) * 10)
            case let .plane(a): a == .y ? Vec3(dx * 10, 0, -dy * 10) : a == .z ? Vec3(dx * 10, dy * 10, 0) : Vec3(0, dy * 10, dx * 10)
            case .screen: Vec3(dx * 10, dy * 10, 0)
            }
            let p = t.position + delta
            t.position = Vec3(snapped(p.x, snap.move), snapped(p.y, snap.move), snapped(p.z, snap.move))
        case .rotate:
            let degrees = snapped(dx * 360, snap.rotateDegrees)
            switch drag.handle {
            case .axis(.x), .plane(.x): t.rotation.x += degrees
            case .axis(.y), .plane(.y): t.rotation.y += degrees
            case .axis(.z), .plane(.z), .screen: t.rotation.z += degrees
            }
        case .scale:
            let f = Swift.max(0.0001, 1 + snapped(dx * 3, snap.scale))
            switch drag.handle {
            case .axis(.x): t.scale.x *= f
            case .axis(.y): t.scale.y *= f
            case .axis(.z): t.scale.z *= f
            case .plane, .screen: t.scale = t.scale * f
            }
        }
        return t
    }
}

public struct FakeMaterialEditing: MaterialEditing {
    public init() {}
    public var unavailableHelp: String? { nil }
    public var presets: [PrismMaterial] {
        [("Matte", PrismColor(0.8, 0.8, 0.8), 0.0, 0.9), ("Plastic", PrismColor(0.8, 0.1, 0.1), 0, 0.35),
         ("Rubber", PrismColor(0.05, 0.05, 0.05), 0, 0.8), ("Metal", PrismColor(0.9, 0.9, 0.9), 1, 0.35),
         ("Chrome", PrismColor(0.95, 0.95, 0.95), 1, 0.05), ("Gold", PrismColor(1.0, 0.77, 0.34), 1, 0.25)]
            .map { PrismMaterial(id: PrismID("preset-\($0.0.lowercased())"), name: $0.0, baseColor: $0.1, metallic: $0.2, roughness: $0.3) }
        + [PrismMaterial(id: PrismID("preset-glow"), name: "Glow", baseColor: .black, emissive: .white, emissiveStrength: 5)]
    }
    public func update(_ material: PrismMaterial, in scene: inout PrismScene) throws(PrismEditError) {
        guard let i = scene.materials.firstIndex(where: { $0.id == material.id }) else { throw .noSuchMaterial(material.id) }
        guard !PrismRules.trimmed(material.name).isEmpty else { throw .emptyName }
        var m = material
        func c(_ v: Double, _ hi: Double) -> Double { v.isFinite ? Swift.min(hi, Swift.max(0, v)) : 0 }
        m.metallic = c(m.metallic, 1); m.roughness = c(m.roughness, 1); m.emissiveStrength = c(m.emissiveStrength, 100)
        scene.materials[i] = m
    }
    public func assign(_ material: PrismID, to nodes: [PrismID], in scene: inout PrismScene) throws(PrismEditError) {
        guard scene.material(material) != nil else { throw .noSuchMaterial(material) }
        guard !nodes.isEmpty else { throw .nothingSelected }
        var copy = scene
        for id in nodes {
            guard let i = copy.nodes.firstIndex(where: { $0.id == id }) else { throw .noSuchNode(id) }
            guard copy.nodes[i].kind == .mesh else { throw .outOfRange("Only objects with a shape take a material.") }
            copy.nodes[i].materialID = material
        }
        scene = copy
    }
}

public struct FakeLightEditing: LightEditing {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func update(_ light: PrismLight, of node: PrismID, in scene: inout PrismScene) throws(PrismEditError) {
        guard let i = scene.nodes.firstIndex(where: { $0.id == node }) else { throw .noSuchNode(node) }
        guard scene.nodes[i].kind == .light else { throw .outOfRange("That object isn't a light.") }
        guard light.intensity.isFinite, light.intensity >= 0 else { throw .outOfRange("Intensity can't be below 0.") }
        guard light.outerConeDegrees >= light.innerConeDegrees, light.outerConeDegrees <= 90 else {
            throw .outOfRange("The outer cone must be wider than the inner one and at most 90°.")
        }
        scene.nodes[i].light = light
    }
    public func setEnvironment(_ environment: PrismEnvironment, in scene: inout PrismScene) throws(PrismEditError) {
        if let image = environment.imageID, !scene.textures.contains(where: { $0.id == image }) {
            throw .outOfRange("That environment image is no longer in the scene.")
        }
        guard environment.intensity.isFinite, environment.intensity >= 0 else { throw .outOfRange("Intensity can't be below 0.") }
        scene.environment = environment
    }
    public var rigNames: [String] { ["Three-Point", "Studio Soft", "Rim"] }
    public func rig(named name: String, around bounds: Box3) -> [(name: String, light: PrismLight, transform: PrismTransform)] {
        let c = bounds.isEmpty ? Vec3.zero : bounds.center, r = Swift.max(1, bounds.size.length)
        func spot(_ n: String, _ i: Double, _ at: Vec3, _ rot: Vec3) -> (name: String, light: PrismLight, transform: PrismTransform) {
            (n, PrismLight(kind: .spot, intensity: i, outerConeDegrees: 40), PrismTransform(position: c + at * r, rotation: rot))
        }
        switch name {
        case "Three-Point":
            return [spot("Key", 1000, Vec3(1, 1, 1), Vec3(-35, 45, 0)), spot("Fill", 300, Vec3(-1, 0.5, 1), Vec3(-20, -45, 0)),
                    spot("Rim", 600, Vec3(0, 1, -1), Vec3(-45, 180, 0))]
        case "Studio Soft":
            // Two wide, soft spots stand in for a softbox until area lights land.
            return [spot("Soft Left", 500, Vec3(-0.7, 1.5, 1), Vec3(-50, -25, 0)), spot("Soft Right", 500, Vec3(0.7, 1.5, 1), Vec3(-50, 25, 0))]
        case "Rim":
            return [spot("Rim Left", 800, Vec3(-1, 0.5, -1), Vec3(-20, -135, 0)), spot("Rim Right", 800, Vec3(1, 0.5, -1), Vec3(-20, 135, 0))]
        default:
            return []
        }
    }
}

public struct FakeCameraDirecting: CameraDirecting {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func camera(matching view: PrismViewCamera) -> (PrismCamera, PrismTransform) {
        let projection: PrismProjection = view.isOrthographic
            ? .orthographic(height: 2 * view.distance * tan(view.fieldOfViewDegrees * .pi / 360))
            : .perspective(fieldOfViewDegrees: view.fieldOfViewDegrees)
        return (PrismCamera(projection: projection),
                PrismTransform(position: view.eye, rotation: Vec3(view.pitchDegrees, view.yawDegrees, 0)))
    }
    public func setActiveCamera(_ node: PrismID?, in scene: inout PrismScene) throws(PrismEditError) {
        if let n = node {
            guard let found = scene.node(n) else { throw .noSuchNode(n) }
            guard found.kind == .camera else { throw .outOfRange("That object isn't a camera.") }
        }
        scene.activeCameraID = node
    }
    public func update(_ camera: PrismCamera, of node: PrismID, in scene: inout PrismScene) throws(PrismEditError) {
        guard let i = scene.nodes.firstIndex(where: { $0.id == node }) else { throw .noSuchNode(node) }
        guard scene.nodes[i].kind == .camera else { throw .outOfRange("That object isn't a camera.") }
        guard camera.near > 0, camera.far > camera.near else { throw .outOfRange("Far must be beyond near, and near above 0.") }
        if case let .perspective(f) = camera.projection, !(1...179).contains(f) {
            throw .outOfRange("Field of view must be from 1° to 179°.")
        }
        scene.nodes[i].camera = camera
    }
}

public struct FakePropertyKeying: PropertyKeying {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func value(of property: PrismProperty, node: PrismID, in scene: PrismScene, at frame: Int) -> Double? {
        scene.node(node).flatMap { PrismRules.value(property, of: $0, at: frame) }
    }
    public func isAnimated(_ property: PrismProperty, node: PrismID, in scene: PrismScene) -> Bool {
        !(scene.node(node)?.tracks[property.rawValue]?.isEmpty ?? true)
    }
    public func setValue(_ value: Double, of property: PrismProperty, node: PrismID, at frame: Int,
                         in scene: inout PrismScene) throws(PrismEditError) {
        guard let i = scene.nodes.firstIndex(where: { $0.id == node }) else { throw .noSuchNode(node) }
        var n = scene.nodes[i]
        guard property.applies(to: n.kind) else { throw .notAnimatable(property, n.kind) }
        guard value.isFinite else { throw .notANumber(property) }
        let v = PrismRules.clamp(property, value)
        if var track = n.tracks[property.rawValue], !track.isEmpty {
            if let k = track.firstIndex(where: { $0.frame == frame }) { track[k].value = v }
            else { track.append(PrismKey(frame: frame, value: v)); track.sort { $0.frame < $1.frame } }
            n.tracks[property.rawValue] = track
        } else {
            try PrismRules.setBase(property, v, on: &n)
        }
        scene.nodes[i] = n
    }
    public func toggleAnimation(_ property: PrismProperty, node: PrismID, at frame: Int,
                                in scene: inout PrismScene) throws(PrismEditError) {
        guard let i = scene.nodes.firstIndex(where: { $0.id == node }) else { throw .noSuchNode(node) }
        let n = scene.nodes[i]
        guard let v = PrismRules.value(property, of: n, at: frame) else { throw .notAnimatable(property, n.kind) }
        if isAnimated(property, node: node, in: scene) {
            var copy = n
            try PrismRules.setBase(property, v, on: &copy)
            copy.tracks[property.rawValue] = nil
            scene.nodes[i] = copy
        } else {
            let last = scene.settings.lastFrame
            let keys = Set([frame, last]).sorted().map { PrismKey(frame: $0, value: v) }
            scene.nodes[i].tracks[property.rawValue] = keys
        }
    }
    public func toggleKey(_ property: PrismProperty, node: PrismID, at frame: Int,
                          in scene: inout PrismScene) throws(PrismEditError) {
        guard let i = scene.nodes.firstIndex(where: { $0.id == node }) else { throw .noSuchNode(node) }
        let n = scene.nodes[i]
        guard let v = PrismRules.value(property, of: n, at: frame) else { throw .notAnimatable(property, n.kind) }
        var track = n.tracks[property.rawValue] ?? []
        if let k = track.firstIndex(where: { $0.frame == frame }) { track.remove(at: k) }
        else { track.append(PrismKey(frame: frame, value: v)); track.sort { $0.frame < $1.frame } }
        var copy = n
        if track.isEmpty { try PrismRules.setBase(property, v, on: &copy); copy.tracks[property.rawValue] = nil }
        else { copy.tracks[property.rawValue] = track }
        scene.nodes[i] = copy
    }
    public func keyFrames(of node: PrismID, in scene: PrismScene) -> [Int] {
        Set(scene.node(node)?.tracks.values.flatMap { $0.map(\.frame) } ?? []).sorted()
    }
}

public struct FakeKeyEasing: KeyEasing {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func setEasing(_ easing: PrismEasing, for keys: [PrismKeyRef], in scene: inout PrismScene) throws(PrismEditError) {
        guard !keys.isEmpty else { throw .nothingSelected }
        var copy = scene
        for ref in keys {
            guard PrismRules.hasKey(ref, in: copy), let i = copy.nodes.firstIndex(where: { $0.id == ref.node }),
                  var track = copy.nodes[i].tracks[ref.property.rawValue],
                  let k = track.firstIndex(where: { $0.frame == ref.frame }) else { throw .noSuchNode(ref.node) }
            track[k].easing = easing
            copy.nodes[i].tracks[ref.property.rawValue] = track
        }
        scene = copy
    }
}

public struct FakePlaybackClock: PlaybackClock {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func frame(at now: Double, startTime: Double, startFrame: Int, settings: PrismSceneSettings, loops: Bool) -> Int {
        let total = Swift.max(1, settings.durationFrames)
        let elapsed = Swift.max(0, now - startTime)
        let raw = startFrame + Int((elapsed * Double(settings.framesPerSecond) + 1e-6).rounded(.down))
        return loops ? raw % total : Swift.min(raw, total - 1)
    }
}

public struct FakeSceneHistory: SceneHistory {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func record(_ before: PrismDocumentState, name: String, coalesceKey: String?, into history: inout PrismHistory) {
        history.redo.removeAll()
        if let key = coalesceKey, history.coalescing, history.undo.last?.coalesceKey == key { return }
        history.undo.append(.init(name: name, coalesceKey: coalesceKey, state: before))
        if history.undo.count > PrismHistory.limit { history.undo.removeFirst(history.undo.count - PrismHistory.limit) }
        history.coalescing = coalesceKey != nil
    }
    public func undo(_ current: PrismDocumentState, history: inout PrismHistory) -> PrismDocumentState? {
        guard let step = history.undo.popLast() else { return nil }
        history.redo.append(.init(name: step.name, coalesceKey: nil, state: current))
        history.coalescing = false
        return step.state
    }
    public func redo(_ current: PrismDocumentState, history: inout PrismHistory) -> PrismDocumentState? {
        guard let step = history.redo.popLast() else { return nil }
        history.undo.append(.init(name: step.name, coalesceKey: nil, state: current))
        history.coalescing = false
        return step.state
    }
}

/// Differs: keeps meshes and textures inside the JSON (no buffers); checks the envelope, version,
/// size and PrismRules.damage like live.
public struct FakeSceneFiles: SceneFiles {
    public init() {}
    public var unavailableHelp: String? { nil }
    struct Envelope: Codable { var format: String; var version: Int; var state: PrismDocumentState? }
    public func encode(_ state: PrismDocumentState) throws(PrismFileError) -> PrismFilePackage {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.sortedKeys]
            let data = try enc.encode(Envelope(format: PrismFilePackage.formatName, version: PrismFilePackage.version, state: state))
            return PrismFilePackage(document: data, buffers: [:])
        } catch { throw .damaged("it couldn't be written.") }
    }
    public func decode(_ package: PrismFilePackage) throws(PrismFileError) -> PrismDocumentState {
        let size = package.document.count + package.buffers.values.reduce(0) { $0 + $1.count }
        guard size <= PrismFilePackage.maximumBytes else { throw .tooLarge }
        guard let head = try? JSONDecoder().decode(Envelope.self, from: package.document),
              head.format == PrismFilePackage.formatName else { throw .notAPrismFile }
        guard head.version <= PrismFilePackage.version else { throw .newerFormat(head.version) }
        guard let state = head.state else { throw .damaged("it has no scene.") }
        if let reason = PrismRules.damage(in: state) { throw .damaged(reason) }
        return state
    }
}

/// Differs: writes OBJ text only (no glb, stl or usdz); keys baked at `frame`.
public struct FakeSceneExporting: SceneExporting {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func canExport(_ format: PrismExportFormat) -> Bool { format == .obj }
    public func export(_ scene: PrismScene, format: PrismExportFormat, at frame: Int) throws(PrismFileError) -> Data {
        guard canExport(format) else { throw .unsupportedExport(format.rawValue) }
        var out = "# Prism OBJ\n", base = 1
        for node in scene.nodes where node.kind == .mesh && node.isVisible {
            guard let mesh = scene.mesh(node.meshID), let w = PrismRules.world(node.id, in: scene, at: frame) else { continue }
            out += "o \(node.name)\n"
            for p in mesh.positions { let q = w.transformPoint(p); out += "v \(q.x) \(q.y) \(q.z)\n" }
            for f in mesh.faces { out += "f " + f.map { String(Int($0) + base) }.joined(separator: " ") + "\n" }
            base += mesh.positions.count
        }
        return Data(out.utf8)
    }
}

public struct FakeFrameDrawing: FrameDrawing {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func drawList(_ scene: PrismScene, selection: [PrismID], viewpoint: PrismViewpoint, at frame: Int,
                         aspect: Double) -> PrismDrawList? {
        guard let (view, eye) = FakeViewNavigating().viewMatrix(for: viewpoint, in: scene, at: frame) else { return nil }
        let fallback = PrismMaterial(id: PrismID("default"), name: "Default")
        var items: [PrismDrawItem] = [], lights: [PrismDrawLight] = []
        for node in scene.nodes where node.isVisible {
            guard let w = PrismRules.world(node.id, in: scene, at: frame) else { continue }
            if node.kind == .mesh, let mesh = node.meshID, scene.mesh(mesh) != nil {
                items.append(PrismDrawItem(node: node.id, mesh: mesh, world: w,
                                           material: scene.material(node.materialID) ?? fallback,
                                           isSelected: selection.contains(node.id)))
            }
            if node.kind == .light, var light = node.light {
                light.intensity = PrismRules.value(.lightIntensity, of: node, at: frame) ?? light.intensity
                lights.append(PrismDrawLight(light: light, position: Vec3(w[0, 3], w[1, 3], w[2, 3]),
                                             direction: w.transformDirection(Vec3(0, 0, -1)).normalized ?? Vec3(0, -1, 0)))
            }
        }
        let projection: PrismProjection, near: Double, far: Double
        switch viewpoint {
        case let .free(v):
            projection = v.isOrthographic ? .orthographic(height: 2 * v.distance * tan(v.fieldOfViewDegrees * .pi / 360))
                : .perspective(fieldOfViewDegrees: v.fieldOfViewDegrees)
            near = 0.01; far = 10_000
        case let .camera(id):
            guard let node = scene.node(id), let cam = node.camera else { return nil }
            if case .perspective = cam.projection {
                projection = .perspective(fieldOfViewDegrees: PrismRules.value(.cameraFieldOfView, of: node, at: frame) ?? 40)
            } else { projection = cam.projection }
            near = cam.near; far = cam.far
        }
        return PrismDrawList(frame: frame, items: items, lights: lights, view: view, eye: eye, projection: projection,
                             near: near, far: far, aspect: aspect, environment: scene.environment)
    }
}

/// Differs: flat, unlit: each item's projected bounding box filled with its base color, no depth test,
/// drawn in list order; background is the environment color (alpha 0 when transparent).
public struct FakeFrameRendering: FrameRendering {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func render(_ list: PrismDrawList, meshes: [PrismMesh], textures: [PrismTexture], width: Int, height: Int,
                       quality: PrismRenderQuality) throws(PrismRenderError) -> PrismImage {
        guard (16...8192).contains(width), (16...8192).contains(height) else { throw .badSize }
        let env = list.environment, a: Float = env.transparentBackground ? 0 : 1
        var px = [Float](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            px[i * 4] = Float(env.color.r) * a; px[i * 4 + 1] = Float(env.color.g) * a; px[i * 4 + 2] = Float(env.color.b) * a
            px[i * 4 + 3] = a
        }
        let fov: Double
        if case let .perspective(f) = list.projection { fov = f } else { fov = 40 }
        let t = tan(fov * .pi / 360)
        for item in list.items {
            guard let mesh = meshes.first(where: { $0.id == item.mesh }) else { continue }
            let box = mesh.bounds.transformed(by: list.view * item.world)
            guard !box.isEmpty, box.max.z < -list.near else { continue }
            let z = Swift.max(-box.max.z, list.near)
            func sx(_ x: Double) -> Int { Int(((x / (z * t * list.aspect)) + 1) / 2 * Double(width)) }
            func sy(_ y: Double) -> Int { Int((1 - (y / (z * t))) / 2 * Double(height)) }
            let (x0, x1) = (Swift.max(0, sx(box.min.x)), Swift.min(width, sx(box.max.x)))
            let (y0, y1) = (Swift.max(0, sy(box.max.y)), Swift.min(height, sy(box.min.y)))
            guard x0 < x1, y0 < y1 else { continue }
            let c = item.material.baseColor
            for y in y0..<y1 { for x in x0..<x1 {
                let i = (y * width + x) * 4
                px[i] = Float(c.r); px[i + 1] = Float(c.g); px[i + 2] = Float(c.b); px[i + 3] = 1
            } }
        }
        return PrismImage(width: width, height: height, rgba: px)
    }
}

public struct FakeSequenceRendering: SequenceRendering {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func problem(with plan: PrismRenderPlan, scene: PrismScene) -> PrismRenderError? {
        guard (16...8192).contains(plan.width), (16...8192).contains(plan.height) else { return .badSize }
        guard plan.frames.lowerBound >= 0, plan.frames.upperBound <= scene.settings.lastFrame else { return .badSize }
        return nil
    }
    public func run(_ plan: PrismRenderPlan, scene: PrismScene, viewpoint: PrismViewpoint, drawing: any FrameDrawing,
                    renderer: any FrameRendering, sink: any RenderSink, progress: @Sendable (Int) -> Void,
                    isCancelled: @Sendable () -> Bool) -> PrismRenderOutcome {
        if let p = problem(with: plan, scene: scene) { return .failed(frame: plan.frames.lowerBound, message: p.message) }
        do throws(PrismRenderError) {
            try sink.begin(plan)
            for (index, frame) in plan.frames.enumerated() {
                if isCancelled() { sink.cancel(plan); return .cancelled(atFrame: frame) }
                var s = scene
                s.environment.transparentBackground = plan.transparentBackground
                guard let list = drawing.drawList(s, selection: [], viewpoint: viewpoint, at: frame,
                                                  aspect: Double(plan.width) / Double(plan.height)) else { throw .noCamera }
                let image = try renderer.render(list, meshes: s.meshes, textures: s.textures, width: plan.width,
                                                height: plan.height, quality: plan.quality)
                try sink.write(image, index: index, plan: plan)
                progress(index + 1)
            }
            let files = try sink.finish(plan)
            return .finished(files: files, frames: plan.frames.count)
        } catch {
            sink.cancel(plan)
            return .failed(frame: plan.frames.lowerBound, message: error.message)
        }
    }
}

/// Matches live's rules: Halo takes PNG sequences and alpha movies, Flare stills and PNG sequences,
/// Design stills. Live also asks the suite whether the target's import has shipped.
public struct FakeRenderHandingOff: RenderHandingOff {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func refusal(for target: PrismHandOffTarget, plan: PrismRenderPlan) -> String? {
        let ok: Set<PrismRenderFormat> = switch target {
        case .halo: [.pngSequence, .movieWithAlpha]
        case .flare: [.still, .pngSequence]
        case .design: [.still]
        }
        return ok.contains(plan.format) ? nil : "\(target.title) can't take this kind of render. Pick "
            + (target == .design ? "Still." : target == .flare ? "Still or PNG Sequence." : "PNG Sequence or Movie with Alpha.")
    }
    public func request(for target: PrismHandOffTarget, plan: PrismRenderPlan, outcome: PrismRenderOutcome,
                        settings: PrismSceneSettings, sourceDocument: String?) -> PrismHandOffRequest? {
        guard refusal(for: target, plan: plan) == nil, case let .finished(files, _) = outcome, !files.isEmpty else { return nil }
        return PrismHandOffRequest(target: target, files: files, framesPerSecond: settings.framesPerSecond, width: plan.width,
                                   height: plan.height, hasAlpha: plan.transparentBackground && plan.format != .movie,
                                   sourceDocument: sourceDocument)
    }
}

/// Differs: bevel is left to the live engine (unavailableHelp says so); loop cut works on quads only.
public struct FakeMeshEditing: MeshEditing {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func unavailableHelp(for op: PrismMeshOpKind) -> String? {
        op == .bevel ? "Bevel arrives with the live mesh engine." : nil
    }
    public func pick(_ ray: PrismRay, mesh: PrismMesh, world: Mat4, mode: PrismSelectMode) -> PrismMeshElement? {
        var best: (face: Int, t: Double, point: Vec3)?
        let p = mesh.positions.map { world.transformPoint($0) }
        for (fi, f) in mesh.faces.enumerated() where f.count >= 3 {
            for k in 1..<(f.count - 1) {
                let (ia, ib, ic) = (Int(f[0]), Int(f[k]), Int(f[k + 1]))
                guard ia < p.count, ib < p.count, ic < p.count,
                      let t = Self.triangle(ray, p[ia], p[ib], p[ic]), t < (best?.t ?? .infinity) else { continue }
                best = (fi, t, ray.origin + ray.direction * t)
            }
        }
        guard let hit = best, hit.face < mesh.faces.count else { return nil }
        let face = mesh.faces[hit.face].map(Int.init)
        switch mode {
        case .face: return .face(hit.face)
        case .vertex:
            let v = face.min { (p[$0] - hit.point).length < (p[$1] - hit.point).length }
            return v.map { .vertex($0) }
        case .edge:
            let edges = face.indices.map { PrismEdge(face[$0], face[($0 + 1) % face.count]) }
            let e = edges.min { ((p[$0.a] + p[$0.b]) * 0.5 - hit.point).length < ((p[$1.a] + p[$1.b]) * 0.5 - hit.point).length }
            return e.map { .edge($0) }
        }
    }
    public func apply(_ op: PrismMeshOp, to mesh: PrismMesh, selection: PrismMeshSelection,
                      mode: PrismSelectMode) throws(PrismEditError) -> (mesh: PrismMesh, selection: PrismMeshSelection) {
        if let why = unavailableHelp(for: op.kind) { throw .outOfRange(why) }
        if case .setSmooth(let on) = op { var m = mesh; m.smooth = on; return (m, selection) }
        guard !selection.isEmpty else { throw .nothingSelected }
        var m = mesh
        let touched = selection.touchedVertices(in: mesh)
        let center = touched.reduce(Vec3.zero) { $0 + (($1 < m.positions.count) ? m.positions[$1] : .zero) } * (1 / Double(Swift.max(1, touched.count)))
        switch op {
        case let .translate(d):
            for v in touched where v < m.positions.count { m.positions[v] = m.positions[v] + d }
            return (m, selection)
        case let .rotate(axis, degrees):
            let q = Quat(axis: axis, degrees: degrees)
            for v in touched where v < m.positions.count { m.positions[v] = center + q.rotate(m.positions[v] - center) }
            return (m, selection)
        case let .scale(s):
            for v in touched where v < m.positions.count {
                let d = m.positions[v] - center
                m.positions[v] = center + Vec3(d.x * s.x, d.y * s.y, d.z * s.z)
            }
            return (m, selection)
        case let .extrude(distance):
            guard mode == .face, !selection.faces.isEmpty else { throw .outOfRange("Extrude works on selected faces.") }
            let normal = selection.faces.reduce(Vec3.zero) { $0 + faceNormal(m, $1) }.normalized ?? Vec3(0, 1, 0)
            var newFaces = Set<Int>()
            for fi in selection.faces.sorted() where fi < m.faces.count {
                let f = m.faces[fi], base = m.positions.count
                m.positions += f.map { m.positions[Int($0)] + normal * distance }
                for i in f.indices {
                    let j = (i + 1) % f.count
                    m.faces.append([f[i], f[j], UInt32(base + j), UInt32(base + i)])
                }
                m.faces[fi] = (0..<f.count).map { UInt32(base + $0) }
                newFaces.insert(fi)
            }
            return (m, PrismMeshSelection(faces: newFaces))
        case let .inset(amount):
            guard mode == .face, !selection.faces.isEmpty else { throw .outOfRange("Inset works on selected faces.") }
            guard amount > 0 else { throw .outOfRange("Inset must be more than 0.") }
            for fi in selection.faces.sorted() where fi < m.faces.count {
                let f = m.faces[fi], base = m.positions.count
                let c = f.reduce(Vec3.zero) { $0 + m.positions[Int($1)] } * (1 / Double(f.count))
                m.positions += f.map { v -> Vec3 in
                    let d = m.positions[Int(v)] - c
                    return c + d * Swift.max(0, 1 - amount / Swift.max(d.length, 1e-9))
                }
                for i in f.indices {
                    let j = (i + 1) % f.count
                    m.faces.append([f[i], f[j], UInt32(base + j), UInt32(base + i)])
                }
                m.faces[fi] = (0..<f.count).map { UInt32(base + $0) }
            }
            return (m, selection)
        case let .loopCut(cuts):
            guard cuts >= 1, cuts <= 64 else { throw .outOfRange("Cuts must be from 1 to 64.") }
            guard let start = selection.edges.sorted().first else { throw .outOfRange("Pick an edge to cut across.") }
            return loopCut(m, through: start, cuts: cuts)
        case .mergeAtCenter:
            guard touched.count >= 2, let keep = touched.min() else { throw .outOfRange("Select two or more vertices to merge.") }
            m.positions[keep] = center
            m.faces = m.faces.map { f in
                var out: [UInt32] = []
                for v in f { let w = touched.contains(Int(v)) ? UInt32(keep) : v; if out.last != w { out.append(w) } }
                if out.count > 1, out.first == out.last { out.removeLast() }
                return out
            }.filter { $0.count >= 3 }
            return (m, PrismMeshSelection(vertices: [keep]))
        case .delete:
            let gone: (Int, [UInt32]) -> Bool = { fi, f in
                switch mode {
                case .face: selection.faces.contains(fi)
                case .edge: f.indices.contains { selection.edges.contains(PrismEdge(Int(f[$0]), Int(f[($0 + 1) % f.count]))) }
                case .vertex: f.contains { selection.vertices.contains(Int($0)) }
                }
            }
            m.faces = m.faces.enumerated().filter { !gone($0.offset, $0.element) }.map(\.element)
            return (m, PrismMeshSelection())
        case .fill:
            let loop = selection.touchedVertices(in: mesh).sorted()
            guard loop.count >= 3 else { throw .outOfRange("Select a boundary of three or more vertices to fill.") }
            m.faces.append(loop.map { UInt32($0) })
            return (m, PrismMeshSelection(faces: [m.faces.count - 1]))
        case .flipNormals:
            for fi in selection.faces where fi < m.faces.count { m.faces[fi].reverse() }
            return (m, selection)
        case .bevel, .setSmooth:
            return (m, selection)
        }
    }
    public func loop(through edge: PrismEdge, in mesh: PrismMesh) -> [PrismEdge] {
        var out = [edge]
        for start in [edge.b, edge.a] {
            var current = edge, at = start
            for _ in 0..<mesh.faces.count {
                guard valence(at, in: mesh) == 4,
                      let next = nextInLoop(after: current, at: at, in: mesh), !out.contains(next) else { break }
                out.append(next)
                at = next.a == at ? next.b : next.a
                current = next
            }
        }
        return out
    }

    private func valence(_ v: Int, in m: PrismMesh) -> Int { m.edges.filter { $0.a == v || $0.b == v }.count }
    private func faceNormal(_ m: PrismMesh, _ fi: Int) -> Vec3 {
        guard fi < m.faces.count, m.faces[fi].count >= 3 else { return .zero }
        let f = m.faces[fi].map { m.positions[Int($0)] }
        return (f[1] - f[0]).cross(f[2] - f[0]).normalized ?? .zero
    }
    private func facesWith(_ e: PrismEdge, in m: PrismMesh) -> Set<Int> {
        Set(m.faces.indices.filter { fi in
            let f = m.faces[fi]
            return f.indices.contains { PrismEdge(Int(f[$0]), Int(f[($0 + 1) % f.count])) == e }
        })
    }
    /// At a valence-4 vertex, the one other edge that shares no face with `e`.
    private func nextInLoop(after e: PrismEdge, at v: Int, in m: PrismMesh) -> PrismEdge? {
        let faces = facesWith(e, in: m)
        return m.edges.first { $0 != e && ($0.a == v || $0.b == v) && facesWith($0, in: m).isDisjoint(with: faces) }
    }
    /// Walks the ring of quads across `start` and splits each into `cuts + 1` strips.
    private func loopCut(_ mesh: PrismMesh, through start: PrismEdge, cuts: Int) -> (mesh: PrismMesh, selection: PrismMeshSelection) {
        var m = mesh, ring: [(face: Int, edge: PrismEdge)] = [], edge = start, visited = Set<Int>()
        while let fi = facesWith(edge, in: m).subtracting(visited).sorted().first, m.faces[fi].count == 4 {
            visited.insert(fi); ring.append((fi, edge))
            let f = m.faces[fi].map(Int.init)
            guard let i = f.indices.first(where: { PrismEdge(f[$0], f[($0 + 1) % 4]) == edge }) else { break }
            edge = PrismEdge(f[(i + 2) % 4], f[(i + 3) % 4])
            if edge == start { break }
        }
        var splits: [PrismEdge: [UInt32]] = [:]
        func points(on e: PrismEdge, from a: Int) -> [UInt32] {
            if let s = splits[e] { return e.a == a ? s : s.reversed() }
            var made: [UInt32] = []
            for k in 1...cuts {
                let t = Double(k) / Double(cuts + 1)
                m.positions.append(m.positions[e.a] + (m.positions[e.b] - m.positions[e.a]) * t)
                made.append(UInt32(m.positions.count - 1))
            }
            splits[e] = made
            return e.a == a ? made : made.reversed()
        }
        var newEdges = Set<PrismEdge>(), replaced: [Int: [[UInt32]]] = [:]
        for (fi, e) in ring {
            let f = m.faces[fi].map(Int.init)
            guard let i = f.indices.first(where: { PrismEdge(f[$0], f[($0 + 1) % 4]) == e }) else { continue }
            let (a, b, c, d) = (f[i], f[(i + 1) % 4], f[(i + 2) % 4], f[(i + 3) % 4])
            let ab = points(on: PrismEdge(a, b), from: a), dc = points(on: PrismEdge(d, c), from: d)
            let left = [UInt32(a)] + ab + [UInt32(b)], right = [UInt32(d)] + dc + [UInt32(c)]
            var strips: [[UInt32]] = []
            for k in 0..<(left.count - 1) {
                strips.append([left[k], left[k + 1], right[k + 1], right[k]])
                if k > 0 { newEdges.insert(PrismEdge(Int(left[k]), Int(right[k]))) }
            }
            replaced[fi] = strips
        }
        var faces: [[UInt32]] = []
        for (fi, f) in m.faces.enumerated() { faces += replaced[fi] ?? [f] }
        m.faces = faces
        return (m, PrismMeshSelection(edges: newEdges))
    }
    /// Möller–Trumbore; nil when the ray misses.
    static func triangle(_ r: PrismRay, _ a: Vec3, _ b: Vec3, _ c: Vec3) -> Double? {
        let e1 = b - a, e2 = c - a, p = r.direction.cross(e2), det = e1.dot(p)
        guard abs(det) > 1e-12 else { return nil }
        let inv = 1 / det, s = r.origin - a, u = s.dot(p) * inv
        guard (0...1).contains(u) else { return nil }
        let q = s.cross(e1), v = r.direction.dot(q) * inv
        guard v >= 0, u + v <= 1 else { return nil }
        let t = e2.dot(q) * inv
        return t > 1e-9 ? t : nil
    }
}

/// A sink that keeps what it is given, for tests and the fake render sheet.
public final class CountingSink: RenderSink, @unchecked Sendable {
    // @unchecked: the tests drive it from one thread; the real sinks live in PrismApp.
    public private(set) var written: [Int] = [], began = false, cancelled = false
    public let failAt: Int?
    public init(failAt: Int? = nil) { self.failAt = failAt }
    public func begin(_ plan: PrismRenderPlan) throws(PrismRenderError) { began = true }
    public func write(_ image: PrismImage, index: Int, plan: PrismRenderPlan) throws(PrismRenderError) {
        if index == failAt { throw .sinkFailed("the disk is full.") }
        written.append(index)
    }
    public func finish(_ plan: PrismRenderPlan) throws(PrismRenderError) -> [String] {
        written.map { plan.fileName(forFrameAt: $0) }
    }
    public func cancel(_ plan: PrismRenderPlan) { cancelled = true }
}

/// Differs: reads only `<rect x= y= width= height= fill="#rrggbb"/>` elements; anything else is a warning.
public struct FakeVectorArtReading: VectorArtReading {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func shapes(fromSVG data: Data) throws(PrismImportError) -> (shapes: [PrismVectorShape], warnings: [String]) {
        let text = String(decoding: data, as: UTF8.self)
        guard text.contains("<svg") else { throw .damaged("it isn't SVG.") }
        var shapes: [PrismVectorShape] = [], warnings: [String] = []
        for element in text.split(separator: "<").dropFirst() {
            let tag = element.prefix { $0 != " " && $0 != ">" && $0 != "/" }
            guard tag != "svg", !tag.isEmpty else { continue }
            guard tag == "rect" else { warnings.append("Skipped a <\(tag)>: the fake reads rectangles only."); continue }
            func attr(_ n: String) -> Double? {
                guard let rest = PrismRules.after(n + "=\"", in: element) else { return nil }
                return Double(rest.prefix { $0 != "\"" })
            }
            guard let x = attr("x"), let y = attr("y"), let w = attr("width"), let h = attr("height"), w > 0, h > 0 else {
                warnings.append("Skipped a rectangle with no size."); continue
            }
            var fill = PrismColor.black
            if let rest = PrismRules.after("fill=\"#", in: element) {
                let hex = rest.prefix(6)
                if hex.count == 6, let v = Int(hex, radix: 16) {
                    fill = PrismColor(Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
                }
            }
            shapes.append(PrismVectorShape(name: "Shape \(shapes.count + 1)",
                                           outline: PrismOutline(contours: [[Vec2(x, -y - h), Vec2(x + w, -y - h), Vec2(x + w, -y), Vec2(x, -y)]]),
                                           fill: fill))
        }
        return (shapes, warnings)
    }
}

/// Differs: reads a test format "RGBA <w> <h>\n" then w × h × 4 bytes; anything else is refused.
public struct FakeImageDecoding: ImageDecoding {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func decode(_ data: Data, name: String, id: PrismID) throws(PrismImportError) -> PrismTexture {
        let bytes = [UInt8](data)
        guard let nl = bytes.firstIndex(of: 10) else { throw .unreadableImage }
        let head = String(decoding: bytes[..<nl], as: UTF8.self).split(separator: " ")
        guard head.count == 3, head[0] == "RGBA", let w = Int(head[1]), let h = Int(head[2]), w > 0, h > 0 else {
            throw .unreadableImage
        }
        let body = Array(bytes[(nl + 1)...])
        guard body.count == w * h * 4 else { throw .damaged("the image is cut short.") }
        return PrismTexture(id: id, name: name, width: w, height: h, rgba8: body)
    }
}

/// Differs: subdivision splits each face at its center and edge midpoints without smoothing
/// (the counts match Catmull-Clark, the positions don't); mirror matches live.
public struct FakeModifierEvaluating: ModifierEvaluating {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func evaluate(_ mesh: PrismMesh, modifiers: [PrismModifier], forRender: Bool) throws(PrismEditError) -> PrismMesh {
        var m = mesh
        for mod in modifiers {
            switch mod {
            case let .mirror(axis, merge):
                let n = m.positions.count
                func flip(_ p: Vec3) -> Vec3 { axis == .x ? Vec3(-p.x, p.y, p.z) : axis == .y ? Vec3(p.x, -p.y, p.z) : Vec3(p.x, p.y, -p.z) }
                func onPlane(_ p: Vec3) -> Bool { abs(axis == .x ? p.x : axis == .y ? p.y : p.z) < 0.001 }
                var map = [UInt32](repeating: 0, count: n)
                var added: [Vec3] = []
                for (i, p) in m.positions.enumerated() {
                    if merge && onPlane(p) { map[i] = UInt32(i) } else { map[i] = UInt32(n + added.count); added.append(flip(p)) }
                }
                m.positions += added
                m.faces += mesh.faces.map { f in f.reversed().map { Int($0) < n ? map[Int($0)] : $0 } }
                m.normals = []; m.uvs = []
            case let .subdivision(levels, renderLevels):
                let count = Swift.max(0, Swift.min(forRender ? 4 : 3, forRender ? renderLevels : levels))
                for _ in 0..<count {
                    let estimate = m.faces.reduce(0) { $0 + $1.count } * 2
                    guard estimate <= PrismImportError.maximumTriangles else {
                        throw .outOfRange("That many levels would pass 5,000,000 triangles.")
                    }
                    m = Self.split(m)
                }
            }
        }
        return m
    }
    static func split(_ mesh: PrismMesh) -> PrismMesh {
        var p = mesh.positions, faces: [[UInt32]] = [], mids: [PrismEdge: UInt32] = [:]
        func mid(_ a: Int, _ b: Int) -> UInt32 {
            let e = PrismEdge(a, b)
            if let i = mids[e] { return i }
            p.append((p[a] + p[b]) * 0.5); mids[e] = UInt32(p.count - 1)
            return UInt32(p.count - 1)
        }
        for f in mesh.faces where f.count >= 3 {
            let c = f.reduce(Vec3.zero) { $0 + p[Int($1)] } * (1 / Double(f.count))
            p.append(c)
            let ci = UInt32(p.count - 1)
            for i in f.indices {
                let prev = Int(f[(i + f.count - 1) % f.count]), cur = Int(f[i]), next = Int(f[(i + 1) % f.count])
                faces.append([UInt32(cur), mid(cur, next), ci, mid(prev, cur)])
            }
        }
        return PrismMesh(id: mesh.id, name: mesh.name, positions: p, faces: faces, smooth: true)
    }
}
