// PhotoBudgetTests.swift: the model step of photo-seams' budgets (blueprint
// 7.1, packet S-13) on the `large` fixture (4000 x 3000, three layers, on
// `.fake`): the wall time of the `drag` call one pointer move makes, over 60
// moves of one stroke after its press. PB-2: a clone and a heal move with a
// 64 px dab, median within 1 ms; PB-9: a move-tool move, median within
// 0.1 ms. Both touch pixels or ride on a stroke that does, so per the
// blueprint the median is gated in a release build
// (`swift test -c release --filter PhotoBudgetTests`) and only reported in
// debug, where CoreRaster's per-pixel loops run about 20 times slower. Every
// build prints p50, p95 and max, and a series with fewer than 60 samples
// fails. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

#if DEBUG
/// Debug reports the medians; it gates only the sample count.
private let gated = false
#else
private let gated = true
#endif

/// Pointer moves timed per series.
private let events = 60

@Suite struct PhotoBudgetTests {
    @Test(arguments: [PhotoTool.clone, .heal])
    func cloneHealDab(tool: PhotoTool) throws {
        var workspace = try PhotoWorkspace.fixture(.large)
        workspace.selectTool(tool)
        workspace.setToolOption(.size(64))
        // Option-click sets the source; the stroke then copies from 400 px to its left.
        workspace.drag(from: point(1200, 1500), to: point(1200, 1500), modifiers: [.option])
        workspace.endDrag()
        #expect(workspace.cloneSource?.point == point(1200, 1500))
        let id = try #require(workspace.selectedLayerID)
        let before = workspace.pixels[id]
        let costs = timedMoves(&workspace, from: point(1600, 1500), step: 6)
        workspace.endDrag()
        #expect(workspace.pixels[id] != before, "the \(tool) stroke painted")
        #expect(workspace.undoActionName == (tool == .heal ? "Undo Heal" : "Undo Clone"))
        let series = Series(name: "PB-2 \(tool)", costs: costs)
        #expect(series.samples >= events, "\(series.name): \(series.samples) samples, \(events) needed")
        if gated { #expect(series.p50 <= .milliseconds(1), "\(series.name): median \(series.p50)") }
    }

    @Test func moveDrag() throws {
        var workspace = try PhotoWorkspace.fixture(.large)
        workspace.selectTool(.move)
        let costs = timedMoves(&workspace, from: point(2000, 1500), step: 3)
        workspace.endDrag()
        #expect(workspace.selectedLayer?.offsetX == 3 * events)
        #expect(workspace.undoActionName == "Undo Move Layer")
        let series = Series(name: "PB-9 move", costs: costs)
        #expect(series.samples >= events, "\(series.name): \(series.samples) samples, \(events) needed")
        if gated { #expect(series.p50 <= .microseconds(100), "\(series.name): median \(series.p50)") }
    }
}

/// Presses at `start`, untimed, then times `events` moves of the stroke, each
/// `step` px further right, as the canvas sends them (no modifiers, zoom 1).
private func timedMoves(_ workspace: inout PhotoWorkspace, from start: Mask.Point, step: Double) -> [Duration] {
    let clock = ContinuousClock()
    workspace.drag(from: start, to: start, modifiers: [])
    var costs: [Duration] = []
    costs.reserveCapacity(events)
    for move in 1...events {
        let end = point(start.x + step * Double(move), start.y)
        costs.append(clock.measure { workspace.drag(from: start, to: end, pressure: 1, modifiers: [], zoom: 1) })
    }
    return costs
}

/// A timed series, sorted, printed once with its p50, p95 and max.
private struct Series {
    let name: String, samples: Int, p50: Duration, p95: Duration, max: Duration

    init(name: String, costs: [Duration]) {
        let sorted = costs.sorted()
        self.name = name
        samples = sorted.count
        p50 = sorted.isEmpty ? .zero : sorted[sorted.count / 2]
        p95 = sorted.isEmpty ? .zero : sorted[sorted.count * 95 / 100]
        max = sorted.last ?? .zero
        print("PhotoBudget \(name) p50 \(ms(p50)) ms p95 \(ms(p95)) ms max \(ms(max)) ms (\(samples) events, \(gated ? "gated" : "report only"))")
    }
}

private func ms(_ duration: Duration) -> Double { (duration / .milliseconds(1) * 10_000).rounded() / 10_000 }
