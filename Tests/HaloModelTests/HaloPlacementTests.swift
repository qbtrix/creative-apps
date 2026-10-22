// HaloPlacementTests.swift (anchor-parenting AN-7, slice AN-halo; MJ-AN-halo):
// Halo's layers place through the kernel's `Placement` (AN-8) with every render
// unchanged, and a viewer anchor drag (`transform.set-anchor` at release) keeps
// the layer where it is on screen as one undo step. Written first and disabled
// until AN-8 builds `HaloPlacement+Kernel` and registers the command; AN-8
// turns the suite on.
//
// The renders are checked against Halo's own rule written out here, not
// against any production path: T(x, y) · R(rotation) · S(scaleX, scaleY) ·
// T(−anchorX, −anchorY), each value sampled at the frame, parents applied
// outermost last. Every fixture's draw list redrawn with those matrices must
// match the live draw list within 1 level at 1/8 size. Runs on Linux and macOS.
import CoreRaster
import FlareCore
@testable import HaloModel
import SuiteKernel
import Testing

@Suite(.disabled("waits on AN-8"))
struct HaloPlacementTests {
    // MARK: Renders unchanged

    /// Halo's local matrix for `layer` at `f`, sampled through the live placing.
    static func ruleLocal(_ layer: HaloLayer, in c: HaloComposition, at f: Int) -> HaloMatrix {
        let placing = LiveLayerPlacing()
        func v(_ p: HaloProperty) -> Double { placing.value(p, of: layer.id, in: c, at: f) ?? .nan }
        return HaloMatrix.translation(x: v(.x), y: v(.y)) * HaloMatrix.rotation(degrees: v(.rotation))
            * HaloMatrix.scale(x: v(.scaleX), y: v(.scaleY)) * HaloMatrix.translation(x: -v(.anchorX), y: -v(.anchorY))
    }

    /// Layer space to composition space by the rule, stopping at a cycle or an unknown parent.
    static func ruleWorld(_ id: String, in c: HaloComposition, at f: Int) -> HaloMatrix? {
        guard let layer = c.layers.first(where: { $0.id == id }) else { return nil }
        var m = ruleLocal(layer, in: c, at: f), seen: Set<String> = [id], next = layer.parentID
        while let pid = next, !seen.contains(pid), let parent = c.layers.first(where: { $0.id == pid }) {
            m = ruleLocal(parent, in: c, at: f) * m
            seen.insert(pid)
            next = parent.parentID
        }
        return m
    }

    /// Every fixture's compositions, plus `keyed` with Ball's anchor and rotation keyed, so a
    /// keyed anchor is sampled at the frame and not read once.
    static func compositions() throws -> [(String, HaloComposition)] {
        var out: [(String, HaloComposition)] = []
        for name in HaloFixtures.names {
            let state = try #require(HaloFixtures.project(name), "no fixture \(name)")
            out += state.compositions.map { ("\(name)/\($0.name)", $0) }
        }
        var keyed = try #require(HaloFixtures.project("keyed")?.compositions.first)
        let ball = try #require(keyed.layers.firstIndex { $0.name == "Ball" })
        keyed.layers[ball].tracks["anchorX"] = [HaloKeyframe(frame: 0, value: 0), HaloKeyframe(frame: 24, value: 60)]
        keyed.layers[ball].tracks["anchorY"] = [HaloKeyframe(frame: 0, value: 40), HaloKeyframe(frame: 47, value: -20)]
        keyed.layers[ball].tracks["rotation"] = [HaloKeyframe(frame: 0, value: 0), HaloKeyframe(frame: 47, value: 270)]
        return out + [("keyed-anchored", keyed)]
    }

    /// The first, middle and last frame of `c`.
    static func frames(_ c: HaloComposition) -> [Int] {
        Array(Set([0, c.durationFrames / 2, max(0, c.durationFrames - 1)])).sorted()
    }

    static func close(_ a: HaloMatrix, _ b: HaloMatrix) -> Bool {
        let tolerance = 1e-6
        return [a.a - b.a, a.b - b.b, a.c - b.c, a.d - b.d, a.tx - b.tx, a.ty - b.ty].allSatisfy { abs($0) <= tolerance }
    }

    @Test func everyLayersMatrixIsHalosRuleAtEveryCheckedFrame() throws {
        for (name, comp) in try Self.compositions() {
            for f in Self.frames(comp) {
                for item in LiveFrameDrawing().drawList(comp, at: f).items {
                    let rule = try #require(Self.ruleWorld(item.layerID, in: comp, at: f))
                    #expect(Self.close(item.matrix, rule), "\(name) \(item.layerID) at \(f): \(item.matrix) is not \(rule)")
                }
            }
        }
    }

    @Test func everyFixtureRendersTheSameFramesWithinOneLevel() throws {
        // `huge` (2,000 layers) is the files budget's fixture; its matrices are checked above.
        for (name, comp) in try Self.compositions() where !name.hasPrefix("huge/") {
            let (w, h) = (max(1, comp.width / 8), max(1, comp.height / 8))
            for f in Self.frames(comp) {
                let live = LiveFrameDrawing().drawList(comp, at: f)
                var rule = live
                for i in rule.items.indices {
                    rule.items[i].matrix = try #require(Self.ruleWorld(rule.items[i].layerID, in: comp, at: f))
                }
                let a = try LiveFrameRendering().render(live, width: w, height: h, text: nil).pixels.rgba8()
                let b = try LiveFrameRendering().render(rule, width: w, height: h, text: nil).pixels.rgba8()
                #expect(a.count == b.count, "\(name) at \(f)")
                let worst = zip(a, b).map { abs(Int($0) - Int($1)) }.max() ?? 0
                #expect(worst <= 1, "\(name) at \(f) differs by \(worst) levels")
            }
        }
    }

    // MARK: The viewer's anchor drag

    /// A live project on fixture `name` with `edit` applied to its state, `layer` selected, at `frame`.
    static func project(_ name: String, select layer: String, at frame: Int,
                        _ edit: (inout HaloComposition) -> Void = { _ in }) throws -> HaloProject {
        var state = try #require(HaloFixtures.project(name))
        edit(&state.compositions[0])
        var project = HaloProject(services: .live)
        project.restore(state)
        let id = try #require(state.compositions.first?.layers.first { $0.name == layer }?.id)
        project.selectLayer(id)
        _ = try HaloProject.catalog.run("timeline.scrub", params: .object(["frame": .number(Double(frame))]), on: &project)
        return project
    }

    /// The selected layer's drawn box corners in composition space at `f`.
    static func corners(_ project: HaloProject, at f: Int) throws -> [HaloPoint] {
        let comp = try #require(project.selectedComposition), id = try #require(project.selectedLayerID)
        let item = try #require(LiveFrameDrawing().drawList(comp, at: f).items.first { $0.layerID == id })
        let r = item.bounds
        return [(r.x, r.y), (r.x + r.width, r.y), (r.x + r.width, r.y + r.height), (r.x, r.y + r.height)]
            .map { item.matrix.apply(HaloPoint(x: $0.0, y: $0.1)) }
    }

    /// The selected layer's box in its own space at `f`.
    static func box(_ project: HaloProject, at f: Int) throws -> HaloLayerRect {
        let comp = try #require(project.selectedComposition), id = try #require(project.selectedLayerID)
        return try #require(LiveFrameDrawing().drawList(comp, at: f).items.first { $0.layerID == id }).bounds
    }

    /// Drags the selected layer's anchor to its box's bottom middle, as the viewer sends it at release,
    /// and checks the layer stayed put, the anchor landed, and the drag is one undo step undone whole.
    static func dragAnchorToBottom(_ start: HaloProject, at f: Int) throws -> HaloProject {
        var project = start
        let id = try #require(project.selectedLayerID), box = try Self.box(project, at: f)
        let before = try Self.corners(project, at: f), steps = project.history.undo.count
        let target = HaloPoint(x: box.x + box.width / 2, y: box.y + box.height)
        let params: JSONValue = .object(["id": .string(id), "x": .number(target.x), "y": .number(target.y)])
        let outcome = try HaloProject.catalog.run("transform.set-anchor", params: params, on: &project)
        #expect(outcome.undoStep != nil)
        #expect(project.history.undo.count == steps + 1, "the drag is not one undo step")
        let comp = try #require(project.selectedComposition), placing = LiveLayerPlacing()
        #expect(placing.value(.anchorX, of: id, in: comp, at: f) == target.x)
        #expect(placing.value(.anchorY, of: id, in: comp, at: f) == target.y)
        for (old, new) in zip(before, try Self.corners(project, at: f)) {
            #expect(abs(old.x - new.x) < 1e-6 && abs(old.y - new.y) < 1e-6, "a corner moved from \(old) to \(new)")
        }
        var undone = project
        undone.undo()
        #expect(undone.document == start.document, "one undo doesn't bring the layer back")
        return project
    }

    @Test func anAnchorDragOnAStaticTurnedShapeKeepsItInPlace() throws {
        let project = try Self.project("three-layers", select: "Badge", at: 30) { comp in
            if let i = comp.layers.firstIndex(where: { $0.name == "Badge" }) {
                comp.layers[i].tracks["rotation"] = [HaloKeyframe(frame: 0, value: 30)]
                comp.layers[i].tracks["scaleX"] = [HaloKeyframe(frame: 0, value: 2)]
            }
        }
        let dragged = try Self.dragAnchorToBottom(project, at: 30)
        // Nothing was keyed: the static values moved, each still one key.
        let badge = try #require(dragged.selectedComposition?.layers.first { $0.id == dragged.selectedLayerID })
        #expect(badge.tracks["anchorX"]?.count ?? 0 <= 1 && badge.tracks["x"]?.count ?? 0 <= 1)
    }

    @Test func anAnchorDragOnAKeyedAnchorKeysTheAnchorAtThePlayhead() throws {
        let project = try Self.project("keyed", select: "Ball", at: 12) { comp in
            if let i = comp.layers.firstIndex(where: { $0.name == "Ball" }) {
                comp.layers[i].tracks["anchorX"] = [HaloKeyframe(frame: 0, value: 0), HaloKeyframe(frame: 24, value: 0)]
                comp.layers[i].tracks["anchorY"] = [HaloKeyframe(frame: 0, value: 0), HaloKeyframe(frame: 24, value: 0)]
                comp.layers[i].tracks["rotation"] = [HaloKeyframe(frame: 0, value: 45)]
            }
        }
        let dragged = try Self.dragAnchorToBottom(project, at: 12)
        let ball = try #require(dragged.selectedComposition?.layers.first { $0.id == dragged.selectedLayerID })
        #expect(ball.tracks["anchorX"]?.map(\.frame) == [0, 12, 24], "the drag didn't key the anchor at 12")
        #expect(ball.tracks["anchorY"]?.map(\.frame) == [0, 12, 24])
    }
}
