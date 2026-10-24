// HaloRenderSheetSnapshots.swift: File > Render… on SuiteUI's export sheet
// (core-loop CL-4, #1971) on `keyed` with the fakes, each state set through
// the Model's kernel methods on CL-2's stubs: editing (PNG sequence, Half,
// the summary), editing into a folder with a 40-character name (one line,
// middle-truncated, at the Size row's inset), running at "Frame 12 of 48",
// finished ("Exported 48 PNG files into "Bounce"", the folder name dimmed
// with the sheet) and failed at frame 5. The summary, problem and progress
// notes start at the Folder label's x (#4454), and while busy the folder
// control's help is the Export button's words (#4457).
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

    private func sheet(_ project: HaloProject, output: URL? = nil, into destination: URL? = nil) -> HaloRenderExportAdapter {
        HaloRenderExportAdapter(model: project, destination: destination ?? folder, output: output) { _ in }
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
        // HX-2's checkbox shows for a PNG sequence too; the Codec row only for a movie.
        #expect(Set(found.keys) == ["halo.render.alpha", "halo.render.cancel", "halo.render.destination", "halo.render.format", "halo.render.start"])
        #expect(found["halo.render.start"]?.enabled == true)
        #expect(found["halo.render.destination"]?.enabled == true)
        try shoot(view, "")
    }

    @Test func longFolderName() throws {
        let long = URL(fileURLWithPath: "/nonexistent/halo-render-A775E2C6-0D1F-4B7A-9E21-3C4D", isDirectory: true)
        #expect(long.lastPathComponent.count == 40)
        let view = sheet(try editing(), into: long)
        let found = try controls(view)
        #expect(found["halo.render.destination"]?.enabled == true)
        try shoot(view, "-long-folder")
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
        // One busy state, one name: the folder control's help is the Export button's (#4457).
        #expect(found["halo.render.start"]?.reason == "The export is already under way or done.")
        #expect(found["halo.render.destination"]?.reason == found["halo.render.start"]?.reason)
        #expect(found["halo.render.dismiss"] == nil)
        try shoot(view, "-progress")
    }

    @Test func done() throws {
        var project = try running()
        project.endRender(.finished(frames: 48))
        #expect(project.renderOutcomeText == "Rendered 48 frames.")
        let view = sheet(project, output: folder.appending(path: "Bounce"))
        #expect(project.renderWrittenText(into: "Bounce") == "48 PNG files into \"Bounce\"")
        #expect(view.readout.line == .finished("Exported 48 PNG files into \"Bounce\""))
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

    /// The summary, the missing-folder problem and the progress line start where the Folder label does (#4454).
    /// The problem is an error note, whose element starts at its Label's symbol, so it is held to where a bare
    /// error note at a column's x 0 reports itself; the summary and frame notes are plain text, at the label's x.
    @Test(.timeLimit(.minutes(1))) func notesSitOnTheLabelInset() throws {
        let errorLead = try Self.lead(of: InspectorNote(HaloRenderOptionRows.noDestination, kind: .error, identifier: "note", column: (0, "column")))
        let cases: [(String, HaloRenderExportAdapter, lead: CGFloat)] = [
            ("halo.render.summary", sheet(try editing()), 0),
            ("halo.render.problem", HaloRenderExportAdapter(model: try editing(), destination: nil, output: nil) { _ in }, errorLead),
            ("halo.render.frame", sheet(try running()), 0),
        ]
        for (id, view, lead) in cases {
            let window = Self.host(view)
            defer { window.close() }
            let nodes = Self.nodes(in: window.contentView as Any)
            let label = try #require(Self.frame(nodes.first { Self.label($0) == "Folder" }, in: window), "no Folder label")
            let note = try #require(Self.frame(nodes.first { ($0.accessibilityIdentifier?() ?? nil) == id }, in: window), "no \(id)")
            #expect(
                abs(note.minX - label.minX - lead) <= 0.5,
                "\(id) starts at \(note.minX), the Folder label at \(label.minX), a note \(lead) in from its column")
        }
    }

    /// How far right of its column's x 0 `note` (identifier "note", column space "column") reports its element.
    private static func lead(of note: InspectorNote) throws -> CGFloat {
        let window = host(VStack(alignment: .leading, spacing: 0) {
            Text("Folder")
            note
        }.coordinateSpace(.named("column")))
        defer { window.close() }
        let nodes = nodes(in: window.contentView as Any)
        let column = try #require(frame(nodes.first { label($0) == "Folder" }, in: window), "no column text")
        let shown = try #require(frame(nodes.first { ($0.accessibilityIdentifier?() ?? nil) == "note" }, in: window), "no note")
        print("halo.render notes: a bare error note starts \(shown.minX - column.minX) right of its column")
        return shown.minX - column.minX
    }

    /// `view` in a borderless window far off every screen, accessibility on, so its elements report frames.
    private static func host(_ view: some View) -> NSWindow {
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let size = CGSize(width: SuiteSize.contentMinimum.width, height: 640)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height, alignment: .topLeading))
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return window
    }

    private static func nodes(in element: Any) -> [AnyObject] {
        let node = element as AnyObject
        return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { nodes(in: $0) }
    }

    /// A node's accessibility label, else its value, when it is text; read untyped, as HaloLayoutTests does.
    private static func label(_ node: AnyObject) -> String? {
        guard let object = node as? NSObject else { return nil }
        return ["accessibilityLabel", "accessibilityValue"].lazy.compactMap { getter -> String? in
            let selector = NSSelectorFromString(getter)
            guard object.responds(to: selector) else { return nil }
            return object.perform(selector)?.takeUnretainedValue() as? String
        }.first
    }

    private static func frame(_ node: AnyObject?, in window: NSWindow) -> CGRect? {
        guard let screen = node?.accessibilityFrame?() else { return nil }
        return window.convertFromScreen(screen)
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
