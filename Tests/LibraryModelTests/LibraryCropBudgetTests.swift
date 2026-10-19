// LibraryCropBudgetTests.swift: crop CR-3, the crop's Model budgets (slice
// CR-b; Quality tests QB-L1 Model half and the cropped render), written
// first; CR-4 builds `LiveCrop` and enables them. On the live services with
// `IMG_0001` (6000 × 4000) at 1:1: one `dragCrop` within 2 ms debug (0.2 ms
// release) and one `setCropAngle` within 2 ms (0.2 ms release), neither
// recording a step. The 2048 px render at 1:1 and 5° through `LiveDevelop`
// is report-only in debug (decision D8) and within 120 ms in release. Each
// prints a `LIBRARY-BUDGET crop …` line. Runs on Linux and macOS.
@testable import LibraryModel
import CoreRaster
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
/// The render row judges only in release (D8).
private let judgesRenders = false
#else
private let scale = 0.1
private let judgesRenders = true
#endif

@Suite
struct LibraryCropBudgetTests {
    /// The live loupe on `IMG_0001` with a 1:1 draft.
    private func squareDraft() -> LibraryCatalog {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        return catalog
    }

    @Test func dragWithinBudget() throws {
        var catalog = squareDraft()
        #expect(catalog.cropFrameValue?.hasPrefix("4000 × 4000") == true)
        var run = 0
        let cost = Budget.measure("crop drag-6000", runs: 50) {
            let step = run % 2 == 0 ? 40.0 : -40.0
            run += 1
            catalog.dragCrop(.topLeft, dx: step, dy: step * 0.5)
        }
        let frame = try #require(catalog.cropFrame)
        #expect(abs(frame.width - frame.height) <= 1)
        #expect(catalog.history.undo.isEmpty)
        #expect(cost.median <= 2 * scale)
    }

    @Test func angleWithinBudget() throws {
        var catalog = squareDraft()
        var run = 0
        let cost = Budget.measure("crop angle-6000", runs: 50) {
            run += 1
            catalog.setCropAngle(Double(run % 90) - 44.5)
        }
        let draft = try #require(catalog.cropDraft)
        #expect(CropSettings.angleRange.contains(draft.angle) && draft.angle != 0)
        #expect(catalog.history.undo.isEmpty)
        #expect(cost.median <= 2 * scale)
    }

    @Test func croppedRenderReport() throws {
        let buffer = try developGradient(width: 2048, height: 1365)
        let size = PixelSize(width: buffer.width, height: buffer.height)
        let square = try cropLiveGeometry().initial(aspect: .square, angle: 5, photo: size)
        let settings = DevelopSettings.neutral.setting(crop: square)
        let live = LiveDevelop()
        let cost = Budget.measure("crop render-2048-square-5", runs: judgesRenders ? 10 : 2) {
            _ = try? live.render(buffer, settings: settings)
        }
        let out = try live.render(buffer, settings: settings)
        #expect(abs(out.width - out.height) <= 1 && out.width < 1365)
        #expect(!judgesRenders || cost.median <= 120)
    }
}
