// Values.swift: the values Prism's contracts speak (blueprint part 6.1).
// W0 copies this file into Sources/PrismModel/Contracts/PrismValues.swift.
// Invariants: every type is a Sendable value; angles in the document are
// degrees (what the inspector shows), radians only inside math helpers;
// colors are linear-light RGBA in 0...1 (the glTF 2.0 convention); frames are
// whole numbers from 0; nothing here traps on input (no force unwraps, no
// unchecked indexing, no division by a value that can be zero).
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

// MARK: Math

public struct Vec3: Sendable, Hashable, Codable {
    public var x: Double, y: Double, z: Double
    public init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    public static let zero = Vec3(0, 0, 0)
    public static let one = Vec3(1, 1, 1)
    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static func * (a: Vec3, s: Double) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    public func dot(_ b: Vec3) -> Double { x * b.x + y * b.y + z * b.z }
    public func cross(_ b: Vec3) -> Vec3 { Vec3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x) }
    public var length: Double { dot(self).squareRoot() }
    /// The unit vector, or nil for a zero-length vector.
    public var normalized: Vec3? { length > 1e-12 ? self * (1 / length) : nil }
    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

public struct Vec2: Sendable, Hashable, Codable {
    public var x: Double, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

/// A unit quaternion. Rotation composes as `a * b` = b first, then a.
public struct Quat: Sendable, Hashable, Codable {
    public var x: Double, y: Double, z: Double, w: Double
    public init(x: Double, y: Double, z: Double, w: Double) { self.x = x; self.y = y; self.z = z; self.w = w }
    public static let identity = Quat(x: 0, y: 0, z: 0, w: 1)
    public init(axis: Vec3, degrees: Double) {
        let a = (axis.normalized ?? Vec3(0, 0, 1)), h = degrees * .pi / 360
        let s = sin(h)
        self.init(x: a.x * s, y: a.y * s, z: a.z * s, w: cos(h))
    }
    /// Euler angles in degrees, applied X, then Y, then Z (the inspector's order).
    public init(eulerDegrees e: Vec3) {
        self = Quat(axis: Vec3(0, 0, 1), degrees: e.z) * Quat(axis: Vec3(0, 1, 0), degrees: e.y)
            * Quat(axis: Vec3(1, 0, 0), degrees: e.x)
    }
    public static func * (a: Quat, b: Quat) -> Quat {
        Quat(x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
             y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
             z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
             w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)
    }
    public func rotate(_ v: Vec3) -> Vec3 {
        let u = Vec3(x, y, z), t = u.cross(v) * 2
        return v + t * w + u.cross(t)
    }
}

/// A 4 × 4 matrix, column-major (`m[column * 4 + row]`), acting on column vectors.
public struct Mat4: Sendable, Hashable, Codable {
    public var m: [Double]
    public init(_ m: [Double]) { self.m = m.count == 16 ? m : Mat4.identity.m }
    public static let identity = Mat4(storage: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
    private init(storage: [Double]) { m = storage }
    public subscript(row: Int, column: Int) -> Double {
        let i = column * 4 + row
        return (0..<16).contains(i) && i < m.count ? m[i] : 0
    }
    public static func * (a: Mat4, b: Mat4) -> Mat4 {
        var r = [Double](repeating: 0, count: 16)
        for c in 0..<4 { for row in 0..<4 {
            var s = 0.0
            for k in 0..<4 { s += a[row, k] * b[k, c] }
            r[c * 4 + row] = s
        } }
        return Mat4(r)
    }
    public static func translation(_ t: Vec3) -> Mat4 { Mat4([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, t.x, t.y, t.z, 1]) }
    public static func scale(_ s: Vec3) -> Mat4 { Mat4([s.x, 0, 0, 0, 0, s.y, 0, 0, 0, 0, s.z, 0, 0, 0, 0, 1]) }
    public static func rotation(_ q: Quat) -> Mat4 {
        let a = q.rotate(Vec3(1, 0, 0)), b = q.rotate(Vec3(0, 1, 0)), c = q.rotate(Vec3(0, 0, 1))
        return Mat4([a.x, a.y, a.z, 0, b.x, b.y, b.z, 0, c.x, c.y, c.z, 0, 0, 0, 0, 1])
    }
    public func transformPoint(_ p: Vec3) -> Vec3 {
        Vec3(self[0, 0] * p.x + self[0, 1] * p.y + self[0, 2] * p.z + self[0, 3],
             self[1, 0] * p.x + self[1, 1] * p.y + self[1, 2] * p.z + self[1, 3],
             self[2, 0] * p.x + self[2, 1] * p.y + self[2, 2] * p.z + self[2, 3])
    }
    public func transformDirection(_ d: Vec3) -> Vec3 {
        Vec3(self[0, 0] * d.x + self[0, 1] * d.y + self[0, 2] * d.z,
             self[1, 0] * d.x + self[1, 1] * d.y + self[1, 2] * d.z,
             self[2, 0] * d.x + self[2, 1] * d.y + self[2, 2] * d.z)
    }
    /// The inverse of an affine matrix (last row 0 0 0 1), or nil when singular.
    public var affineInverse: Mat4? {
        let a = self[0, 0], b = self[0, 1], c = self[0, 2], d = self[1, 0], e = self[1, 1], f = self[1, 2]
        let g = self[2, 0], h = self[2, 1], i = self[2, 2]
        let det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        guard abs(det) > 1e-12 else { return nil }
        let r = 1 / det
        let inv: [Double] = [(e * i - f * h) * r, -(d * i - f * g) * r, (d * h - e * g) * r, 0,
                             -(b * i - c * h) * r, (a * i - c * g) * r, -(a * h - b * g) * r, 0,
                             (b * f - c * e) * r, -(a * f - c * d) * r, (a * e - b * d) * r, 0, 0, 0, 0, 1]
        let rot = Mat4(inv), t = rot.transformPoint(Vec3(self[0, 3], self[1, 3], self[2, 3]))
        var out = rot.m
        out[12] = -t.x; out[13] = -t.y; out[14] = -t.z
        return Mat4(out)
    }
}

/// Bounds in some space; `empty` has min > max.
public struct Box3: Sendable, Hashable, Codable {
    public var min: Vec3, max: Vec3
    public init(min: Vec3, max: Vec3) { self.min = min; self.max = max }
    public static let empty = Box3(min: Vec3(1, 1, 1), max: Vec3(-1, -1, -1))
    public var isEmpty: Bool { min.x > max.x || min.y > max.y || min.z > max.z }
    public var center: Vec3 { (min + max) * 0.5 }
    public var size: Vec3 { isEmpty ? .zero : max - min }
    public func union(_ p: Vec3) -> Box3 {
        isEmpty ? Box3(min: p, max: p)
            : Box3(min: Vec3(Swift.min(min.x, p.x), Swift.min(min.y, p.y), Swift.min(min.z, p.z)),
                   max: Vec3(Swift.max(max.x, p.x), Swift.max(max.y, p.y), Swift.max(max.z, p.z)))
    }
    public func union(_ b: Box3) -> Box3 { b.isEmpty ? self : union(b.min).union(b.max) }
    public func transformed(by t: Mat4) -> Box3 {
        guard !isEmpty else { return self }
        var out = Box3.empty
        for i in 0..<8 {
            out = out.union(t.transformPoint(Vec3(i & 1 == 0 ? min.x : max.x, i & 2 == 0 ? min.y : max.y,
                                                  i & 4 == 0 ? min.z : max.z)))
        }
        return out
    }
}

public struct PrismRay: Sendable, Hashable {
    public var origin: Vec3, direction: Vec3
    public init(origin: Vec3, direction: Vec3) { self.origin = origin; self.direction = direction }
}

// MARK: Scene

public struct PrismID: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {
    public var raw: String
    public init(_ raw: String) { self.raw = raw }
    public static func < (a: PrismID, b: PrismID) -> Bool { a.raw < b.raw }
    public var description: String { raw }
}

/// Linear-light RGBA, each channel 0...1.
public struct PrismColor: Sendable, Hashable, Codable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        func c(_ v: Double) -> Double { v.isFinite ? Swift.min(1, Swift.max(0, v)) : 0 }
        self.r = c(r); self.g = c(g); self.b = c(b); self.a = c(a)
    }
    public static let white = PrismColor(1, 1, 1), black = PrismColor(0, 0, 0)
}

/// Position, Euler rotation in degrees (X then Y then Z) and scale, relative to the parent.
public struct PrismTransform: Sendable, Hashable, Codable {
    public var position: Vec3, rotation: Vec3, scale: Vec3
    public init(position: Vec3 = .zero, rotation: Vec3 = .zero, scale: Vec3 = .one) {
        self.position = position; self.rotation = rotation; self.scale = scale
    }
    public static let identity = PrismTransform()
    public var matrix: Mat4 { .translation(position) * .rotation(Quat(eulerDegrees: rotation)) * .scale(scale) }
}

/// A polygon mesh: every face is a list of 3 or more vertex indices, counter-clockwise seen from
/// outside. `normals` and `uvs` are empty or the same count as positions. Imported meshes are
/// triangles; modeling makes quads and n-gons. Renderers read `triangles`.
public struct PrismMesh: Sendable, Hashable, Codable, Identifiable {
    public var id: PrismID, name: String
    public var positions: [Vec3], normals: [Vec3], uvs: [Vec2], faces: [[UInt32]]
    /// Smooth shading averages normals across faces; flat shading uses each face's normal.
    public var smooth: Bool
    public init(id: PrismID, name: String, positions: [Vec3], normals: [Vec3] = [], uvs: [Vec2] = [],
                faces: [[UInt32]], smooth: Bool = false) {
        self.id = id; self.name = name; self.positions = positions; self.normals = normals; self.uvs = uvs
        self.faces = faces; self.smooth = smooth
    }
    /// Fan triangulation, exact for convex faces. Core replaces it with ear clipping for
    /// concave n-gons (part 4, core issue C3D-2); the contract tests use convex faces only.
    public var triangles: [UInt32] {
        faces.flatMap { f -> [UInt32] in
            guard f.count >= 3, let a = f.first else { return [] }
            return (1..<(f.count - 1)).flatMap { [a, f[$0], f[$0 + 1]] }
        }
    }
    public var triangleCount: Int { faces.reduce(0) { $0 + Swift.max(0, $1.count - 2) } }
    public var bounds: Box3 { positions.reduce(Box3.empty) { $0.union($1) } }
    /// Unique undirected edges, sorted.
    public var edges: [PrismEdge] {
        var set = Set<PrismEdge>()
        for f in faces where f.count >= 2 {
            for (i, a) in f.enumerated() { set.insert(PrismEdge(Int(a), Int(f[(i + 1) % f.count]))) }
        }
        return set.sorted()
    }
    /// Nil when valid, else the reason (used by importers and file decode).
    public var problem: String? {
        if faces.contains(where: { $0.count < 3 }) { return "\(name) has a face with fewer than 3 corners." }
        if faces.contains(where: { $0.contains { Int($0) >= positions.count } }) {
            return "\(name) points at a vertex it doesn't have."
        }
        if !normals.isEmpty && normals.count != positions.count { return "\(name) has the wrong number of normals." }
        if !uvs.isEmpty && uvs.count != positions.count { return "\(name) has the wrong number of texture coordinates." }
        if positions.contains(where: { !$0.isFinite }) { return "\(name) has a vertex that isn't a number." }
        return nil
    }
}

/// An undirected edge, stored low index first.
public struct PrismEdge: Sendable, Hashable, Codable, Comparable {
    public var a: Int, b: Int
    public init(_ a: Int, _ b: Int) { self.a = Swift.min(a, b); self.b = Swift.max(a, b) }
    public static func < (l: PrismEdge, r: PrismEdge) -> Bool { (l.a, l.b) < (r.a, r.b) }
}

// MARK: Modeling

public enum PrismSelectMode: String, Sendable, Hashable, Codable, CaseIterable { case vertex, edge, face }

/// What is selected inside one mesh in edit mode.
public struct PrismMeshSelection: Sendable, Hashable, Codable {
    public var vertices: Set<Int>, edges: Set<PrismEdge>, faces: Set<Int>
    public init(vertices: Set<Int> = [], edges: Set<PrismEdge> = [], faces: Set<Int> = []) {
        self.vertices = vertices; self.edges = edges; self.faces = faces
    }
    public var isEmpty: Bool { vertices.isEmpty && edges.isEmpty && faces.isEmpty }
    /// Every vertex the selection touches, whatever the mode.
    public func touchedVertices(in mesh: PrismMesh) -> Set<Int> {
        var out = vertices
        for e in edges { out.insert(e.a); out.insert(e.b) }
        for f in faces where f < mesh.faces.count { for v in mesh.faces[f] { out.insert(Int(v)) } }
        return out
    }
}

public enum PrismMeshElement: Sendable, Hashable { case vertex(Int), edge(PrismEdge), face(Int) }

/// The tier-1 modeling operations (part 3, P-F8). Amounts are in the mesh's own units.
public enum PrismMeshOp: Sendable, Hashable {
    case translate(Vec3)
    case rotate(axis: Vec3, degrees: Double)
    case scale(Vec3)
    /// Extrude the selected faces along their average normal.
    case extrude(distance: Double)
    /// Inset each selected face by `amount`, adding a ring of faces.
    case inset(amount: Double)
    /// Bevel the selected edges with `segments` faces across `width`.
    case bevel(width: Double, segments: Int)
    /// Cut `cuts` new edge loops across the ring of faces through the selected edge.
    case loopCut(cuts: Int)
    /// Merge the selected vertices at their center.
    case mergeAtCenter
    /// Delete the selected faces (face mode), edges or vertices with the faces that use them.
    case delete
    /// Fill the selected boundary loop with one face.
    case fill
    case flipNormals
    case setSmooth(Bool)

    public var kind: PrismMeshOpKind {
        switch self {
        case .translate: .translate
        case .rotate: .rotate
        case .scale: .scale
        case .extrude: .extrude
        case .inset: .inset
        case .bevel: .bevel
        case .loopCut: .loopCut
        case .mergeAtCenter: .mergeAtCenter
        case .delete: .delete
        case .fill: .fill
        case .flipNormals: .flipNormals
        case .setSmooth: .setSmooth
        }
    }
}

public enum PrismMeshOpKind: String, Sendable, Hashable, Codable, CaseIterable {
    case translate, rotate, scale, extrude, inset, bevel, loopCut, mergeAtCenter, delete, fill, flipNormals, setSmooth
    /// The Undo menu name of the step.
    public var title: String {
        switch self {
        case .translate: "Move"
        case .rotate: "Rotate"
        case .scale: "Scale"
        case .extrude: "Extrude"
        case .inset: "Inset"
        case .bevel: "Bevel"
        case .loopCut: "Loop Cut"
        case .mergeAtCenter: "Merge"
        case .delete: "Delete"
        case .fill: "Fill"
        case .flipNormals: "Flip Normals"
        case .setSmooth: "Shade Smooth"
        }
    }
}

/// An image a material samples. Pixels are 8-bit RGBA, sRGB-encoded, row-major from the top.
public struct PrismTexture: Sendable, Hashable, Codable, Identifiable {
    public var id: PrismID, name: String, width: Int, height: Int, rgba8: [UInt8]
    public init(id: PrismID, name: String, width: Int, height: Int, rgba8: [UInt8]) {
        self.id = id; self.name = name; self.width = width; self.height = height; self.rgba8 = rgba8
    }
    public var isValid: Bool { width > 0 && height > 0 && rgba8.count == width * height * 4 }
}

/// The glTF 2.0 metallic-roughness material, the one material model in v1.
public struct PrismMaterial: Sendable, Hashable, Codable, Identifiable {
    public var id: PrismID, name: String
    public var baseColor: PrismColor, metallic: Double, roughness: Double
    public var emissive: PrismColor, emissiveStrength: Double
    public var baseColorTexture: PrismID?
    public var doubleSided: Bool
    public init(id: PrismID, name: String, baseColor: PrismColor = PrismColor(0.8, 0.8, 0.8), metallic: Double = 0,
                roughness: Double = 0.5, emissive: PrismColor = .black, emissiveStrength: Double = 0,
                baseColorTexture: PrismID? = nil, doubleSided: Bool = false) {
        self.id = id; self.name = name; self.baseColor = baseColor; self.metallic = metallic; self.roughness = roughness
        self.emissive = emissive; self.emissiveStrength = emissiveStrength; self.baseColorTexture = baseColorTexture
        self.doubleSided = doubleSided
    }
}

public enum PrismLightKind: String, Sendable, Hashable, Codable, CaseIterable { case directional, point, spot, area }

/// Intensity is in the glTF punctual-light units: lux for directional, candela for point and spot;
/// an area light is a one-sided rectangle `width` × `height` in nits.
public struct PrismLight: Sendable, Hashable, Codable {
    public var kind: PrismLightKind, color: PrismColor, intensity: Double
    public var range: Double?, innerConeDegrees: Double, outerConeDegrees: Double
    public var width: Double, height: Double, castsShadows: Bool
    public init(kind: PrismLightKind, color: PrismColor = .white, intensity: Double, range: Double? = nil,
                innerConeDegrees: Double = 0, outerConeDegrees: Double = 45, width: Double = 1, height: Double = 1,
                castsShadows: Bool = true) {
        self.kind = kind; self.color = color; self.intensity = intensity; self.range = range
        self.innerConeDegrees = innerConeDegrees; self.outerConeDegrees = outerConeDegrees
        self.width = width; self.height = height; self.castsShadows = castsShadows
    }
}

public enum PrismProjection: Sendable, Hashable, Codable {
    /// Vertical field of view in degrees, 1...179.
    case perspective(fieldOfViewDegrees: Double)
    /// Height of the view in scene units.
    case orthographic(height: Double)
}

public struct PrismCamera: Sendable, Hashable, Codable {
    public var projection: PrismProjection, near: Double, far: Double
    public init(projection: PrismProjection = .perspective(fieldOfViewDegrees: 40), near: Double = 0.05, far: Double = 1000) {
        self.projection = projection; self.near = near; self.far = far
    }
}

public enum PrismNodeKind: String, Sendable, Hashable, Codable, CaseIterable { case group, mesh, light, camera }

public struct PrismNode: Sendable, Hashable, Codable, Identifiable {
    public var id: PrismID, name: String, kind: PrismNodeKind
    public var transform: PrismTransform, parentID: PrismID?, isVisible: Bool
    public var meshID: PrismID?, materialID: PrismID?, light: PrismLight?, camera: PrismCamera?
    /// Keyframe tracks by `PrismProperty.rawValue`, each sorted by frame with one key per frame.
    public var tracks: [String: [PrismKey]]
    /// Applied in order to the mesh before drawing, rendering and export (P-F21).
    public var modifiers: [PrismModifier]
    /// Text or vector art the mesh is rebuilt from (P-F19, P-F20); nil once converted to a mesh.
    public var shapeSource: PrismShapeSource?
    public init(id: PrismID, name: String, kind: PrismNodeKind, transform: PrismTransform = .identity,
                parentID: PrismID? = nil, isVisible: Bool = true, meshID: PrismID? = nil, materialID: PrismID? = nil,
                light: PrismLight? = nil, camera: PrismCamera? = nil, tracks: [String: [PrismKey]] = [:],
                modifiers: [PrismModifier] = [], shapeSource: PrismShapeSource? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.transform = transform; self.parentID = parentID
        self.isVisible = isVisible; self.meshID = meshID; self.materialID = materialID; self.light = light
        self.camera = camera; self.tracks = tracks; self.modifiers = modifiers; self.shapeSource = shapeSource
    }
}

public struct PrismEnvironment: Sendable, Hashable, Codable {
    /// Flat background and ambient color, or an equirectangular image when `imageID` is set.
    public var color: PrismColor, intensity: Double, imageID: PrismID?, rotationDegrees: Double
    /// When true the background renders transparent (alpha 0) and only lights the scene.
    public var transparentBackground: Bool
    public init(color: PrismColor = PrismColor(0.05, 0.05, 0.06), intensity: Double = 1, imageID: PrismID? = nil,
                rotationDegrees: Double = 0, transparentBackground: Bool = false) {
        self.color = color; self.intensity = intensity; self.imageID = imageID; self.rotationDegrees = rotationDegrees
        self.transparentBackground = transparentBackground
    }
}

/// Output size and time: what Render and the hand-offs write.
public struct PrismSceneSettings: Sendable, Hashable, Codable {
    public var width: Int, height: Int, framesPerSecond: Int, durationFrames: Int
    public init(width: Int = 1920, height: Int = 1080, framesPerSecond: Int = 30, durationFrames: Int = 90) {
        self.width = width; self.height = height; self.framesPerSecond = framesPerSecond; self.durationFrames = durationFrames
    }
    public static let rates = [24, 25, 30, 60]
    public var lastFrame: Int { Swift.max(0, durationFrames - 1) }
    public var aspect: Double { height > 0 ? Double(width) / Double(height) : 1 }
}

/// The document. `nodes` is in outliner order (parents before their children).
public struct PrismScene: Sendable, Hashable, Codable {
    public var nodes: [PrismNode], meshes: [PrismMesh], materials: [PrismMaterial], textures: [PrismTexture]
    public var environment: PrismEnvironment, activeCameraID: PrismID?, settings: PrismSceneSettings
    public init(nodes: [PrismNode] = [], meshes: [PrismMesh] = [], materials: [PrismMaterial] = [],
                textures: [PrismTexture] = [], environment: PrismEnvironment = PrismEnvironment(),
                activeCameraID: PrismID? = nil, settings: PrismSceneSettings = PrismSceneSettings()) {
        self.nodes = nodes; self.meshes = meshes; self.materials = materials; self.textures = textures
        self.environment = environment; self.activeCameraID = activeCameraID; self.settings = settings
    }
    public func node(_ id: PrismID) -> PrismNode? { nodes.first { $0.id == id } }
    public func mesh(_ id: PrismID?) -> PrismMesh? { id.flatMap { i in meshes.first { $0.id == i } } }
    public func material(_ id: PrismID?) -> PrismMaterial? { id.flatMap { i in materials.first { $0.id == i } } }
    public func children(of id: PrismID?) -> [PrismNode] { nodes.filter { $0.parentID == id } }
    public var triangleCount: Int {
        nodes.reduce(0) { $0 + (mesh($1.meshID)?.triangleCount ?? 0) }
    }
}

/// What the window holds: the scene, the selection and the id counter.
public struct PrismDocumentState: Sendable, Hashable, Codable {
    public var scene: PrismScene, selection: [PrismID], nextID: Int
    public init(scene: PrismScene = PrismScene(), selection: [PrismID] = [], nextID: Int = 1) {
        self.scene = scene; self.selection = selection; self.nextID = nextID
    }
    /// A fresh id with the given prefix ("node", "mesh", "mat", "tex"); bumps the counter.
    public mutating func takeID(_ prefix: String) -> PrismID {
        defer { nextID += 1 }
        return PrismID("\(prefix)-\(nextID)")
    }
}

// MARK: Keys and easing

public enum PrismEasing: Sendable, Hashable, Codable {
    case linear, easeIn, easeOut, easeInOut, hold
    /// The CSS cubic-bezier(x1, y1, x2, y2) form; x1 and x2 in 0...1.
    case cubic(Double, Double, Double, Double)
    public static let presets: [PrismEasing] = [.linear, .easeIn, .easeOut, .easeInOut, .hold]
    public var title: String {
        switch self {
        case .linear: "Linear"
        case .easeIn: "Ease In"
        case .easeOut: "Ease Out"
        case .easeInOut: "Ease In and Out"
        case .hold: "Hold"
        case .cubic: "Custom"
        }
    }
    /// Control points of the curve per W3C CSS Easing Level 1; nil for hold.
    public var controlPoints: (Double, Double, Double, Double)? {
        switch self {
        case .linear: (0, 0, 1, 1)
        case .easeIn: (0.42, 0, 1, 1)
        case .easeOut: (0, 0, 0.58, 1)
        case .easeInOut: (0.42, 0, 0.58, 1)
        case .hold: nil
        case let .cubic(a, b, c, d): (Swift.min(1, Swift.max(0, a)), b, Swift.min(1, Swift.max(0, c)), d)
        }
    }
    /// Progress 0...1 at time fraction t in 0...1.
    public func value(at t: Double) -> Double {
        let t = Swift.min(1, Swift.max(0, t.isFinite ? t : 0))
        guard let (x1, y1, x2, y2) = controlPoints else { return t < 1 ? 0 : 1 }
        func bez(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
            let u = 1 - s
            return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s
        }
        var lo = 0.0, hi = 1.0
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            if bez(mid, x1, x2) < t { lo = mid } else { hi = mid }
        }
        return bez((lo + hi) / 2, y1, y2)
    }
}

/// One key: the value at a frame and the easing toward the next key.
public struct PrismKey: Sendable, Hashable, Codable {
    public var frame: Int, value: Double, easing: PrismEasing
    public init(frame: Int, value: Double, easing: PrismEasing = .linear) {
        self.frame = frame; self.value = value; self.easing = easing
    }
}

public enum PrismProperty: String, Sendable, Hashable, Codable, CaseIterable {
    case positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ
    case lightIntensity, cameraFieldOfView
    public var title: String {
        switch self {
        case .positionX: "Position X"
        case .positionY: "Position Y"
        case .positionZ: "Position Z"
        case .rotationX: "Rotation X"
        case .rotationY: "Rotation Y"
        case .rotationZ: "Rotation Z"
        case .scaleX: "Scale X"
        case .scaleY: "Scale Y"
        case .scaleZ: "Scale Z"
        case .lightIntensity: "Intensity"
        case .cameraFieldOfView: "Field of View"
        }
    }
    /// Which node kinds carry it.
    public func applies(to kind: PrismNodeKind) -> Bool {
        switch self {
        case .lightIntensity: kind == .light
        case .cameraFieldOfView: kind == .camera
        default: true
        }
    }
    /// Parses typed text such as "45", "45°", "-1.5 m"; nil when it isn't a finite number.
    public static func parse(_ text: String) -> Double? {
        let kept = text.filter { "0123456789.-+eE".contains($0) }
        guard let v = Double(kept), v.isFinite else { return nil }
        return v
    }
}

/// A key on a node's track, for selection and easing.
public struct PrismKeyRef: Sendable, Hashable, Codable {
    public var node: PrismID, property: PrismProperty, frame: Int
    public init(node: PrismID, property: PrismProperty, frame: Int) { self.node = node; self.property = property; self.frame = frame }
}

// MARK: Viewport

/// The free view a person orbits in the viewport (not a scene camera).
public struct PrismViewCamera: Sendable, Hashable, Codable {
    /// The point orbited around, the distance to it, and the orbit angles in degrees.
    public var target: Vec3, distance: Double, yawDegrees: Double, pitchDegrees: Double
    public var fieldOfViewDegrees: Double, isOrthographic: Bool
    public init(target: Vec3 = .zero, distance: Double = 6, yawDegrees: Double = 35, pitchDegrees: Double = -25,
                fieldOfViewDegrees: Double = 40, isOrthographic: Bool = false) {
        self.target = target; self.distance = distance; self.yawDegrees = yawDegrees; self.pitchDegrees = pitchDegrees
        self.fieldOfViewDegrees = fieldOfViewDegrees; self.isOrthographic = isOrthographic
    }
    public static let minimumDistance = 0.01, maximumDistance = 100_000.0
    /// The eye position in world space.
    public var eye: Vec3 {
        let q = Quat(axis: Vec3(0, 1, 0), degrees: yawDegrees) * Quat(axis: Vec3(1, 0, 0), degrees: pitchDegrees)
        return target + q.rotate(Vec3(0, 0, distance))
    }
}

public enum PrismViewPreset: String, Sendable, Hashable, Codable, CaseIterable { case front, back, left, right, top, bottom, perspective }

/// Where the viewport looks from: the free view, or through a scene camera.
public enum PrismViewpoint: Sendable, Hashable, Codable {
    case free(PrismViewCamera)
    case camera(PrismID)
}

/// A point in the viewport, normalized: (0, 0) top-left, (1, 1) bottom-right.
public struct ViewPoint: Sendable, Hashable {
    public var x: Double, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

public struct PrismHit: Sendable, Hashable {
    public var node: PrismID, distance: Double, point: Vec3
    public init(node: PrismID, distance: Double, point: Vec3) { self.node = node; self.distance = distance; self.point = point }
}

public enum PrismGizmoMode: String, Sendable, Hashable, Codable, CaseIterable { case move, rotate, scale }
public enum PrismAxis: String, Sendable, Hashable, Codable, CaseIterable { case x, y, z }

public enum PrismGizmoHandle: Sendable, Hashable {
    case axis(PrismAxis)
    /// The plane whose normal is the axis.
    case plane(PrismAxis)
    /// Move or rotate in the view plane, or scale uniformly.
    case screen
}

public struct PrismGizmoDrag: Sendable, Hashable {
    public var node: PrismID, mode: PrismGizmoMode, handle: PrismGizmoHandle
    public var start: ViewPoint, startTransform: PrismTransform, startWorldPoint: Vec3
    public init(node: PrismID, mode: PrismGizmoMode, handle: PrismGizmoHandle, start: ViewPoint,
                startTransform: PrismTransform, startWorldPoint: Vec3) {
        self.node = node; self.mode = mode; self.handle = handle; self.start = start
        self.startTransform = startTransform; self.startWorldPoint = startWorldPoint
    }
}

/// Grid snapping for gizmo drags: move in units, rotate in degrees, scale in factor steps; 0 is off.
public struct PrismSnap: Sendable, Hashable, Codable {
    public var move: Double, rotateDegrees: Double, scale: Double
    public init(move: Double = 0, rotateDegrees: Double = 0, scale: Double = 0) {
        self.move = move; self.rotateDegrees = rotateDegrees; self.scale = scale
    }
    public static let off = PrismSnap(), standard = PrismSnap(move: 0.25, rotateDegrees: 15, scale: 0.1)
}

// MARK: Drawing and rendering

/// One mesh to draw, resolved at a frame: everything a renderer needs, no lookups.
public struct PrismDrawItem: Sendable, Hashable {
    public var node: PrismID, mesh: PrismID, world: Mat4, material: PrismMaterial, isSelected: Bool
    public init(node: PrismID, mesh: PrismID, world: Mat4, material: PrismMaterial, isSelected: Bool) {
        self.node = node; self.mesh = mesh; self.world = world; self.material = material; self.isSelected = isSelected
    }
}

public struct PrismDrawLight: Sendable, Hashable {
    public var light: PrismLight, position: Vec3, direction: Vec3
    public init(light: PrismLight, position: Vec3, direction: Vec3) {
        self.light = light; self.position = position; self.direction = direction
    }
}

/// A frame as a renderer sees it. The viewport (Metal) and the reference renderer read the same list.
public struct PrismDrawList: Sendable, Hashable {
    public var frame: Int, items: [PrismDrawItem], lights: [PrismDrawLight]
    public var view: Mat4, eye: Vec3, projection: PrismProjection, near: Double, far: Double, aspect: Double
    public var environment: PrismEnvironment
    public init(frame: Int, items: [PrismDrawItem], lights: [PrismDrawLight], view: Mat4, eye: Vec3,
                projection: PrismProjection, near: Double, far: Double, aspect: Double, environment: PrismEnvironment) {
        self.frame = frame; self.items = items; self.lights = lights; self.view = view; self.eye = eye
        self.projection = projection; self.near = near; self.far = far; self.aspect = aspect; self.environment = environment
    }
}

public enum PrismRenderQuality: String, Sendable, Hashable, Codable, CaseIterable {
    /// Viewport shading: direct lights, no shadows, 1 sample.
    case preview
    /// Final: direct lights with shadows, environment light, 8 samples per pixel.
    case final
}

/// Rendered pixels: linear-light premultiplied RGBA floats, row-major from the top.
public struct PrismImage: Sendable, Hashable {
    public var width: Int, height: Int, rgba: [Float]
    public init(width: Int, height: Int, rgba: [Float]) { self.width = width; self.height = height; self.rgba = rgba }
    public var isValid: Bool { width > 0 && height > 0 && rgba.count == width * height * 4 }
    public func pixel(x: Int, y: Int) -> (Float, Float, Float, Float)? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        let i = (y * width + x) * 4
        guard i + 3 < rgba.count else { return nil }
        return (rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3])
    }
}

public enum PrismRenderFormat: String, Sendable, Hashable, Codable, CaseIterable {
    /// One PNG per frame with alpha: Halo's and Flare's footage format.
    case pngSequence
    /// A ProRes 4444 movie with alpha.
    case movieWithAlpha
    /// An H.264 movie, no alpha.
    case movie
    /// One PNG at the playhead.
    case still
}

public struct PrismRenderPlan: Sendable, Hashable, Codable {
    public var format: PrismRenderFormat, frames: ClosedRange<Int>, width: Int, height: Int
    public var quality: PrismRenderQuality, baseName: String, transparentBackground: Bool
    public init(format: PrismRenderFormat, frames: ClosedRange<Int>, width: Int, height: Int,
                quality: PrismRenderQuality, baseName: String, transparentBackground: Bool) {
        self.format = format; self.frames = frames; self.width = width; self.height = height; self.quality = quality
        self.baseName = baseName; self.transparentBackground = transparentBackground
    }
    /// "Bounce_0001.png" for frame index 0 of the plan.
    public func fileName(forFrameAt index: Int) -> String {
        let n = String(index + 1)
        return baseName + "_" + String(repeating: "0", count: Swift.max(0, 4 - n.count)) + n + ".png"
    }
}

public enum PrismRenderOutcome: Sendable, Hashable {
    case finished(files: [String], frames: Int)
    case cancelled(atFrame: Int)
    case failed(frame: Int, message: String)
}

// MARK: Files, import, export, shapes, hand-offs

public enum PrismImportFormat: String, Sendable, Hashable, Codable, CaseIterable {
    case glb, gltf, obj, stl, ply, usdz, usd, usda, usdc
    public init?(fileExtension: String) { self.init(rawValue: fileExtension.lowercased()) }
    /// Formats read by pure Swift in creative-core (Linux-tested); the rest by the macOS importer.
    public var isCore: Bool { [.glb, .gltf, .obj, .stl, .ply].contains(self) }
}

public enum PrismExportFormat: String, Sendable, Hashable, Codable, CaseIterable {
    case glb, usdz, obj, stl
    public var isCore: Bool { self != .usdz }
}

/// What an import brings in, before it joins the scene: ids are local to the result.
public struct PrismImportResult: Sendable, Hashable {
    public var nodes: [PrismNode], meshes: [PrismMesh], materials: [PrismMaterial], textures: [PrismTexture]
    /// Things it skipped, each a sentence ("Skipped 2 skinned meshes: skinning isn't supported yet.").
    public var warnings: [String]
    public init(nodes: [PrismNode], meshes: [PrismMesh], materials: [PrismMaterial], textures: [PrismTexture],
                warnings: [String]) {
        self.nodes = nodes; self.meshes = meshes; self.materials = materials; self.textures = textures
        self.warnings = warnings
    }
}

/// A .prism package: the scene JSON plus one binary file per mesh and texture.
public struct PrismFilePackage: Sendable, Hashable {
    public var document: Data, buffers: [String: Data]
    public init(document: Data, buffers: [String: Data]) { self.document = document; self.buffers = buffers }
    public static let formatName = "prism", version = 1, maximumBytes = 512 * 1024 * 1024
}

public enum PrismPrimitive: String, Sendable, Hashable, Codable, CaseIterable {
    case cube, sphere, cylinder, cone, plane, torus
    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// A flat shape to extrude: closed contours in the XY plane, outer contours
/// counter-clockwise and holes clockwise (the SVG nonzero rule after flattening).
public struct PrismOutline: Sendable, Hashable, Codable {
    public var contours: [[Vec2]]
    public init(contours: [[Vec2]]) { self.contours = contours }
    public var isEmpty: Bool { contours.allSatisfy { $0.count < 3 } }
}

public struct PrismExtrusion: Sendable, Hashable, Codable {
    public var depth: Double, bevel: Double, bevelSegments: Int
    public init(depth: Double = 0.2, bevel: Double = 0.02, bevelSegments: Int = 2) {
        self.depth = depth; self.bevel = bevel; self.bevelSegments = bevelSegments
    }
}

public enum PrismModifier: Sendable, Hashable, Codable {
    /// Catmull-Clark subdivision: `levels` in the viewport (0...3), `renderLevels` in renders and export (0...4).
    case subdivision(levels: Int, renderLevels: Int)
    /// Mirror across the object's own axis; `merge` welds vertices within 0.001 of the plane.
    case mirror(axis: PrismAxis, merge: Bool)
    public var title: String {
        switch self {
        case .subdivision: "Subdivision Surface"
        case .mirror: "Mirror"
        }
    }
}

public enum PrismShapeSource: Sendable, Hashable, Codable {
    case text(string: String, fontName: String, size: Double, extrusion: PrismExtrusion)
    case vector(outline: PrismOutline, extrusion: PrismExtrusion)
}

/// One filled shape read from vector art, ready to extrude.
public struct PrismVectorShape: Sendable, Hashable, Codable {
    public var name: String, outline: PrismOutline, fill: PrismColor
    public init(name: String, outline: PrismOutline, fill: PrismColor) { self.name = name; self.outline = outline; self.fill = fill }
}

/// Where a render goes after it is written.
public enum PrismHandOffTarget: String, Sendable, Hashable, Codable, CaseIterable {
    case halo, flare, design
    public var title: String {
        switch self {
        case .halo: "Halo"
        case .flare: "Flare"
        case .design: "Design"
        }
    }
}

/// The request the suite transport carries (suite.md 2.6); Prism only builds it.
public struct PrismHandOffRequest: Sendable, Hashable, Codable {
    public var target: PrismHandOffTarget, files: [String], framesPerSecond: Int, width: Int, height: Int
    public var hasAlpha: Bool, sourceDocument: String?
    public init(target: PrismHandOffTarget, files: [String], framesPerSecond: Int, width: Int, height: Int,
                hasAlpha: Bool, sourceDocument: String?) {
        self.target = target; self.files = files; self.framesPerSecond = framesPerSecond; self.width = width
        self.height = height; self.hasAlpha = hasAlpha; self.sourceDocument = sourceDocument
    }
}

// MARK: Errors (each `message` is the sentence the UI shows)

public enum PrismEditError: Error, Sendable, Hashable {
    case noSuchNode(PrismID), noSuchMaterial(PrismID), notAnimatable(PrismProperty, PrismNodeKind)
    case parentCycle, notANumber(PrismProperty), outOfRange(String), emptyName, emptyOutline, nothingSelected
    public var message: String {
        switch self {
        case .noSuchNode: "That object is no longer in the scene."
        case .noSuchMaterial: "That material is no longer in the scene."
        case let .notAnimatable(p, k): "A \(k.rawValue) has no \(p.title)."
        case .parentCycle: "An object can't be placed inside itself or its children."
        case let .notANumber(p): "\(p.title) needs a number."
        case let .outOfRange(what): what
        case .emptyName: "Enter a name."
        case .emptyOutline: "There's no closed shape to extrude."
        case .nothingSelected: "Select an object first."
        }
    }
}

public enum PrismImportError: Error, Sendable, Hashable {
    case unsupportedFormat(String), damaged(String), missingSidecar(String), tooLarge(Int), empty
    public var message: String {
        switch self {
        case let .unsupportedFormat(ext): "Prism can't import .\(ext) files. Try glTF, OBJ, STL, PLY or USDZ."
        case let .damaged(reason): "This model is damaged: \(reason)"
        case let .missingSidecar(name): "\(name) is missing. Put it next to the model and import again."
        case let .tooLarge(triangles): "This model has \(triangles) triangles; Prism opens up to 5,000,000."
        case .empty: "This file has no meshes in it."
        }
    }
    public static let maximumTriangles = 5_000_000
}

public enum PrismFileError: Error, Sendable, Hashable {
    case notAPrismFile, newerFormat(Int), damaged(String), tooLarge, unsupportedExport(String)
    public var message: String {
        switch self {
        case let .unsupportedExport(ext): "Prism can't export .\(ext) yet." 
        case .notAPrismFile: "This isn't a Prism scene."
        case let .newerFormat(v): "This scene was saved by a newer Prism (format \(v)). Update Prism to open it."
        case let .damaged(reason): "This scene is damaged: \(reason)"
        case .tooLarge: "This scene is larger than 512 MB, more than Prism opens."
        }
    }
}

public enum PrismRenderError: Error, Sendable, Hashable {
    case badSize, noCamera, sinkFailed(String)
    public var message: String {
        switch self {
        case .badSize: "Width and height must be whole numbers from 16 to 8192."
        case .noCamera: "Add a camera or render from the view."
        case let .sinkFailed(reason): "Couldn't write the frame: \(reason)"
        }
    }
}
