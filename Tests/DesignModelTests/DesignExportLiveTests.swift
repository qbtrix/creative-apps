// DesignExportLiveTests.swift: DesignExportLive, the loop the live export
// runs (design-export DE-10, DE-11): in order, progress after each written
// file, Cancel checked before each file and again between its render and its
// write, and the first render or write that throws stops the run naming that
// file. Then the lines the sheet and the status line read: the finished line
// names the written files, the failed line says how to fix it. Linux and macOS.
import DesignModel
import Testing

private struct DiskFull: Error, CustomStringConvertible {
    var description: String { "The disk is full." }
}

@Suite struct DesignExportLiveTests {
    @Test func writesEachFileInOrderAndCountsEachStep() async {
        var wrote: [String] = [], steps: [Int] = []
        let outcome = await DesignExportLive.run(
            ["a", "b", "c"], name: { "\($0).png" }, render: { $0.uppercased() },
            write: { payload, item in wrote.append("\(item):\(payload)") }, progressed: { steps.append($0) })
        #expect(wrote == ["a:A", "b:B", "c:C"])
        #expect(steps == [1, 2, 3])
        #expect(outcome.written == ["a.png", "b.png", "c.png"])
        #expect(outcome.failed == nil && !outcome.cancelled)
    }

    @Test func aFailingWriteStopsTheRunAndNamesItsFile() async {
        var wrote: [String] = [], steps: [Int] = []
        let outcome = await DesignExportLive.run(
            ["a", "b", "c"], name: { "\($0).png" }, render: { $0 },
            write: { _, item in
                if item == "b" { throw DiskFull() }
                wrote.append(item)
            }, progressed: { steps.append($0) })
        #expect(wrote == ["a"])
        #expect(steps == [1])
        #expect(outcome.written == ["a.png"])
        #expect(outcome.failed?.file == "b.png")
        #expect(outcome.failed.map { String(describing: $0.error) } == "The disk is full.")
        #expect(!outcome.cancelled)
    }

    @Test func aRenderThatThrowsFailsLikeAWrite() async {
        let outcome = await DesignExportLive.run(
            ["a"], name: { "\($0).png" }, render: { (_: String) throws -> String in throw DiskFull() },
            write: { _, _ in }, progressed: { _ in })
        #expect(outcome.written.isEmpty && outcome.failed?.file == "a.png")
    }

    @Test func aCancelBeforeAFileRendersAndWritesNothingMore() async {
        var wrote: [String] = [], rendered: [String] = []
        let outcome = await DesignExportLive.run(
            ["a", "b", "c"], name: { "\($0).png" },
            render: { item in
                rendered.append(item)
                return item
            },
            write: { _, item in wrote.append(item) },
            isCancelled: { wrote.count == 1 }, progressed: { _ in })
        #expect(rendered == ["a"], "a file after Cancel was rendered")
        #expect(wrote == ["a"])
        #expect(outcome.written == ["a.png"] && outcome.cancelled && outcome.failed == nil)
    }

    @Test func aCancelDuringARenderSkipsThatWrite() async {
        var wrote: [String] = [], cancelled = false
        let outcome = await DesignExportLive.run(
            ["a", "b"], name: { "\($0).png" },
            render: { item in
                if item == "b" { cancelled = true }
                return item
            },
            write: { _, item in wrote.append(item) },
            isCancelled: { cancelled }, progressed: { _ in })
        #expect(wrote == ["a"])
        #expect(outcome.written == ["a.png"] && outcome.cancelled)
    }

    @Test func nothingToWriteIsAnEmptyFinishedRun() async {
        let outcome = await DesignExportLive.run(
            [String](), name: { $0 }, render: { $0 }, write: { _, _ in }, progressed: { _ in })
        #expect(outcome.written.isEmpty && outcome.failed == nil && !outcome.cancelled)
    }

    @Test func theFinishedLineNamesTheFolderAndTheFiles() {
        #expect(DesignExportLive.finished(["Desktop 2.png"], folder: "Exports") == "Exported 1 file to Exports: Desktop 2.png.")
        #expect(DesignExportLive.finished(["A.png", "B.png"], folder: "Out") == "Exported 2 files to Out: A.png and B.png.")
        #expect(DesignExportLive.finished(["A.png", "B.png", "C.png", "D.png", "E.png"], folder: "Out")
                == "Exported 5 files to Out: A.png, B.png, C.png and 2 more.")
    }

    @Test func theFailedLineSaysHowToFixIt() {
        #expect(DesignExportLive.failed("Desktop 3.png", reason: "You don't have permission.")
                == "Desktop 3.png couldn't be written. You don't have permission. Choose another folder and export again.")
    }
}

