// main.swift: proof checks of every fake against the behavior part 6 states.
// W0 turns each block into a Swift Testing suite in Tests/PrismModelTests/<Contract>ContractTests.swift.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

nonisolated(unsafe) var failures: [String] = []
func check(_ ok: Bool, _ what: String, line: Int = #line) { if !ok { failures.append("line \(line): \(what)") } }
func near(_ a: Double?, _ b: Double, _ eps: Double = 1e-6) -> Bool { a.map { abs($0 - b) <= eps } ?? false }

let s = PrismServices.fake
var doc = PrismDocumentState()

// UC2 primitives: a unit cube has 8 vertices, 6 quads, bounds ±0.5; every primitive is valid.
let cube = s.primitives.mesh(for: .cube, id: doc.takeID("mesh"), detail: 1)
check(cube.positions.count == 8 && cube.faces.count == 6 && cube.triangleCount == 12, "cube counts")
check(cube.bounds.size == Vec3(1, 1, 1), "cube is 1 across")
for p in PrismPrimitive.allCases {
    let m = s.primitives.mesh(for: p, id: PrismID("p"), detail: 16)
    check(m.problem == nil && !m.faces.isEmpty, "\(p) is a valid mesh")
}

// Scene: a cube under a group, a light, a camera.
let groupID = doc.takeID("node"), cubeID = doc.takeID("node"), lightID = doc.takeID("node"), camID = doc.takeID("node")
doc.scene.meshes = [cube]
doc.scene.materials = [PrismMaterial(id: PrismID("mat-1"), name: "Red", baseColor: PrismColor(1, 0, 0))]
doc.scene.nodes = [
    PrismNode(id: groupID, name: "Rig", kind: .group, transform: PrismTransform(position: Vec3(10, 0, 0))),
    PrismNode(id: cubeID, name: "Box", kind: .mesh, parentID: groupID, meshID: cube.id, materialID: PrismID("mat-1")),
    PrismNode(id: lightID, name: "Key", kind: .light, light: PrismLight(kind: .point, intensity: 800)),
    PrismNode(id: camID, name: "Camera", kind: .camera, transform: PrismTransform(position: Vec3(0, 0, 10)), camera: PrismCamera()),
]
doc.scene.settings = PrismSceneSettings(width: 640, height: 360, framesPerSecond: 24, durationFrames: 48)

// UC4 arranging: parent offsets apply; a cycle is refused and changes nothing; keepWorld keeps the place.
check(near(s.arranging.worldMatrix(of: cubeID, in: doc.scene, at: 0)?[0, 3], 10), "world includes parent")
var scene = doc.scene
do { try s.arranging.reparent(groupID, to: cubeID, index: 0, keepWorld: true, in: &scene, at: 0); check(false, "cycle accepted") }
catch { check(error == .parentCycle && scene == doc.scene, "cycle refused, scene unchanged") }
do {
    try s.arranging.reparent(cubeID, to: nil, index: 99, keepWorld: true, in: &scene, at: 0)
    check(near(s.arranging.worldMatrix(of: cubeID, in: scene, at: 0)?[0, 3], 10), "keepWorld keeps x = 10")
    check(scene.node(cubeID)?.parentID == nil, "now at the root")
} catch { check(false, "reparent to root threw \(error)") }

// UC11 keys: stopwatch keys now and the last frame; setValue moves the key; the middle is eased.
scene = doc.scene
do {
    try s.keying.toggleAnimation(.positionY, node: cubeID, at: 0, in: &scene)
    check(s.keying.keyFrames(of: cubeID, in: scene) == [0, 47], "stopwatch keys 0 and 47")
    try s.keying.setValue(4.7, of: .positionY, node: cubeID, at: 47, in: &scene)
    check(near(s.keying.value(of: .positionY, node: cubeID, in: scene, at: 10), 1.0), "linear midway value")
    // UC12 easing: ease-in-out is below linear at a quarter and equal at the middle.
    try s.easing.setEasing(.easeInOut, for: [PrismKeyRef(node: cubeID, property: .positionY, frame: 0)], in: &scene)
    let quarter = s.keying.value(of: .positionY, node: cubeID, in: scene, at: 12) ?? 0
    check(quarter < 1.2, "eased value below linear at a quarter")
    check(near(s.keying.value(of: .positionY, node: cubeID, in: scene, at: 0), 0) , "key value at 0")
    try s.keying.setValue(.nan, of: .positionY, node: cubeID, at: 3, in: &scene)
    check(false, "NaN accepted")
} catch { check(error == .notANumber(.positionY), "NaN refused with notANumber") }
do { try s.keying.setValue(1, of: .lightIntensity, node: cubeID, at: 0, in: &scene); check(false, "intensity on a mesh") }
catch { check(error == .notAnimatable(.lightIntensity, .mesh), "intensity refused on a mesh") }
check(PrismProperty.parse("45°") == 45 && PrismProperty.parse("abc") == nil, "parse")

// UC5, UC6 navigation and picking: framing the cube puts it under the center of the view.
let view = s.navigating.frame(s.arranging.worldBounds(of: [cubeID], in: doc.scene, at: 0), in: PrismViewCamera(), aspect: 16 / 9)
check(near(view.target.x, 10) && view.distance > 0.5, "frame targets the cube")
let ray = s.picking.ray(at: ViewPoint(0.5, 0.5), viewpoint: .free(view), in: doc.scene, at: 0, aspect: 16 / 9)
check(ray.flatMap { s.picking.hit($0, in: doc.scene, at: 0) }?.node == cubeID, "center click hits the cube")
let corner = s.picking.ray(at: ViewPoint(0.01, 0.01), viewpoint: .free(view), in: doc.scene, at: 0, aspect: 16 / 9)
check(corner.flatMap { s.picking.hit($0, in: doc.scene, at: 0) } == nil, "corner click hits nothing")
check(s.navigating.dolly(view, factor: 1e9).distance == PrismViewCamera.minimumDistance, "dolly clamps")
check(s.navigating.orbit(view, dx: 0, dy: 1e6).pitchDegrees <= 89.9, "orbit pitch clamps")

// UC7 gizmo: dragging the X arrow a tenth of the view moves 1 unit, snapped to 0.25.
if let drag = s.gizmo.begin(.move, handle: .axis(.x), node: cubeID, at: ViewPoint(0.5, 0.5), viewpoint: .free(view),
                            in: doc.scene, at: 0, aspect: 16 / 9) {
    let t = s.gizmo.transform(for: drag, to: ViewPoint(0.61, 0.5), viewpoint: .free(view), in: doc.scene, at: 0,
                              aspect: 16 / 9, snap: .standard)
    check(near(t.position.x, 1.0) && t.position.y == 0, "move x snapped to 1.0")
} else { check(false, "gizmo begin") }

// UC21 modeling: extrude the top face of a cube adds 4 side faces; loop cut adds a ring; merge collapses.
let top = cube.faces.firstIndex { f in f.allSatisfy { cube.positions[Int($0)].y > 0 } } ?? -1
do {
    let (m1, sel1) = try s.meshEditing.apply(.extrude(distance: 1), to: cube, selection: PrismMeshSelection(faces: [top]), mode: .face)
    check(m1.faces.count == 10 && m1.positions.count == 12 && m1.problem == nil, "extrude counts")
    check(near(m1.bounds.max.y, 1.5), "extruded 1 up")
    check(sel1.faces == [top], "extruded face stays selected")
    let (m2, sel2) = try s.meshEditing.apply(.loopCut(cuts: 1), to: cube, selection: PrismMeshSelection(edges: [PrismEdge(0, 1)]), mode: .edge)
    check(m2.faces.count == 10 && m2.positions.count == 12 && m2.edges.count == 20 && m2.problem == nil && sel2.edges.count == 4,
          "loop cut around the cube: 10 faces, 12 vertices, 20 edges, the new 4-edge loop selected")
    let (m3, _) = try s.meshEditing.apply(.inset(amount: 0.1), to: cube, selection: PrismMeshSelection(faces: [top]), mode: .face)
    check(m3.faces.count == 10 && m3.problem == nil, "inset adds a ring of 4")
    let (m4, _) = try s.meshEditing.apply(.delete, to: cube, selection: PrismMeshSelection(faces: [top]), mode: .face)
    check(m4.faces.count == 5, "delete one face")
    _ = try s.meshEditing.apply(.extrude(distance: 1), to: cube, selection: PrismMeshSelection(), mode: .face)
    check(false, "extrude with nothing selected")
} catch { check(error == .nothingSelected, "empty selection refused") }
check(s.meshEditing.unavailableHelp(for: .bevel) != nil, "fake leaves bevel to live")
let r = PrismRay(origin: Vec3(0, 5, 0), direction: Vec3(0, -1, 0))
check(s.meshEditing.pick(r, mesh: cube, world: .identity, mode: .face) == .face(top), "pick the top face from above")
check(s.meshEditing.loop(through: PrismEdge(0, 1), in: cube) == [PrismEdge(0, 1)], "a cube's loop stops at its valence-3 corners")
// A 4 × 4 grid of quads (5 × 5 vertices, index = row * 5 + column): the loop through an interior
// vertical edge runs the full height, 4 edges.
let grid = PrismMesh(id: PrismID("grid"), name: "Grid",
                     positions: (0..<25).map { Vec3(Double($0 % 5), 0, Double($0 / 5)) },
                     faces: (0..<16).map { q -> [UInt32] in let r = q / 4, c = q % 4, a = UInt32(r * 5 + c); return [a, a + 5, a + 6, a + 1] })
check(Set(s.meshEditing.loop(through: PrismEdge(7, 12), in: grid)) == [PrismEdge(2, 7), PrismEdge(7, 12), PrismEdge(12, 17), PrismEdge(17, 22)],
      "grid loop is the full column of 4 edges")

// UC3 extrusion: "AB" with the fake glyphs gives two boxes, 6 faces each.
let outline = s.glyphs.outline(of: "A B", fontName: "Helvetica", size: 1)
do {
    let solid = try s.extruding.extrude(outline, PrismExtrusion(depth: 0.2), id: PrismID("m-text"), name: "Text")
    check(solid.faces.count == 12 && near(solid.bounds.size.z, 0.2), "two extruded letters")
    _ = try s.extruding.extrude(PrismOutline(contours: []), PrismExtrusion(), id: PrismID("x"), name: "x")
    check(false, "empty outline accepted")
} catch { check(error == .emptyOutline, "empty outline refused") }

// UC8, UC9, UC10 look: clamped material values; lights and cameras refuse wrong kinds.
scene = doc.scene
do {
    var red = scene.materials[0]; red.metallic = 4; red.roughness = -1
    try s.materials.update(red, in: &scene)
    check(scene.materials[0].metallic == 1 && scene.materials[0].roughness == 0, "material clamps")
    try s.materials.assign(PrismID("mat-1"), to: [lightID], in: &scene)
    check(false, "material on a light")
} catch { check(error == .outOfRange("Only objects with a shape take a material."), "material refused on a light") }
check(s.lights.rig(named: "Three-Point", around: cube.bounds).count == 3, "three-point rig")
do { try s.cameras.setActiveCamera(cubeID, in: &scene); check(false, "cube as camera") }
catch { check(error == .outOfRange("That object isn't a camera."), "active camera must be a camera") }
let (cam, camT) = s.cameras.camera(matching: view)
check(cam.projection == .perspective(fieldOfViewDegrees: view.fieldOfViewDegrees) && near(camT.position.x, view.eye.x), "camera matches view")

// UC13 clock: 24 fps, 1 s after start from frame 10 is frame 34; loops wrap at 48.
check(s.clock.frame(at: 1, startTime: 0, startFrame: 10, settings: doc.scene.settings, loops: true) == 34, "clock")
check(s.clock.frame(at: 3, startTime: 0, startFrame: 0, settings: doc.scene.settings, loops: true) == 24, "clock loops")
check(s.clock.frame(at: 3, startTime: 0, startFrame: 0, settings: doc.scene.settings, loops: false) == 47, "clock holds")

// UC14 history: coalesced drags make one step; undo then redo restores; record clears redo.
var history = PrismHistory()
var a = doc, b = doc
b.selection = [cubeID]
s.history.record(a, name: "Move", coalesceKey: "drag-1", into: &history)
s.history.record(a, name: "Move", coalesceKey: "drag-1", into: &history)
check(history.undo.count == 1 && history.undoTitle == "Undo Move", "coalesced to one step")
if let back = s.history.undo(b, history: &history) { a = back } else { check(false, "undo") }
check(a == doc && history.redoTitle == "Redo Move", "undo restores and offers redo")
check(s.history.redo(a, history: &history) == b, "redo returns the later state")
s.history.record(a, name: "Rename", coalesceKey: nil, into: &history)
check(history.redo.isEmpty, "record clears redo")

// UC15 files: round trip is equal; newer, foreign and damaged files are refused.
do {
    let pkg = try s.files.encode(doc)
    check(try s.files.decode(pkg) == doc, "file round trip")
    let newer = PrismFilePackage(document: Data(#"{"format":"prism","version":2}"#.utf8), buffers: [:])
    do { _ = try s.files.decode(newer); check(false, "newer accepted") } catch { check(error == .newerFormat(2), "newer refused") }
    do { _ = try s.files.decode(PrismFilePackage(document: Data("nope".utf8), buffers: [:])); check(false, "junk accepted") }
    catch { check(error == .notAPrismFile, "junk refused") }
    var bad = doc
    bad.scene.meshes[0].faces.append([0, 1, 99])
    let badPkg = try s.files.encode(bad)
    do { _ = try s.files.decode(badPkg); check(false, "damaged accepted") }
    catch { check(error == .damaged("Cube points at a vertex it doesn't have."), "damaged refused with reason") }
} catch { check(false, "files threw \(error)") }

// UC1 import: two cubes; a gltf without its buffer names it; unsupported formats say which.
do {
    let res = try s.importing.importModel(Data("two cubes".utf8), format: .obj, name: "Boxes", sidecars: [:])
    check(res.nodes.count == 2 && res.meshes.count == 2 && res.warnings.count == 1, "import two cubes with a warning")
    _ = try s.importing.importModel(Data("cube".utf8), format: .gltf, name: "G", sidecars: [:])
    check(false, "gltf without buffer")
} catch { check(error == .missingSidecar("scene.bin"), "missing sidecar named") }
do { _ = try s.importing.importModel(Data(), format: .usdz, name: "U", sidecars: [:]); check(false, "usdz in core") }
catch { check(error == .unsupportedFormat("usdz"), "usdz is the platform importer's") }

// UC16 export: OBJ has the cube's 8 vertices moved by its parent.
do {
    let obj = String(decoding: try s.exporting.export(doc.scene, format: .obj, at: 0), as: UTF8.self)
    check(obj.components(separatedBy: "\nv ").count - 1 == 8 && obj.contains("v 9.5 "), "obj export world positions")
} catch { check(false, "export threw \(error)") }

// UC17, UC18 draw and render: one item, red where the cube is, transparent elsewhere when asked.
var transparent = doc.scene
transparent.environment.transparentBackground = true
if let list = s.drawing.drawList(transparent, selection: [cubeID], viewpoint: .free(view), at: 0, aspect: 16 / 9) {
    check(list.items.count == 1 && list.items[0].isSelected && list.lights.count == 1, "draw list")
    do {
        let img = try s.rendering.render(list, meshes: transparent.meshes, textures: [], width: 160, height: 90, quality: .preview)
        check(img.isValid && img.pixel(x: 80, y: 45)?.0 == 1 && img.pixel(x: 1, y: 1)?.3 == 0, "render center red, corner clear")
        _ = try s.rendering.render(list, meshes: [], textures: [], width: 8, height: 8, quality: .preview)
        check(false, "tiny render")
    } catch { check(error == .badSize, "bad size refused") }
} else { check(false, "draw list") }

// UC19 sequences: 48 frames into a counting sink; cancel stops; a sink failure reports the reason.
let plan = PrismRenderPlan(format: .pngSequence, frames: 0...47, width: 64, height: 36, quality: .preview,
                           baseName: "Spin", transparentBackground: true)
let sink = CountingSink()
let outcome = s.sequences.run(plan, scene: doc.scene, viewpoint: .camera(camID), drawing: s.drawing, renderer: s.rendering,
                              sink: sink, progress: { _ in }, isCancelled: { false })
check(outcome == .finished(files: (0..<48).map { plan.fileName(forFrameAt: $0) }, frames: 48), "48 frames written")
check(plan.fileName(forFrameAt: 0) == "Spin_0001.png", "file names")
let cancelled = s.sequences.run(plan, scene: doc.scene, viewpoint: .camera(camID), drawing: s.drawing, renderer: s.rendering,
                                sink: CountingSink(), progress: { _ in }, isCancelled: { true })
check(cancelled == .cancelled(atFrame: 0), "cancel")
let failing = s.sequences.run(plan, scene: doc.scene, viewpoint: .camera(camID), drawing: s.drawing, renderer: s.rendering,
                              sink: CountingSink(failAt: 3), progress: { _ in }, isCancelled: { false })
check(failing == .failed(frame: 0, message: "Couldn't write the frame: the disk is full."), "sink failure")

// UC20 hand-off: a PNG sequence goes to Halo with alpha; Design refuses a sequence and says what to pick.
let req = s.handOff.request(for: .halo, plan: plan, outcome: outcome, settings: doc.scene.settings, sourceDocument: "Spin.prism")
check(req?.files.count == 48 && req?.hasAlpha == true && req?.framesPerSecond == 24, "halo hand-off")
check(s.handOff.refusal(for: .design, plan: plan) == "Design can't take this kind of render. Pick Still.", "design refuses a sequence")

// UC3b vector art: two rects become two shapes with their fills; a circle is skipped with a warning.
do {
    let svg = ##"<svg><rect x="0" y="0" width="10" height="5" fill="#ff0000"/><circle r="3"/><rect x="20" y="0" width="5" height="5"/></svg>"##
    let (shapes, warnings) = try s.vectors.shapes(fromSVG: Data(svg.utf8))
    check(shapes.count == 2 && shapes[0].fill == PrismColor(1, 0, 0) && warnings.count == 1, "svg rects and a warning")
    let solid = try s.extruding.extrude(shapes[0].outline, PrismExtrusion(depth: 1), id: PrismID("v"), name: "Logo")
    check(near(solid.bounds.size.x, 10) && near(solid.bounds.size.y, 5), "extruded svg keeps its size")
} catch { check(false, "svg threw \(error)") }

// UC3c images: a 2 × 1 test image decodes; a short one is damaged.
do {
    let tex = try s.images.decode(Data("RGBA 2 1\n".utf8) + Data([255, 0, 0, 255, 0, 0, 255, 255]), name: "Swatch", id: PrismID("t"))
    check(tex.isValid && tex.width == 2, "decode test image")
    _ = try s.images.decode(Data("RGBA 2 2\n".utf8) + Data([1, 2, 3]), name: "Bad", id: PrismID("t2"))
    check(false, "short image accepted")
} catch { check(error == .damaged("the image is cut short."), "short image refused") }
do { _ = try s.images.decode(Data("GIF89a".utf8), name: "x", id: PrismID("t3")); check(false, "gif accepted") }
catch { check(error == .unreadableImage && error.message.hasPrefix("Prism can't read this image."), "unreadable image message") }

// New Scene sheet: per-field problems; valid text gives the settings.
let bad = PrismSceneSettings.problems(width: "abc", height: "1920", lengthSeconds: "0", framesPerSecond: 24)
check(bad.problems[.width] == "Width must be a whole number from 16 to 8192." && bad.problems[.length] != nil && bad.parsed == nil, "scene problems")
check(PrismSceneSettings.problems(width: "1080", height: "1920", lengthSeconds: "2", framesPerSecond: 24).parsed
      == PrismSceneSettings(width: 1080, height: 1920, framesPerSecond: 24, durationFrames: 48), "scene parsed 48 frames")
check(PrismEditError.emptyText.message == "Enter some text.", "empty text message")
check(PrismLightKind.point.shadowHelp != nil && PrismLightKind.spot.shadowHelp == nil && !PrismLightKind.v1.contains(.area), "v1 lights")

// UC22 modifiers: mirror doubles an off-axis cube; one subdivision level makes 24 quads of a cube.
do {
    var offset = cube
    offset.positions = offset.positions.map { $0 + Vec3(2, 0, 0) }
    let mirrored = try s.modifiers.evaluate(offset, modifiers: [.mirror(axis: .x, merge: true)], forRender: false)
    check(mirrored.positions.count == 16 && mirrored.faces.count == 12 && near(mirrored.bounds.min.x, -2.5), "mirror")
    let sub = try s.modifiers.evaluate(cube, modifiers: [.subdivision(levels: 1, renderLevels: 2)], forRender: false)
    check(sub.faces.count == 24 && sub.positions.count == 26 && sub.problem == nil, "subdivide once")
    let subRender = try s.modifiers.evaluate(cube, modifiers: [.subdivision(levels: 1, renderLevels: 2)], forRender: true)
    check(subRender.faces.count == 96, "render level 2")
} catch { check(false, "modifiers threw \(error)") }

// Every unbuilt service says why.
let unbuilt = PrismServices.unbuilt
check(unbuilt.importing.unavailableHelp == "Import isn't built yet." && unbuilt.rendering.unavailableHelp != nil, "unbuilt help")
check([s.importing.unavailableHelp, s.meshEditing.unavailableHelp, s.handOff.unavailableHelp].allSatisfy { $0 == nil }, "fakes work")

if failures.isEmpty { print("contracts: PASS (\(PrismPrimitive.allCases.count) primitives, 25 services)") }
else { print(failures.joined(separator: "\n")); print("contracts: FAIL") }
