// HaloRenderSheetSnapshots.swift: the Render sheet (render-out RO-8) on
// `keyed` with the fakes, each stage set through the Model's public methods:
// settings (PNG, Half, summary), "Frame 12 of 48", finished, and failed at
// frame 5. The control inventory stands in for the accessibility tree, so a
// stage missing a control, or Render on with no folder, fails. Light and
// Dark: halo-render-sheet-*.png. macOS only.
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

@MainActor
@Suite struct HaloRenderSheetSnapshots {
    private let folder = URL(fileURLWithPath: "/nonexistent/Renders", isDirectory: true)
    private let half = HaloRenderSettings(format: .pngSequence, halfSize: true)

    private func opened() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        project.openRenderSheet()
        return project
    }

    private func running() throws -> HaloProject {
        var project = try opened()
        let started = project.startRender(half)
        _ = try #require(started)
        project.renderProgress(frame: 12)
        return project
    }

    private func controls(_ sheet: HaloRenderSheet) throws -> [ControlEntry] {
        let store = SuiteControlStore()
        _ = try #require(render(sheet.environment(\.suiteControlStore, store), scheme: .light))
        return store.inventory.document().controls
    }

    private func shoot(_ sheet: HaloRenderSheet, _ name: String) throws {
        try snapshot(sheet, name: "halo-render-sheet\(name)-light", scheme: .light)
        try snapshot(sheet, name: "halo-render-sheet\(name)-dark", scheme: .dark)
    }

    @Test func settings() throws {
        let project = try opened()
        let sheet = HaloRenderSheet(model: project, destination: folder, initial: half)
        #expect(sheet.stage == .settings)
        #expect(sheet.renderHelp == nil)
        #expect(project.renderSummary(half, existing: []) == "48 PNG files, 960 × 540, into a new folder \"Bounce\"")
        #expect(try controls(sheet) == [
            ControlEntry(id: "halo.render.cancel", enabled: true),
            ControlEntry(id: "halo.render.destination", enabled: true),
            ControlEntry(id: "halo.render.format", enabled: true),
            ControlEntry(id: "halo.render.size", enabled: true),
            ControlEntry(id: "halo.render.start", enabled: true),
        ])
        try shoot(sheet, "")
        let none = HaloRenderSheet(model: project, destination: nil, initial: half)
        let start = try controls(none).first { $0.id == "halo.render.start" }
        #expect(start == ControlEntry(id: "halo.render.start", enabled: false, reason: HaloRenderSheet.noDestination))
    }

    @Test func progress() throws {
        let project = try running()
        #expect(project.renderProgressText == "Frame 12 of 48")
        let sheet = HaloRenderSheet(model: project, destination: folder)
        #expect(sheet.stage == .running)
        #expect(try controls(sheet) == [ControlEntry(id: "halo.render.cancel", enabled: true)])
        try shoot(sheet, "-progress")
    }

    @Test func done() throws {
        var project = try running()
        project.finishRender(.finished(frames: 48))
        #expect(project.renderOutcomeText == "Rendered 48 frames.")
        let sheet = HaloRenderSheet(model: project, destination: folder, output: folder.appending(path: "Bounce"))
        #expect(sheet.stage == .ended)
        #expect(try controls(sheet) == [
            ControlEntry(id: "halo.render.close", enabled: true),
            ControlEntry(id: "halo.render.reveal", enabled: true),
        ])
        try shoot(sheet, "-done")
    }

    @Test func failed() throws {
        var project = try running()
        project.finishRender(.failed(frame: 5, message: "Disk full"))
        #expect(project.renderOutcomeText == "Render stopped at frame 5: Disk full.")
        let sheet = HaloRenderSheet(model: project, destination: folder)
        #expect(sheet.stage == .failed)
        #expect(try controls(sheet) == [ControlEntry(id: "halo.render.close", enabled: true)])
        try shoot(sheet, "-failed")
    }

    @Test func progressSinkCountsEveryWrittenFrame() throws {
        let project = try opened()
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
