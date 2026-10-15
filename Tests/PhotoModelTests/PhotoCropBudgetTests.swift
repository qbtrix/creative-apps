// PhotoCropBudgetTests.swift: budget PB-8 (blueprint 7.1, photo-crop CP-3)
// on the `large` fixture (4000 x 3000, three layers) with the live crop
// sizing swapped in (the fake ignores the aspect): the wall time of one
// crop event, over 60 drag moves of one crop stroke after its press and 60
// typed field edits (X, Y, W, H in turn), locked to 3:2 and Free. Each series
// must leave 60 different pending crops, so every timed event did real work.
// The crop touches no pixels, so unlike PhotoBudgetTests the median is gated
// in both builds: within 0.05 ms in release
// (`swift test -c release -Xswiftc -enable-testing --filter
// PhotoCropBudgetTests`, which `@testable` needs) and 0.5 ms in debug,
// which is what CI runs. Every build prints p50, p95 and max, and a series
// with fewer than 60 samples fails. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

#if DEBUG
/// Debug's median bound.
private let budget = Duration.microseconds(500)
#else
/// Release's median bound.
private let budget = Duration.microseconds(50)
#endif

/// Crop events timed per series.
private let events = 60

@Suite struct PhotoCropBudgetTests {
    @Test(arguments: [CropAspect.ratio(3, 2), .free])
    func cropDragAndField(aspect: CropAspect) throws {
        var workspace = try PhotoWorkspace.fixture(.large)
        workspace.services.crop = PhotoServices.live.crop
        workspace.selectTool(.crop)
        workspace.setCropAspect(aspect)

        let drag = timedDrag(&workspace, from: point(500, 400))
        workspace.endDrag()
        check(Series(name: "PB-8 drag \(aspect.title)", costs: drag.costs), crops: drag.crops)

        let field = timedFields(&workspace)
        check(Series(name: "PB-8 field \(aspect.title)", costs: field.costs), crops: field.crops)
        #expect(workspace.undoActionName != "Undo Crop", "a pending crop is not an undo step")
    }

    private func check(_ series: Series, crops: [PixelRect?]) {
        #expect(series.samples >= events, "\(series.name): \(series.samples) samples, \(events) needed")
        #expect(Set(crops.compactMap { $0 }).count == events, "\(series.name): each event gives a new crop")
        #expect(series.p50 <= budget, "\(series.name): median \(series.p50)")
    }
}

/// Presses at `start`, untimed, then times `events` moves of the crop
/// stroke, each 20 px right and 10 px down from the last, as the canvas
/// sends them (no modifiers, zoom 1).
private func timedDrag(_ workspace: inout PhotoWorkspace, from start: Mask.Point)
    -> (costs: [Duration], crops: [PixelRect?])
{
    let clock = ContinuousClock()
    workspace.drag(from: start, to: start, modifiers: [])
    var costs: [Duration] = [], crops: [PixelRect?] = []
    costs.reserveCapacity(events)
    for move in 1...events {
        let end = point(start.x + 20 * Double(move), start.y + 10 * Double(move))
        costs.append(clock.measure { workspace.drag(from: start, to: end, pressure: 1, modifiers: [], zoom: 1) })
        crops.append(workspace.pendingCrop)
    }
    return (costs, crops)
}

/// Times `events` typed fields on the pending crop, X, Y, W and H in turn,
/// each value 7 px past that field's last.
private func timedFields(_ workspace: inout PhotoWorkspace) -> (costs: [Duration], crops: [PixelRect?]) {
    let clock = ContinuousClock()
    let fields: [CropField] = [.x, .y, .width, .height]
    var costs: [Duration] = [], crops: [PixelRect?] = []
    costs.reserveCapacity(events)
    for edit in 0..<events {
        let field = fields[edit % fields.count]
        let value = (field == .x || field == .y ? 100 : 400) + 7 * edit
        costs.append(clock.measure { workspace.setCropField(field, to: value) })
        crops.append(workspace.pendingCrop)
    }
    return (costs, crops)
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
        print("PhotoBudget \(name) p50 \(ms(p50)) ms p95 \(ms(p95)) ms max \(ms(max)) ms (\(samples) events, gated)")
    }
}

private func ms(_ duration: Duration) -> Double { (duration / .milliseconds(1) * 10_000).rounded() / 10_000 }
