// LibraryDevelopBudgetTests.swift: develop's Model budgets (develop packet
// DV-5, enabled by DV-6; Quality tests QB-L2 Model half, paste across many,
// QB-LIB-6 Model half) on the `large` fixture (10,000 photos) and the
// render checks' gradient. One slider sample on one photo within 1 ms debug
// (0.1 ms release); a paste onto 1,000 photos within 50 ms debug (5 ms
// release), one step. The render rows are release only and report-only in
// debug (decision D8): a 512 px preview with every control but Vibrance and
// Saturation within 8 ms, the 2048 px full render within 120 ms, its
// histogram within 10 ms; a miss files the fused-pass core issue (Q3), never
// a looser budget. Each prints a `LIBRARY-BUDGET develop …` line.
//
// The edit rows drive the catalog through `recordEdit` with the packet's
// pseudocode bodies for `setDevelop` and `pasteSettings`, the API on dev
// when this was written; once DV-3 and DV-4 land, the enabling PR calls
// those methods instead. Runs on Linux and macOS.
@testable import LibraryModel
import CoreRaster
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
/// The render rows judge only in release (D8).
private let judgesRenders = false
#else
private let scale = 0.1
private let judgesRenders = true
#endif

@Suite struct LibraryDevelopBudgetTests {
    /// The 10,000-photo catalog with `count` photos selected, in shown order.
    private func large(selecting count: Int) -> (catalog: LibraryCatalog, ids: Set<String>) {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "large"))
        let ids = Set(catalog.order.prefix(count))
        catalog.select(ids)
        return (catalog, ids)
    }

    @Test func setDevelopWithinBudget() {
        var (catalog, ids) = large(selecting: 1)
        #expect(catalog.items.count == 10_000 && ids.count == 1)
        var value = 0.0
        let cost = Budget.measure("develop set-in-10000") {
            value += 0.01
            catalog.recordEdit(DevelopSlider.exposure.rawValue, coalesceKey: "develop-exposure", ids: ids) {
                $0.develop = $0.develop.setting(.exposure, to: value)
            }
        }
        #expect(catalog.history.undo.count == 1)
        #expect(catalog.undoTitle == "Undo Exposure")
        #expect(catalog.items.first { ids.contains($0.id) }?.develop.exposure == value)
        #expect(cost.median <= 1 * scale)
    }

    @Test func pasteManyWithinBudget() {
        var (catalog, ids) = large(selecting: 1_000)
        #expect(ids.count == 1_000)
        let copies = [DevelopSettings.neutral.setting(.exposure, to: 1).setting(.contrast, to: 13),
                      DevelopSettings.neutral.setting(.exposure, to: -1).setting(.whites, to: 20)]
        var run = 0
        let cost = Budget.measure("develop paste-1000-in-10000", runs: 10) {
            let copied = copies[run % 2]
            run += 1
            catalog.recordEdit("Paste Settings", ids: ids) { $0.develop = $0.develop.pastingAdjustments(from: copied) }
            catalog.endCoalescing()
        }
        #expect(catalog.history.undo.count == 10)
        #expect(catalog.history.top?.photos.count == 1_000)
        #expect(catalog.undoTitle == "Undo Paste Settings")
        #expect(cost.median <= 50 * scale)
    }

    @Test func previewRender() throws {
        let buffer = try developGradient(width: 512, height: 341)
        let settings = everyControlButColor()
        let live = LiveDevelop()
        let cost = Budget.measure("develop preview-render-512", runs: judgesRenders ? 20 : 3) {
            _ = try? live.render(buffer, settings: settings)
        }
        #expect(try live.render(buffer, settings: settings) != buffer)
        #expect(!judgesRenders || cost.median <= 8)
    }

    @Test func fullRender() throws {
        let buffer = try developGradient(width: 2048, height: 1365)
        let settings = everyControlButColor()
        let live = LiveDevelop()
        let cost = Budget.measure("develop full-render-2048", runs: judgesRenders ? 10 : 2) {
            _ = try? live.render(buffer, settings: settings)
        }
        #expect(!judgesRenders || cost.median <= 120)
    }

    @Test func histogram() throws {
        let buffer = try developGradient(width: 2048, height: 1365)
        let live = LiveDevelop()
        let cost = Budget.measure("develop histogram-2048", runs: judgesRenders ? 20 : 3) {
            _ = try? live.histogram(of: buffer)
        }
        #expect(try live.histogram(of: buffer) == handHistogram(buffer))
        #expect(!judgesRenders || cost.median <= 10)
    }
}
