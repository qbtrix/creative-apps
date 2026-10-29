// FlareLayersFilesBudgetTests.swift: the layers-files quality gate's real-size timing (#5841). On a scene with
// 2,000 layers, each sidebar action a click or a row menu runs (eye, lock, rename, reorder, duplicate, delete, undo)
// and one list update's row menus and dimmed reads for a window of shown rows stay within one frame: p95 at or under
// 8 ms on an optimized build (`swift test -c release -Xswiftc -DDEBUG --filter FlareLayersFilesBudgetTests`; the
// app test targets need DEBUG to compile). The budget follows the optimization level, not DEBUG: an unoptimized
// build only catches a blow-up. Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

/// True in an unoptimized build: `assert` only evaluates its condition there.
private let unoptimized: Bool = {
    var on = false
    assert({ on = true; return true }())
    return on
}()
private let budget = Duration.milliseconds(unoptimized ? 200 : 8)

private let count = 2_000
private let runs = 20

@Suite struct FlareLayersFilesBudgetTests {
    /// One scene with layer-1 ... layer-2000, on fakes.
    static func big() -> FlareWorkspace {
        let layers = (1...count).map { Layer(id: "layer-\($0)", name: "Layer \($0)") }
        var w = FlareWorkspace(services: .fake())
        w.load(Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: layers)]))
        return w
    }

    private func p95(_ label: String, setup: (inout FlareWorkspace) -> Void = { _ in },
                     _ step: (inout FlareWorkspace, Int) -> Void) {
        var w = Self.big()
        setup(&w)
        #expect(w.layers.count == count)
        let clock = ContinuousClock()
        var costs = (0..<runs).map { i in clock.measure { step(&w, i) } }
        costs.sort()
        let p95 = costs[runs * 95 / 100 - 1]
        print("\(label) at \(count) layers: p50 \(costs[runs / 2]) p95 \(p95) budget \(budget)")
        #expect(w.layerError == nil, "\(label)")
        #expect(p95 <= budget, "\(label)")
    }

    @Test func eyeAndLock() {
        p95("LayersEye") { w, i in w.toggleLayerFlag("layer-\(i + 1)", .visible) }
        p95("LayersLock") { w, i in w.toggleLayerFlag("layer-\(i + 1)", .locked) }
    }

    @Test func renameAndReorder() {
        p95("LayersRename") { w, i in w.renameLayer("layer-\(i + 1)", to: "Hero \(i)") }
        p95("LayersReorder") { w, i in w.moveLayer(from: i, to: count - i) }
    }

    @Test func duplicateDeleteAndUndo() {
        p95("LayersDuplicate") { w, i in w.duplicateLayer("layer-\(i + 1)") }
        p95("LayersDelete") { w, i in w.removeLayer("layer-\(i + 1)") }
        p95("LayersUndo", setup: { w in for n in 1...runs { w.renameLayer("layer-\(n)", to: "R\(n)") } }) { w, _ in
            w.undo()
        }
    }

    /// One list update builds the menu and the dimmed state of each shown row: 40 rows, from the middle.
    @Test func rowMenusForShownRows() {
        p95("LayersRowMenus") { w, i in
            for n in (1_000 + i)..<(1_040 + i) {
                _ = w.layerRowMenu("layer-\(n)")
                _ = w.layerRowIsDimmed("layer-\(n)")
            }
        }
    }
}
