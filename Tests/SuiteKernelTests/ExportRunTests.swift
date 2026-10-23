// ExportRunTests.swift (editor-kernel EK-21, slice EK-run): checks first for
// the one export run. Every transition, progress that never goes back and
// never passes the total, cancel back to idle, and dismiss. On since EK-22
// wrote ExportRun's body; KJ7 is this module's walk.
import Foundation
import Testing
import SuiteKernel

/// The packet's `ExportRunSteps` fixture, kept here: a run of ten steps whose
/// progress reports arrive out of order and past the end, and what the run
/// must read after each one.
enum ExportRunSteps {
    static let total = 10
    static let reports = [1, 3, 2, 3, 7, 6, 12, 4]
    static let readouts = [1, 3, 3, 3, 7, 7, 10, 10]
}

private struct DiskFull: Error, CustomStringConvertible {
    var description: String { "The disk is full." }
}

@Suite struct ExportRunTests {
    private func running(_ total: Int = ExportRunSteps.total) -> ExportRun<String> {
        var run = ExportRun<String>.idle
        _ = run.begin("png")
        _ = run.start(total: total)
        return run
    }

    private func done(_ run: ExportRun<String>) -> Int? {
        if case .running(_, let done, _) = run { return done }
        return nil
    }

    @Test func beginOpensTheSheet() {
        var run = ExportRun<String>.idle
        let opened = run.begin("png")
        #expect(opened && run == .editing("png"))
        let reopened = run.begin("svg")
        #expect(reopened)
        #expect(run == .editing("svg"))
    }

    @Test func startRunsFromEditingOnly() {
        var idle = ExportRun<String>.idle
        let fromIdle = idle.start(total: 5)
        #expect(!fromIdle)
        #expect(idle == .idle)
        var run = ExportRun<String>.editing("png")
        let started = run.start(total: 5)
        #expect(started)
        #expect(run == .running("png", done: 0, total: 5))
        let restarted = run.start(total: 9)
        #expect(!restarted)
        #expect(run == .running("png", done: 0, total: 5))
    }

    @Test func beginRefusedWhileRunning() {
        var run = running()
        let opened = run.begin("svg")
        #expect(!opened)
        #expect(run == .running("png", done: 0, total: ExportRunSteps.total))
    }

    @Test func progressNeverBack() {
        var run = running()
        var seen: [Int] = []
        for report in ExportRunSteps.reports {
            run.progressed(done: report)
            seen.append(done(run) ?? -1)
        }
        #expect(seen == ExportRunSteps.readouts)
        #expect(zip(seen, seen.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test func clampsToTotal() {
        var run = running(4)
        run.progressed(done: 99)
        #expect(run == .running("png", done: 4, total: 4))
        run.progressed(done: -3)
        #expect(run == .running("png", done: 4, total: 4))
    }

    @Test func progressIgnoredOutsideARun() {
        for start: ExportRun<String> in [.idle, .editing("png"), .finished("png", ["a.png"]), .failed("png", "no")] {
            var run = start
            run.progressed(done: 3)
            #expect(run == start)
        }
    }

    @Test func successFinishesWithTheFiles() {
        var run = running()
        run.progressed(done: 10)
        run.end(.success(["a.png", "b.png"]))
        #expect(run == .finished("png", ["a.png", "b.png"]))
    }

    @Test func errorFailsInWords() {
        var run = running()
        run.end(.failure(DiskFull()))
        guard case .failed(let options, let words) = run else {
            Issue.record("a failed write read \(run)")
            return
        }
        #expect(options == "png" && !words.isEmpty)
    }

    @Test func cancelReturnsToIdle() {
        var run = running()
        run.progressed(done: 3)
        run.end(.failure(CancellationError()))
        #expect(run == .idle)
    }

    @Test func endIgnoredOutsideARun() {
        var run = ExportRun<String>.editing("png")
        run.end(.success(["a.png"]))
        #expect(run == .editing("png"))
    }

    @Test func dismissClosesTheSheet() {
        for start: ExportRun<String> in [.editing("png"), .finished("png", ["a.png"]), .failed("png", "no")] {
            var run = start
            run.dismiss()
            #expect(run == .idle)
        }
        var run = running()
        run.dismiss()
        #expect(run == .running("png", done: 0, total: ExportRunSteps.total))
    }

    @Test func reopensAfterFinishing() {
        var run = ExportRun<String>.finished("png", ["a.png"])
        let opened = run.begin("svg")
        #expect(opened)
        #expect(run == .editing("svg"))
    }

    /// KJ7, the export run walk: open, write ten steps with reports out of
    /// order, finish, dismiss; then a second run cancelled midway.
    @Test func exportRunWalk() {
        var run = ExportRun<String>.idle
        let first = run.begin("png") && run.start(total: ExportRunSteps.total)
        #expect(first)
        for report in ExportRunSteps.reports { run.progressed(done: report) }
        #expect(run == .running("png", done: ExportRunSteps.total, total: ExportRunSteps.total))
        run.end(.success(["frame-1.png"]))
        #expect(run == .finished("png", ["frame-1.png"]))
        run.dismiss()
        #expect(run == .idle)
        let second = run.begin("svg") && run.start(total: 3)
        #expect(second)
        run.progressed(done: 1)
        run.end(.failure(CancellationError()))
        #expect(run == .idle)
    }
}
