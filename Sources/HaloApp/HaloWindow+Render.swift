// HaloWindow+Render.swift: the render area's routes and hook. Render Frame
// (⌘R, render-out RO-5, #451) calls the Model's `renderCurrentFrame()`, and
// the viewer shows the frame (HaloRenderedFrameView). Render… (⇧⌘R) opens
// the Model's render run (`beginRender`, core-loop CL-4, #1971), and
// `renderScene(_:)` presents SuiteUI's SuiteExportSheet over `renderRun`
// while it isn't idle (HaloRenderSheetHost), with Halo's rows in the options
// slot (HaloRenderOptionRows): the Size label over Full and Half chips (the
// sheet's own 0.25x-4x Size row is off: Halo renders at those two only), the folder
// (`-HaloRenderTo`, else Choose…), and one note: "Frame n of N" while
// running, else the summary, or, with no folder, why (the error color). A
// format chip or the Size row calls `setRenderSettings`. The sheet's start
// button (titled Export until #3402) asks for a folder when there is none
// (#3297 tracks disabling it instead), then `renderStart(into:)`: the Model
// starts the run, a detached task writes the frames through the PNG or movie
// writer off the main actor, and its progress and outcome come back over a
// stream that a main-actor task hands to `renderProgressed(done:)` and
// `endRender(_:)`. Cancel stops a run under way (`cancelRender`, which
// leaves it idle, so the sheet closes) or closes the editing sheet; Done
// calls `dismissRender`; Try Again reopens a failed run's settings; Reveal
// in Finder selects what the run wrote. Once the run is idle the host
// cancels its task. `.startRender` from a menu does nothing: only the sheet
// knows the folder. In DEBUG, `renderDrive` edits the shown window's model
// for RenderBudgetHaloRenderTests.
import AppKit
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

extension HaloWindow {
    #if DEBUG
    /// Edits the model of the window that last appeared; RenderBudgetHaloRenderTests drives the run with it.
    @MainActor static var renderDrive: ((_ change: (inout HaloProject) -> Void) -> Void)?
    #endif

    func renderPerform(_ command: HaloCommand) {
        switch command {
        case .renderFrame: model.renderCurrentFrame()
        case .openRenderSheet: model.beginRender(model.renderJob?.settings ?? HaloRenderSettings(format: .pngSequence))
        case .cancelRender: model.cancelRender()
        case .closeRenderSheet: model.dismissRender()
        default: break
        }
    }

    func renderScene(_ content: some View) -> some View {
        let hosted = content.modifier(HaloRenderSheetHost(model: model, act: renderAct, start: renderStart(into:)))
        #if DEBUG
        return hosted.onAppear { Self.renderDrive = { change in change(&model) } }
        #else
        return hosted
        #endif
    }

    /// One of the sheet's edits, sent to the Model.
    func renderAct(_ act: HaloRenderAct) {
        switch act {
        case .settings(let settings): model.setRenderSettings(settings)
        case .close:
            if case .running = model.renderRun { model.cancelRender() } else { model.dismissRender() }
        case .tryAgain:
            guard case .failed(let settings, _) = model.renderRun else { return }
            model.dismissRender()
            model.beginRender(settings)
        case .start, .choose, .reveal: break
        }
    }

    /// Starts rendering the selected composition into `folder`; nil when the
    /// Model refuses.
    func renderStart(into folder: URL) -> HaloRenderRun? {
        guard case .editing(let settings) = model.renderRun,
            let name = model.renderOutputName(settings, existing: HaloRenderRun.names(in: folder)),
            let started = model.startRender()
        else { return nil }
        let (plan, composition) = (started.plan, started.composition)
        let output = folder.appending(path: name, directoryHint: settings.format == .movie ? .notDirectory : .isDirectory)
        let rendering = model.services.compositionRendering
        let text = model.services.text
        let (events, continuation) = AsyncStream.makeStream(of: HaloRenderRun.Event.self)
        let worker = Task.detached(priority: .userInitiated) {
            let report: (Int) -> Void = { continuation.yield(.progress($0)) }
            let outcome: HaloRenderOutcome
            switch settings.format {
            case .pngSequence:
                var sink = HaloRenderProgress(base: HaloPNGWriter(folder: output), onWrite: report)
                outcome = rendering.run(plan, of: composition, text: text, into: &sink, isCancelled: { Task.isCancelled })
            case .movie:
                var sink = HaloRenderProgress(base: HaloMovieWriter(url: output), onWrite: report)
                outcome = rendering.run(plan, of: composition, text: text, into: &sink, isCancelled: { Task.isCancelled })
            }
            continuation.yield(.ended(outcome))
            continuation.finish()
        }
        let forwarder = Task { @MainActor in
            for await event in events {
                switch event {
                case .progress(let frame): model.renderProgressed(done: frame)
                case .ended(let outcome): model.endRender(outcome)
                }
            }
        }
        return HaloRenderRun(worker: worker, forwarder: forwarder, output: output)
    }
}

/// What the render sheet asks of the window.
enum HaloRenderAct {
    case settings(HaloRenderSettings), start, choose, close, tryAgain, reveal
}

/// Presents the export sheet while the Model's render run isn't idle; holds the folder and the started run.
struct HaloRenderSheetHost: ViewModifier {
    let model: HaloProject
    let act: @MainActor (HaloRenderAct) -> Void
    let start: @MainActor (URL) -> HaloRenderRun?
    @State private var destination = HaloLaunch.current.renderTo.map { URL(fileURLWithPath: $0, isDirectory: true) }
    @State private var run: HaloRenderRun?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { model.renderRun != .idle }, set: { if !$0 { act(.close) } })) {
                HaloRenderExportAdapter(model: model, destination: destination, output: run?.output) { request in
                    switch request {
                    case .start: begin()
                    case .choose: destination = chosenFolder() ?? destination
                    case .reveal: if let output = run?.output { NSWorkspace.shared.activateFileViewerSelecting([output]) }
                    default: act(request)
                    }
                }
            }
            .onChange(of: model.renderRun == .idle) { _, idle in
                guard idle else { return }
                run?.cancel()
                run = nil
            }
    }

    /// Starts the run into the folder, asking for one first when there is none.
    private func begin() {
        guard let folder = destination ?? chosenFolder() else { return }
        destination = folder
        run = start(folder)
    }

    /// A folder the person picks; nil when they cancel.
    private func chosenFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

/// The sheet's content: SuiteExportSheet over `renderRun` with Halo's rows; the snapshots render it on its own.
struct HaloRenderExportAdapter: View {
    let model: HaloProject
    let destination: URL?
    let output: URL?
    let act: @MainActor (HaloRenderAct) -> Void

    /// The format chips: one choice per format, its id the raw value.
    nonisolated static let formats = HaloRenderSettings.Format.allCases.map {
        FormatChoice(id: $0.rawValue, name: title($0), hasQuality: false)
    }

    /// A format's name on its chip.
    nonisolated static func title(_ format: HaloRenderSettings.Format) -> String {
        switch format {
        case .pngSequence: "PNG sequence"
        case .movie: "Movie"
        }
    }

    /// The Model's run, a finished one read as what it wrote ("Exported Bounce"), not its every file name.
    private var run: ExportRun<HaloRenderSettings> {
        guard case .finished(let settings, let files) = model.renderRun else { return model.renderRun }
        return .finished(settings, [output?.lastPathComponent ?? "\(files.count) files"])
    }

    var readout: ExportSheetRows {
        ExportSheetRows(run, formats: Self.formats, showsSize: false) { ExportPick(format: $0.format.rawValue, scale: $0.halfSize ? 0.5 : 1) }
    }

    var body: some View {
        let settings = model.renderJob?.settings ?? HaloRenderSettings(format: .pngSequence)
        SuiteExportSheet(
            readout, formats: Self.formats, idPrefix: "halo.render",
            onFormat: { id in
                if let format = HaloRenderSettings.Format(rawValue: id) {
                    act(.settings(HaloRenderSettings(format: format, halfSize: settings.halfSize)))
                }
            },
            onScale: { act(.settings(HaloRenderSettings(format: settings.format, halfSize: $0 < 1))) },
            onQuality: { _ in },
            onExport: { act(.start) },
            onClose: { act(.close) },
            onTryAgain: { act(.tryAgain) },
            onReveal: output == nil ? nil : { act(.reveal) }
        ) {
            HaloRenderOptionRows(model: model, settings: settings, destination: destination, act: act)
        }
    }
}

/// Halo's rows in the export sheet's options slot: the Size chips under their label, the folder and one note.
struct HaloRenderOptionRows: View {
    nonisolated static let noDestination = "Choose a folder to render into."
    nonisolated static let busy = "The render is under way or done."

    let model: HaloProject
    let settings: HaloRenderSettings
    let destination: URL?
    let act: @MainActor (HaloRenderAct) -> Void

    private var editing: Bool {
        if case .editing = model.renderRun { true } else { false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text("Size").font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
            ChoiceChips(
                options: [
                    InspectorOption(id: false, title: "Full", identifier: "halo.render.size.full"),
                    InspectorOption(id: true, title: "Half", identifier: "halo.render.size.half"),
                ],
                selected: settings.halfSize
            ) { act(.settings(HaloRenderSettings(format: settings.format, halfSize: $0))) }
            InspectorRow("Folder") {
                HStack(spacing: SuiteSpacing.s) {
                    Text(destination?.lastPathComponent ?? "None")
                        .foregroundStyle(destination == nil ? SuiteColor.secondaryText : SuiteColor.textPrimary)
                    Button("Choose…") { act(.choose) }
                        .help(editing ? "Choose the folder to render into." : Self.busy)
                        .haloControl(id: "halo.render.destination", enabled: editing, help: editing ? nil : Self.busy)
                }
            }
            if let progress = model.renderProgressText {
                InspectorNote(progress, identifier: "halo.render.frame")
            } else if editing, destination == nil {
                InspectorNote(Self.noDestination, kind: .error, identifier: "halo.render.problem")
            } else if editing, let summary = model.renderSummary(settings, existing: HaloRenderRun.names(in: destination)) {
                InspectorNote(summary, identifier: "halo.render.summary")
            }
        }
    }
}

/// A started render: the detached task writing it and the main-actor task
/// handing its events to the Model, both cancelled once the run is idle, and
/// what it writes (the folder of PNGs or the movie file), which Reveal in
/// Finder selects.
struct HaloRenderRun {
    enum Event: Sendable {
        case progress(Int)
        case ended(HaloRenderOutcome)
    }

    let worker: Task<Void, Never>
    let forwarder: Task<Void, Never>
    let output: URL

    func cancel() {
        worker.cancel()
        forwarder.cancel()
    }

    /// What `folder` holds, so a render never writes over an earlier one.
    static func names(in folder: URL?) -> Set<String> {
        guard let folder else { return [] }
        return Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? [])
    }
}

/// Passes every call to `base` and reports how many frames are written.
struct HaloRenderProgress<Base: RenderSink>: RenderSink {
    var base: Base
    let onWrite: (Int) -> Void
    var written = 0

    mutating func begin(_ plan: HaloRenderPlan) throws { try base.begin(plan) }

    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        try base.write(frame, named: fileName)
        written += 1
        onWrite(written)
    }

    mutating func finish(cancelled: Bool) throws { try base.finish(cancelled: cancelled) }
}
