// KernelShapeMoreTests.swift (editor-kernel EK-3, slice EK-a): keys, transform,
// export and session declare the packet's contract as stubs that never trap,
// each public symbol documented. KJ0 runs here (KernelShapeTests is EK-1/EK-2's).
import Foundation
import Testing
import SuiteKernel

@Suite struct KernelShapeMoreTests {
    @Test func allModulesDeclared() throws {
        let ref = KeyRef<String>(layerID: "a", track: .property("x"), frame: 3)
        #expect(ref.frame == 3 && Track<String>.all != ref.track)
        #expect(Segment(key: ref, endFrame: 9, easing: .linear).endFrame == 9)
        #expect(([.notAnimated, .animated, .keyedHere] as [KeyState]).count == 3)
        #expect(EasePreset.allCases == [.linear, .ease, .easeIn, .easeOut, .easeInOut, .hold])
        _ = (EasePreset.ease.easing, EaseCurve.handles(of: .ease), EaseCurve.moving(0, to: Point(x: 0.5, y: 0.5), in: .ease))
        #expect(!EasePreset.hold.title.isEmpty && EaseCurve.samples(of: .linear, count: 5000).count <= 4096)
        #expect(([.singleStays, .propertyGoesStatic] as [RemovePolicy]).count == 2)
        var track = [Keyframe(frame: 0, value: 1), Keyframe(frame: 10, value: 2)]
        _ = (KeyRules.state(track, at: 0), KeyRules.toggleKey(&track, at: 5, value: 3, leaving: .singleStays))
        _ = KeyRules.toggleAnimated(&track, at: 0, lastFrame: 10, value: 1)
        var tracks = ["x": track]
        do throws(KeyRefusal) { try KeyRules.moveKeys(&tracks, [0], by: 2, clampedTo: 0...10) } catch {
            Issue.record("a move inside the range was refused: \(error)")
        }
        #expect(KeyRefusal.pastRange(frame: 12) != .collides(frame: 12))
        KeyRules.removeKeys(&track, [10], leaving: .propertyGoesStatic)
        KeyRules.insertFrames(&track, 2, at: 0)
        KeyRules.removeFrames(&track, 2, at: 0)

        let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 50)
        #expect(LayerTransform() == LayerTransform(scaleX: 1, scaleY: 1, degrees: 0, dx: 0, dy: 0))
        _ = (BoxMath.resized(box, .bottomRight, by: Point(x: 10, y: 10), modifiers: [.shift, .option]),
             BoxMath.scaled(box, from: box, to: box), BoxMath.snappedDegrees(22, modifiers: .shift),
             BoxMath.handles(of: box, size: 8), HandleHit.handle(at: Point(x: 0, y: 0), in: box, tolerance: 4))

        var run = ExportRun<String>.idle
        _ = (run.begin("png"), run.start(total: 10))
        run.progressed(done: 4)
        run.end(.success(["a.png"]))
        run.dismiss()
        let runs: [ExportRun<String>] = [.editing("png"), .running("png", done: 1, total: 2),
                                         .finished("png", ["a.png"]), .failed("png", "disk full")]
        #expect(Set(runs).count == 4)

        var session = DocumentSession(token: 1)
        session.didEdit(token: 2, at: Date(timeIntervalSince1970: 0))
        session.didSave(token: 2)
        _ = (session.isDirty, session.autosaveDue(now: Date(timeIntervalSince1970: 60), delay: 30))
        #expect(Set([.unsaved, .saved, .saving, .failed("no space"), .readOnly] as [SaveStatus]).count == 5)
        let offer = RecoveryOffer(name: "Poster", savedAt: Date(timeIntervalSince1970: 0))
        #expect(offer.name == "Poster" && !offer.prompt.isEmpty)
        #expect(([.damaged, .missing("version"), .newer(found: 3, supported: 2)] as [VersionError]).count == 3)
        _ = try? VersionedJSON.probe(Data(#"{"version": 2}"#.utf8))
        let damaged = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))
        #expect(!VersionedJSON.words(for: damaged).isEmpty)
    }

    /// KJ0, the kernel shape walk, on the geometry and the EK-3 stubs.
    @Test func kernelShapeWalk() {
        let box = Rect(minX: 10, minY: 20, maxX: 110, maxY: 70)
        #expect(EditorHandle.allCases.filter(\.isCorner).count == 4)
        let moved = Matrix.identity.apply(Point(x: box.minX, y: box.minY))
        #expect(moved.x == 10 && moved.y == 20)
        for handle in EditorHandle.allCases {
            let resized = BoxMath.resized(box, handle, by: Point(x: 5, y: 5), modifiers: .shift)
            #expect(resized.width >= 1 && resized.height >= 1)
        }
        #expect(HandleHit.tolerance(screen: 8, zoom: 1) > 0)
        var run = ExportRun<Int>.idle
        _ = run.begin(1)
        run.dismiss()
        var session = DocumentSession()
        session.didSave(token: 0)
        #expect(!session.isDirty && KernelShape.version >= 1)
    }

    /// Every `public` declaration in the EK-3 files has a `///` line above it.
    @Test func publicSymbolsDocumented() throws {
        let files = ["Keys/Keys.swift", "Keys/KeyRules.swift", "Transform/BoxMath.swift", "Transform/HandleHit.swift",
                     "Export/ExportRun.swift", "Session/DocumentSession.swift", "Session/VersionedJSON.swift"]
        for file in files {
            let url = KernelShapeTests.kernelSources.appendingPathComponent(file)
            let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
            for (i, line) in lines.enumerated() where line.trimmingCharacters(in: .whitespaces).hasPrefix("public ") {
                let above = i > 0 ? lines[i - 1].trimmingCharacters(in: .whitespaces) : ""
                if !above.hasPrefix("///") { Issue.record("Sources/SuiteKernel/\(file):\(i + 1) has no doc line: \(line)") }
            }
        }
    }
}
