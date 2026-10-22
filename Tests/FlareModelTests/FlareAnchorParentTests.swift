// FlareAnchorParentTests.swift (anchor-parenting AN-9, MJ-AN-flare): a Flare layer turns about its anchor and
// follows its parent. A rectangle drawn with the tool and keyed 0 to 360 degrees keeps its centre at frame 12 of 24
// (the spin no longer orbits the canvas's top-left corner); a hand parented to an arm through `layer.set-parent`
// stays where it was and then follows the arm's turn; Flare's Lottie export writes `ks.a` and `parent` and reads
// them back; and the fixtures, which have no anchor or parent, draw and save the same. Every test waits on AN-10
// (FlarePlacement+Kernel, the parent command in Flare's catalog, new shapes anchored at their centre).
// Runs on Linux and macOS.
import Foundation
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareAnchorParentTests {
    static func near(_ a: FlareCore.Point, _ b: FlareCore.Point, _ tolerance: Double = 1e-6) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
    }

    static func near(_ a: Matrix, _ b: Matrix, _ tolerance: Double = 1e-6) -> Bool {
        zip([a.a, a.b, a.c, a.d, a.tx, a.ty], [b.a, b.b, b.c, b.d, b.tx, b.ty]).allSatisfy { abs($0 - $1) <= tolerance }
    }

    /// The scene-space box of every item `layerID` draws in the selected scene at `frame`.
    static func box(_ w: FlareWorkspace, _ layerID: String, at frame: Double) -> Rect? {
        guard let scene = w.selectedScene else { return nil }
        let boxes = scene.renderList(at: frame, symbols: w.document?.symbols ?? []).items
            .filter { $0.address.layerID == layerID }.compactMap(\.worldBounds)
        guard let first = boxes.first else { return nil }
        return boxes.dropFirst().reduce(first) {
            Rect(minX: min($0.minX, $1.minX), minY: min($0.minY, $1.minY), maxX: max($0.maxX, $1.maxX), maxY: max($0.maxY, $1.maxY))
        }
    }

    static func centre(_ r: Rect) -> FlareCore.Point { FlareCore.Point(x: (r.minX + r.maxX) / 2, y: (r.minY + r.maxY) / 2) }

    /// The matrix of the first item `layerID` draws at `frame`: its parent chain times its own.
    static func world(_ w: FlareWorkspace, _ layerID: String, at frame: Double) -> Matrix? {
        w.selectedScene?.renderList(at: frame, symbols: w.document?.symbols ?? []).items
            .first { $0.address.layerID == layerID }?.matrix
    }

    static func layer(_ w: FlareWorkspace, _ id: String) -> Layer? { w.selectedScene?.layers.first { $0.id == id } }

    static func rectangle(_ minX: Double, _ minY: Double, _ maxX: Double, _ maxY: Double) -> FlareShape {
        FlareShape(points: [FlareCore.Point(x: minX, y: minY), FlareCore.Point(x: maxX, y: minY),
                            FlareCore.Point(x: maxX, y: maxY), FlareCore.Point(x: minX, y: maxY)],
                   fill: .solid(FlareColor(r: 0.2, g: 0.4, b: 0.9)))
    }

    static func still(_ value: Double) -> [Keyframe] { [Keyframe(frame: 0, value: value)] }

    /// A 24-frame scene: an arm 120 × 20 anchored at its shoulder (0, 10) at (100, 200), turning 0 to 45 degrees,
    /// and a hand 30 × 30 at its tip, not parented unless `parented`.
    static func armAndHand(parented: Bool = false) -> Document {
        let arm = Layer(id: "arm", name: "Arm", shapes: [rectangle(0, 0, 120, 20)],
                        tracks: ["x": still(100), "y": still(200), "anchorX": still(0), "anchorY": still(10),
                                 "rotation": [Keyframe(frame: 0, value: 0), Keyframe(frame: 24, value: 45)]])
        let hand = Layer(id: "hand", name: "Hand", shapes: [rectangle(0, 0, 30, 30)],
                         tracks: ["x": still(220), "y": still(195), "anchorX": still(15), "anchorY": still(15)],
                         parentID: parented ? "arm" : nil)
        return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 24, layers: [arm, hand])])
    }

    /// A 200 × 200 rectangle drawn at (400, 300) and keyed 0 to 360 over 24 frames turns in place: its centre at
    /// frame 12 (half a turn) is within 1 px of frame 0's, and its anchor lands on that centre.
    @Test(.disabled("waits on AN-10: new shapes anchored at their centre")) func drawnRectangleSpinsInPlace() throws {
        var w = FlareWorkspace(services: .built)
        w.newDocument()
        w.selectTool(.rectangle)
        w.drag(from: FlareCore.Point(x: 300, y: 200), to: FlareCore.Point(x: 500, y: 400))
        let id = try #require(w.selectedScene?.layers.last?.id)
        for (frame, degrees) in [(0, 0.0), (24, 360)] {
            w.apply(SetKeyframe(owner: .scene("scene-1"), layerID: id, property: "rotation",
                                keyframe: Keyframe(frame: frame, value: degrees)))
        }
        #expect(w.layerError == nil)
        let start = try #require(Self.box(w, id, at: 0)), half = try #require(Self.box(w, id, at: 12))
        #expect(Self.near(Self.centre(start), FlareCore.Point(x: 400, y: 300), 1), "\(start)")
        #expect(Self.near(Self.centre(half), Self.centre(start), 1), "the spin orbits \(Self.centre(half)), not the centre")
        let placed = try #require(Self.layer(w, id)).placement(at: 12).transform
        let anchor = FlareCore.Point(x: placed.anchorX, y: placed.anchorY)
        #expect(Self.near(placed.matrix.apply(anchor), FlareCore.Point(x: 400, y: 300), 1), "the anchor is the box's centre")
        #expect(placed.anchorX != 0 || placed.anchorY != 0, "a new shape's anchor is its centre, not its origin")
    }

    /// `layer.set-parent` hand to arm keeps the hand where it was at frame 0, is one undo step, and from then on
    /// the hand follows the arm's turn: its world matrix is the arm's turn times its own place before parenting.
    @Test(.disabled("waits on AN-10: layer.set-parent in Flare's catalog")) func handFollowsTheArmWithNoJump() throws {
        var w = FlareWorkspace(services: .built)
        w.load(Self.armAndHand())
        let before = try #require(Self.world(w, "hand", at: 0))
        let arm0 = try #require(Self.world(w, "arm", at: 0)), arm24 = try #require(Self.world(w, "arm", at: 24))
        _ = try FlareWorkspace.catalog.run("layer.set-parent", params: .object(["id": .string("hand"), "parent": .string("arm")]), on: &w)
        #expect(Self.layer(w, "hand")?.parentID == "arm")
        let after = try #require(Self.world(w, "hand", at: 0))
        #expect(Self.near(after, before), "the hand jumps when parented: \(before) to \(after)")
        let followed = try #require(Self.world(w, "hand", at: 24))
        #expect(Self.near(followed, arm24 * (try arm0.inverted()) * before), "the hand doesn't follow the arm's turn")
        #expect(Self.near(Self.world(w, "arm", at: 24) ?? .identity, arm24), "parenting moves the arm")

        _ = try FlareWorkspace.catalog.run("layer.set-parent", params: .object(["id": .string("hand"), "parent": .null]), on: &w)
        #expect(Self.layer(w, "hand")?.parentID == nil)
        #expect(Self.near(Self.world(w, "hand", at: 24) ?? .identity, followed), "clearing the parent moves the hand")
        w.undo()
        #expect(Self.layer(w, "hand")?.parentID == "arm", "clearing the parent is one undo step")
    }

    /// Flare's Lottie export writes the arm's anchor as `ks.a` and the hand's `parent` as the arm's `ind`, and
    /// reading those bytes back gives the hand its parent and the arm its anchor.
    @Test(.disabled("waits on AN-10: Flare's Lottie anchor and parent")) func lottieRoundTripsAnchorAndParent() async throws {
        let document = Self.armAndHand(parented: true)
        let options = ExportOptions(format: .lottie, sceneID: "scene-1", frames: 0...0)
        let result = try await LiveExportAdapter(stage: LiveStage()).export(document, options: options, rasterizer: FakeRasterizer()) { _ in }
        let data = try #require(result.files.first).data
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let layers = try #require(root["layers"] as? [[String: Any]])
        let arm = try #require(layers.first { $0["nm"] as? String == "Arm" })
        let hand = try #require(layers.first { $0["nm"] as? String == "Hand" })
        #expect((hand["parent"] as? NSNumber)?.intValue == (arm["ind"] as? NSNumber)?.intValue && hand["parent"] != nil)
        let anchor = ((arm["ks"] as? [String: Any])?["a"] as? [String: Any])?["k"] as? [NSNumber]
        #expect(anchor?.prefix(2).map(\.doubleValue) == [0, 10], "\(String(describing: anchor))")

        let (read, _) = try LottieImport.document(from: data)
        let back = try #require(read.scenes.first?.layers)
        let readArm = try #require(back.first { $0.name == "Arm" }), readHand = try #require(back.first { $0.name == "Hand" })
        #expect(readHand.parentID == readArm.id)
        let placed = readArm.placement(at: 0).transform
        #expect(placed.anchorX == 0 && placed.anchorY == 10)
    }

    /// The fixtures have no anchor or parent: opened in Flare they draw the same items at frames 0, 12 and 24 as
    /// FlareCore draws them, and save the bytes they always did, with no anchor or parent written.
    @Test(.disabled("waits on AN-10: FlarePlacement+Kernel"), arguments: FlareFixtures.all.map(\.name))
    func oldFilesDrawTheSame(fixture: String) throws {
        let document = try #require(FlareFixtures.named(fixture))
        var w = FlareWorkspace(services: .built)
        w.load(document)
        let opened = try #require(w.document)
        for (scene, again) in zip(document.scenes, opened.scenes) {
            for frame in [0.0, 12, 24] {
                #expect(again.renderList(at: frame, symbols: opened.symbols) == scene.renderList(at: frame, symbols: document.symbols),
                        "\(fixture) \(scene.id) draws differently at \(frame)")
            }
        }
        let saved = try FlareFormat.encode(opened)
        #expect(saved == (try FlareFormat.encode(document)))
        let text = String(decoding: saved, as: UTF8.self)
        #expect(!text.contains("\"anchorX\"") && !text.contains("\"parent\""), "\(fixture) writes an anchor or parent")
    }
}
