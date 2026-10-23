// PhotoExportRunTests.swift: Photo's Export sheet on the kernel's ExportRun
// (adopt-kernel-export AX-photo): Export… opens it only on an image, Export
// starts one write, the write's outcome ends the run, and Cancel closes the
// sheet but never a running write. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoExportRunTests {
    private struct DiskFull: Error {}

    private let jpeg = ExportOptions(format: .jpeg, quality: 0.7)

    /// An open image with the sheet up and Export pressed on `jpeg`.
    private func running() throws -> PhotoWorkspace {
        var workspace = try whiteImage(4, 4)
        let opened = workspace.openExport()
        #expect(opened)
        let started = workspace.startExport(jpeg)
        #expect(started)
        return workspace
    }

    @Test func exportOpensOnlyOnAnImage() throws {
        var empty = PhotoWorkspace()
        let refused = empty.openExport()
        #expect(!refused)
        #expect(empty.exportRun == .idle)
        #expect(!empty.isExportSheetOpen)

        var workspace = try whiteImage(4, 4)
        let opened = workspace.openExport()
        #expect(opened)
        #expect(workspace.exportRun == .editing(workspace.exportOptions))
        #expect(workspace.isExportSheetOpen)
        #expect(!workspace.isExportRunning)
    }

    @Test func exportStartsOneWriteOnTheChosenOptions() throws {
        var workspace = try running()
        #expect(workspace.exportRun == .running(jpeg, done: 0, total: 1))
        #expect(workspace.isExportRunning)
        #expect(!workspace.isExportSheetOpen)
        #expect(workspace.exportOptions == jpeg)
        let started = workspace.startExport(jpeg)
        #expect(!started)
        let opened = workspace.openExport()
        #expect(!opened)
        #expect(workspace.exportRun == .running(jpeg, done: 0, total: 1))
    }

    @Test func exportWithNoSheetIsRefused() throws {
        var workspace = try whiteImage(4, 4)
        let started = workspace.startExport(jpeg)
        #expect(!started)
        #expect(workspace.exportRun == .idle)
        #expect(workspace.exportOptions == ExportOptions())
    }

    @Test func aWrittenFileFinishesTheRun() throws {
        var workspace = try running()
        workspace.endExport(.success(["two.jpg"]))
        #expect(workspace.exportRun == .finished(jpeg, ["two.jpg"]))
        #expect(!workspace.isExportRunning)
        let opened = workspace.openExport()
        #expect(opened)
        #expect(workspace.exportRun == .editing(jpeg))
    }

    @Test func aCancelledSavePanelGoesIdle() throws {
        var workspace = try running()
        workspace.endExport(.failure(CancellationError()))
        #expect(workspace.exportRun == .idle)
    }

    @Test func aFailedWriteFailsTheRun() throws {
        var workspace = try running()
        workspace.endExport(.failure(DiskFull()))
        guard case .failed(let o, _) = workspace.exportRun else {
            Issue.record("expected failed, got \(workspace.exportRun)")
            return
        }
        #expect(o == jpeg)
        #expect(!workspace.isExportRunning)
    }

    @Test func cancelClosesTheSheetButNeverARunningWrite() throws {
        var workspace = try whiteImage(4, 4)
        workspace.openExport()
        workspace.dismissExport()
        #expect(workspace.exportRun == .idle)

        var writing = try running()
        writing.dismissExport()
        #expect(writing.isExportRunning)
    }
}
