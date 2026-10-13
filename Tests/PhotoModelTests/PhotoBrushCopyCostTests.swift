// PhotoBrushCopyCostTests.swift: a brush drag event on a big image costs
// about the same whether or not another copy of the workspace is alive. The
// window always has one: SwiftUI's State has a get and a set but no in-place
// modify, so PhotoWindow's `model.drag(...)` mutates a copy while State still
// holds the old value, and CanvasRenderer holds one while a render is in
// flight. A drag must then copy only what its dabs touch, not the whole
// layer (Float32 RGBA, 192 MB at 4000 x 3000) and the stroke's canvas-sized
// coverage (48 MB more). Times are medians of interleaved events, so a load
// spike hits both sides alike. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoBrushCopyCostTests {
    @Test func aDragWithACopyAliveCostsAboutWhatOneWithoutDoes() throws {
        var workspace = try whiteImage(4000, 3000)
        workspace.selectTool(.brush)
        // The stroke's first event snapshots the layer for undo; only the
        // events after it are timed.
        var x = 200.0
        workspace.drag(from: point(x, 1500), to: point(x, 1500))
        var alone: [Double] = [], held: [Double] = []
        for event in 0..<22 {
            let copyAlive = event % 2 == 1
            let ms = timedDrag(&workspace, from: &x, holdingCopy: copyAlive)
            guard event >= 4 else { continue }  // warm-up
            if copyAlive { held.append(ms) } else { alone.append(ms) }
        }
        workspace.endDrag()
        let (a, h) = (median(alone), median(held))
        // A 1 ms floor keeps a sub-millisecond optimized dab from turning a
        // few copied tiles into a large ratio.
        #expect(
            h <= 2 * max(a, 1),
            "a drag event took \(h.rounded()) ms with a copy alive vs \(a.rounded()) ms without (median of \(held.count))")
    }
}

/// One 12 px brush drag to the right, timed in milliseconds, with or without
/// a second copy of the workspace alive across it.
private func timedDrag(_ workspace: inout PhotoWorkspace, from x: inout Double, holdingCopy: Bool) -> Double {
    let copy: PhotoWorkspace? = holdingCopy ? workspace : nil
    let (a, b) = (point(x, 1500), point(x + 12, 1500))
    let elapsed = ContinuousClock().measure { workspace.drag(from: a, to: b) }
    withExtendedLifetime(copy) {}
    x += 12
    return elapsed / .milliseconds(1)
}

private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
}
