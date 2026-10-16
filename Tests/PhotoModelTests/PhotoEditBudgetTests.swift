// PhotoEditBudgetTests.swift: photo-edit's budgets (blueprint 7.1, packet
// E-5) on the `large` fixture (4000 x 3000, three layers) with the live
// clipboard and merging swapped in. PB-15: one Copy of the whole 12 MP
// "Noise" layer and its Paste in place, timed together, within 120 ms; the
// paste fits `maxOpenPixels`, so no resize runs. PB-16: Merge Down of "Noise"
// onto "Gradient" (two 12 MP layers) and Flatten Image of all three, each
// within 400 ms. All three run in one test, one after another, on one
// workspace. Each timed call is undone, untimed, before the next, so
// every round starts from the same stack. All three touch every pixel, so as
// in PhotoBudgetTests the median is gated in a release build
// (`swift test -c release -Xswiftc -enable-testing --filter
// PhotoEditBudgetTests`, which `@testable` needs to swap the services) and
// only reported in debug, which is what CI runs. Every build prints p50,
// p95 and max, and a series with fewer than `rounds` samples fails. Debug
// does not compare copy and paste with Merge Down: Merge Down is fast now
// (#1198, #1250), and copy and paste is bounded by CoreRaster's per-pixel
// 8-bit conversion (creative-core#309), so in debug their order is a coin
// flip, not a property of the code. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

#if DEBUG
/// Debug reports the medians; it gates only the sample count.
private let gated = false
/// Timed calls per series. Debug's per-pixel loops make one round cost
/// minutes (Merge Down about 65 s, Flatten about 97 s on a Linux worker), so
/// CI's debug run times one of each.
private let rounds = 1
#else
private let gated = true
/// Timed calls per series; each is a whole-image pass, so fewer than the
/// per-move budgets' 60.
private let rounds = 5
#endif

@Suite struct PhotoEditBudgetTests {
    /// One test, so the series share a workspace and never time each other.
    @Test func editBudgets() throws {
        var workspace = try PhotoWorkspace.fixture(.large)
        workspace.services.clipboard = PhotoServices.live.clipboard
        workspace.services.merging = PhotoServices.live.merging
        let copyPaste = copyPaste(&workspace)
        let (merge, flatten) = mergeFlatten(&workspace)
        check(copyPaste, within: .milliseconds(120))
        check(merge, within: .milliseconds(400))
        check(flatten, within: .milliseconds(400))
    }

    private func copyPaste(_ workspace: inout PhotoWorkspace) -> Series {
        let names = workspace.layers.map(\.name)
        #expect(workspace.selectedLayer?.name == "Noise")
        let clock = ContinuousClock()
        var costs: [Duration] = []
        for _ in 0..<rounds {
            var copied: ClipboardImage?
            let cost = clock.measure {
                copied = workspace.copySelection()
                if let copied { workspace.paste(copied, viewCenter: point(2000, 1500)) }
            }
            #expect(copied?.image.width == 4000 && copied?.image.height == 3000, "copied the whole layer")
            #expect(workspace.selectedLayer?.name == "Pasted Layer")
            #expect(workspace.selectedLayer?.offsetX == 0 && workspace.selectedLayer?.offsetY == 0, "pasted in place")
            #expect(workspace.statusMessage == nil, "no resize note: \(workspace.statusMessage ?? "")")
            #expect(workspace.undoActionName == "Undo Paste")
            if copied != nil, workspace.layers.count == names.count + 1 { costs.append(cost) }
            workspace.undo()
            #expect(workspace.layers.map(\.name) == names)
        }
        return Series(name: "PB-15 copy and paste", costs: costs)
    }

    private func mergeFlatten(_ workspace: inout PhotoWorkspace) -> (merge: Series, flatten: Series) {
        let names = workspace.layers.map(\.name)
        #expect(names == ["Noise", "Gradient", "Background"])
        let clock = ContinuousClock()
        var merges: [Duration] = [], flattens: [Duration] = []
        for _ in 0..<rounds {
            let merge = clock.measure { workspace.mergeDown() }
            #expect(workspace.layers.map(\.name) == ["Gradient", "Background"])
            #expect(workspace.undoActionName == "Undo Merge Down")
            if workspace.layers.count == 2 { merges.append(merge) }
            workspace.undo()
            #expect(workspace.layers.map(\.name) == names)

            let flatten = clock.measure { workspace.flattenImage() }
            #expect(workspace.layers.map(\.name) == ["Background"])
            #expect(workspace.undoActionName == "Undo Flatten Image")
            if workspace.layers.count == 1 { flattens.append(flatten) }
            workspace.undo()
            #expect(workspace.layers.map(\.name) == names)
            #expect(workspace.selectedLayer?.name == "Noise", "undo selects Noise again for the next Merge Down")
        }
        return (Series(name: "PB-16 merge down", costs: merges), Series(name: "PB-16 flatten", costs: flattens))
    }

    private func check(_ series: Series, within budget: Duration) {
        #expect(series.samples >= rounds, "\(series.name): \(series.samples) samples, \(rounds) needed")
        if gated { #expect(series.p50 <= budget, "\(series.name): median \(series.p50)") }
    }
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
