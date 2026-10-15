// LiveConformanceTests.swift: ST-5 of the live-stage packet (docs/blueprints/flare/features/live-stage.md), closing
// #357. No file under `Sources/FlareModel/Live/` names `FixtureEdit` (a live type edits through the engine, never the
// fixture helper), and the scan fails if it read fewer than 3 files so a wrong path can't pass. `LiveStage` draws
// `bounce` and `character` at scene level, where the hand-built stage is exact, item for item like `FakeStage` at
// several frames, and `LiveHits.hit` equals `FakeHits` at every item's center.
import Foundation
import FlareCore
import FlareModel
import Testing

/// The package root: the first folder above this file that holds `Package.swift`.
private func packageRoot() -> URL? {
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while dir.path != "/" {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
        dir = dir.deletingLastPathComponent()
    }
    return nil
}

@Test func noFixtureEditInLive() throws {
    let root = try #require(packageRoot())
    let live = root.appendingPathComponent("Sources/FlareModel/Live")
    let walker = try #require(FileManager.default.enumerator(at: live, includingPropertiesForKeys: nil))
    var read = 0
    for case let url as URL in walker where url.pathExtension == "swift" {
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("FixtureEdit"), "\(url.lastPathComponent) uses FixtureEdit")
        read += 1
    }
    #expect(read >= 3, "read \(read) files under \(live.path)")
}

private func near(_ a: Matrix, _ b: Matrix) -> Bool {
    zip([a.a, a.b, a.c, a.d, a.tx, a.ty], [b.a, b.b, b.c, b.d, b.tx, b.ty]).allSatisfy { abs($0 - $1) <= 1e-9 }
}

private let fixtures: [(name: String, document: Document)] = [("bounce", FlareFixtures.bounce),
                                                               ("character", FlareFixtures.character)]

@Test(arguments: [0, 6, 12, 23, 47])
func liveStageEqualsFake(frame: Int) throws {
    for (name, doc) in fixtures {
        let got = LiveStage().drawList(doc, sceneID: "scene-1", frame: frame, editing: nil)
        let want = FakeStage().drawList(doc, sceneID: "scene-1", frame: frame, editing: nil)
        #expect(got.width == want.width && got.height == want.height && got.background == want.background, "\(name)")
        #expect(got.hiddenTextCount == want.hiddenTextCount, "\(name) at \(frame)")
        #expect(got.items.count == want.items.count && !got.items.isEmpty, "\(name) at \(frame)")
        for (i, (g, w)) in zip(got.items, want.items).enumerated() {
            let at = "\(name) item \(i) at frame \(frame)"
            #expect(g.address == w.address && g.path == w.path && g.fill == w.fill && g.stroke == w.stroke, "\(at)")
            #expect(near(g.transform, w.transform), "\(at): \(g.transform) vs \(w.transform)")
            #expect(abs(g.opacity - w.opacity) <= 1e-9 && g.isText == w.isText, "\(at)")
        }

        // Each drawn item's center, from the fake's world box, hits the same thing live and fake.
        for item in want.items where !item.isText {
            let local = try #require(item.path.bounds)
            let corners = [Point(x: local.minX, y: local.minY), Point(x: local.maxX, y: local.minY),
                           Point(x: local.minX, y: local.maxY), Point(x: local.maxX, y: local.maxY)]
            let box = try #require(Rect(enclosing: corners.map(item.transform.apply)))
            let center = Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2)
            let l = LiveHits().hit(doc, sceneID: "scene-1", frame: frame, editing: nil, at: center, tolerance: 0)
            let f = FakeHits().hit(doc, sceneID: "scene-1", frame: frame, editing: nil, at: center, tolerance: 0)
            #expect(l == f, "\(name) at frame \(frame), center \(center)")
        }
    }
}
