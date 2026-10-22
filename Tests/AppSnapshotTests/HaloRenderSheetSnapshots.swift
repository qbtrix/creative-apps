// HaloRenderSheetSnapshots.swift: File > Render… on SuiteUI's export sheet
// (core-loop CL-4, #1971) on `keyed` with the fakes, each state set through
// the Model's kernel methods on CL-2's stubs: editing (PNG sequence, Half,
// the summary), running at "Frame 12 of 48", finished and failed at frame 5.
// The control inventory stands in for the accessibility tree, so a state
// missing a control fails; the readout pins the rows the sheet draws. Light
// and Dark: halo-render-sheet-*.png. macOS only.
import AppKit
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

@MainActor
@Suite struct HaloRenderSheetSnapshots {
    private let folder = URL(fileURLWithPath: "/nonexistent/Renders", isDirectory: true)
    private let half = HaloRenderSettings(format: .pngSequence, halfSize: true)

    private func editing() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let began = project.beginRender(HaloRenderSettings(format: .pngSequence))
        #expect(began)
        project.setRenderSettings(half)
        return project
    }

    private func running() throws -> HaloProject {
        var project = try editing()
        let started = project.startRender()
        _ = try #require(started)
        project.renderProgressed(done: 12)
        return project
    }

    private func sheet(_ project: HaloProject, output: URL? = nil) -> HaloRenderExportAdapter {
        HaloRenderExportAdapter(model: project, destination: folder, output: output) { _ in }
    }

    private func controls(_ sheet: HaloRenderExportAdapter) throws -> [String: ControlEntry] {
        let store = SuiteControlStore()
        _ = try #require(render(sheet.environment(\.suiteControlStore, store), scheme: .light))
        return Dictionary(store.inventory.document().controls.map { ($0.id, $0) }) { a, _ in a }
    }

    private func shoot(_ sheet: HaloRenderExportAdapter, _ name: String) throws {
        try snapshot(sheet, name: "halo-render-sheet\(name)-light", scheme: .light)
        try snapshot(sheet, name: "halo-render-sheet\(name)-dark", scheme: .dark)
    }

    @Test func editingState() throws {
        let project = try editing()
        #expect(project.renderRun == .editing(half))
        #expect(project.renderSummary(half, existing: []) == "48 PNG files, 960 × 540, into a new folder \"Bounce\"")
        let view = sheet(project)
        // Size is the Full and Half chips in the options rows; the kernel's 0.25x-4x scrub would offer scales Halo has not got.
        #expect(view.readout.rows == [.format("pngSequence")])
        #expect(view.readout.editable)
        #expect(HaloRenderExportAdapter.formats.map { ExportSheetIDs("halo.render").format($0.id) }
            == ["halo.render.format.pngSequence", "halo.render.format.movie"])
        let found = try controls(view)
        #expect(Set(found.keys) == ["halo.render.cancel", "halo.render.destination", "halo.render.format", "halo.render.start"])
        #expect(found["halo.render.start"]?.enabled == true)
        #expect(found["halo.render.destination"]?.enabled == true)
        try shoot(view, "")
    }

    @Test func progress() throws {
        let project = try running()
        #expect(project.renderRun == .running(half, done: 12, total: 48))
        #expect(project.renderProgressText == "Frame 12 of 48")
        let view = sheet(project)
        #expect(view.readout.progress == ExportProgress(done: 12, total: 48))
        let found = try controls(view)
        #expect(found["halo.render.cancel"]?.enabled == true)
        #expect(found["halo.render.start"]?.enabled == false)
        #expect(found["halo.render.destination"]?.enabled == false)
        #expect(found["halo.render.dismiss"] == nil)
        try shoot(view, "-progress")
    }

    @Test func done() throws {
        var project = try running()
        project.endRender(.finished(frames: 48))
        #expect(project.renderOutcomeText == "Rendered 48 frames.")
        let view = sheet(project, output: folder.appending(path: "Bounce"))
        #expect(view.readout.line == .finished("Exported Bounce"))
        let found = try controls(view)
        #expect(found["halo.render.dismiss"]?.enabled == true)
        #expect(found["halo.render.reveal"]?.enabled == true)
        #expect(found["halo.render.cancel"] == nil)
        #expect(found["halo.render.tryAgain"] == nil)
        try shoot(view, "-done")
    }

    @Test func failed() throws {
        var project = try running()
        project.endRender(.failed(frame: 5, message: "Disk full"))
        #expect(project.renderRun == .failed(half, "Render stopped at frame 5: Disk full."))
        let view = sheet(project)
        #expect(view.readout.line == .failed("Render stopped at frame 5: Disk full."))
        let found = try controls(view)
        #expect(found["halo.render.dismiss"]?.enabled == true)
        #expect(found["halo.render.tryAgain"]?.enabled == true)
        #expect(found["halo.render.reveal"] == nil)
        try shoot(view, "-failed")
    }

    @Test func progressSinkCountsEveryWrittenFrame() throws {
        let project = try editing()
        let composition = try #require(project.selectedComposition)
        let plan = try project.services.compositionRendering.plan(composition, settings: half)
        var counts: [Int] = []
        var sink = HaloRenderProgress(base: Recorder()) { counts.append($0) }
        let outcome = project.services.compositionRendering.run(
            plan, of: composition, text: nil, into: &sink, isCancelled: { false })
        #expect(outcome == .finished(frames: 48))
        #expect(counts == Array(1...48))
        #expect(sink.base.names == plan.fileNames)
    }
}

private struct Recorder: RenderSink {
    var names: [String] = []
    mutating func begin(_ plan: HaloRenderPlan) {}
    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) { names.append(fileName) }
    mutating func finish(cancelled: Bool) {}
}
