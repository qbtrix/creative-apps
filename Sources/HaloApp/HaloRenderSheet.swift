// HaloRenderSheet.swift: File > Render… (render-out RO-8, #429), staged by
// the Model's render job. Settings: a Form with segmented Format and Size,
// the folder (`-HaloRenderTo`, else Choose…), the summary, Cancel, and
// Render (off with a reason until there is a folder). Running: "Frame n of
// N", a progress bar, Cancel. Ended: the outcome and Close, with Reveal in
// Finder after a finished render; a failure in stateError. The sheet holds
// its draft and its run; commands go to the window, and a job cancelled by
// any route cancels the run. Controls carry `halo.render.*` ids, and each
// Format and Size segment its own (`halo.render.format.png`, ...).
import AppKit
import HaloModel
import SuiteUI
import SwiftUI

struct HaloRenderSheet: View {
    enum Stage: Equatable { case settings, running, ended, failed }

    static let noDestination = "Choose a destination folder first."

    let project: HaloProject
    var onRender: @MainActor (HaloRenderSettings, URL) -> HaloRenderRun?
    var onCommand: @MainActor (HaloCommand) -> Void
    @State private var format: HaloRenderSettings.Format
    @State private var size: HaloRenderSize
    @State private var destination: URL?
    @State private var run: HaloRenderRun?
    @State private var output: URL?

    init(
        model: HaloProject, destination: URL?, initial: HaloRenderSettings? = nil, output: URL? = nil,
        onRender: @escaping @MainActor (HaloRenderSettings, URL) -> HaloRenderRun? = { _, _ in nil },
        onCommand: @escaping @MainActor (HaloCommand) -> Void = { _ in }
    ) {
        let settings = initial ?? model.renderJob?.settings ?? HaloRenderSettings(format: .pngSequence)
        self.project = model
        self.onRender = onRender
        self.onCommand = onCommand
        self._format = State(initialValue: settings.format)
        self._size = State(initialValue: settings.halfSize ? .half : .full)
        self._destination = State(initialValue: destination)
        self._output = State(initialValue: output)
    }

    var settings: HaloRenderSettings { HaloRenderSettings(format: format, halfSize: size == .half) }

    /// Why Render is off: no folder yet, or the Model's reason; nil when on.
    var renderHelp: String? {
        destination == nil ? Self.noDestination : project.unavailableHelp(for: .startRender(settings))
    }

    var stage: Stage {
        guard let job = project.renderJob, let outcome = job.outcome else {
            return project.renderJob?.plan == nil ? .settings : .running
        }
        if case .failed = outcome { return .failed }
        return .ended
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text("Render").font(SuiteFont.title)
            switch stage {
            case .settings: settingsForm
            case .running: progressRow
            case .ended: Text(project.renderOutcomeText ?? "")
            case .failed:
                Label(project.renderOutcomeText ?? "", systemImage: "exclamationmark.circle")
                    .foregroundStyle(SuiteColor.stateError)
            }
            HStack {
                Spacer()
                buttons
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentMinimum.width)
        .onChange(of: project.renderJob?.outcome) { _, outcome in
            if case .cancelled = outcome { run?.worker.cancel() }
        }
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Form {
                Picker("Format", selection: $format) {
                    ForEach(HaloRenderSettings.Format.allCases, id: \.self) {
                        Text(Self.title($0)).tag($0).accessibilityIdentifier(Self.segmentID($0))
                    }
                }
                .pickerStyle(.segmented)
                .haloControl(id: "halo.render.format", enabled: true, help: nil)
                Picker("Size", selection: $size) {
                    ForEach(HaloRenderSize.allCases, id: \.self) {
                        Text($0.rawValue).tag($0).accessibilityIdentifier(Self.segmentID($0))
                    }
                }
                .pickerStyle(.segmented)
                .haloControl(id: "halo.render.size", enabled: true, help: nil)
                LabeledContent("Destination") {
                    HStack(spacing: SuiteSpacing.s) {
                        Text(destination?.lastPathComponent ?? "None")
                            .foregroundStyle(destination == nil ? SuiteColor.secondaryText : SuiteColor.textPrimary)
                        Button("Choose…") { chooseFolder() }
                            .haloControl(id: "halo.render.destination", enabled: true, help: nil)
                    }
                }
            }
            .formStyle(.columns)
            if let summary = project.renderSummary(settings, existing: HaloRenderRun.names(in: destination)) {
                Text(summary).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            }
        }
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text(project.renderProgressText ?? "").font(SuiteFont.monospacedDigits)
            ProgressView(
                value: Double(project.renderJob?.progress ?? 0),
                total: Double(max(project.renderJob?.plan?.frames.count ?? 1, 1))
            )
            .accessibilityIdentifier("halo.render.progress")
        }
    }

    @ViewBuilder private var buttons: some View {
        switch stage {
        case .settings:
            command(.cancelRender, title: "Cancel", id: "halo.render.cancel").keyboardShortcut(.cancelAction)
            Button("Render") { startRender() }
                .keyboardShortcut(.defaultAction)
                .disabled(renderHelp != nil)
                .help(renderHelp ?? "Render the composition into the destination folder.")
                .haloControl(id: "halo.render.start", enabled: renderHelp == nil, help: renderHelp)
        case .running:
            command(.cancelRender, title: "Cancel", id: "halo.render.cancel").keyboardShortcut(.cancelAction)
        case .ended, .failed:
            if case .finished = project.renderJob?.outcome {
                let help = output == nil ? "Nothing was written." : nil
                Button("Reveal in Finder") {
                    if let output { NSWorkspace.shared.activateFileViewerSelecting([output]) }
                }
                    .disabled(help != nil)
                    .help(help ?? "Show what the render wrote in Finder.")
                    .haloControl(id: "halo.render.reveal", enabled: help == nil, help: help)
            }
            command(.closeRenderSheet, title: "Close", id: "halo.render.close").keyboardShortcut(.defaultAction)
        }
    }

    private func command(_ command: HaloCommand, title: String, id: String) -> some View {
        let help = project.unavailableHelp(for: command)
        return Button(title) { onCommand(command) }
            .disabled(help != nil)
            .help(help ?? title)
            .haloControl(id: id, enabled: help == nil, help: help)
    }

    private func startRender() {
        guard let destination, renderHelp == nil else { return }
        run = onRender(settings, destination)
        output = run?.output
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        destination = url
    }

    static func title(_ format: HaloRenderSettings.Format) -> String {
        switch format {
        case .pngSequence: "PNG Sequence"
        case .movie: "Movie"
        }
    }

    /// Each Format segment's id: a segmented Picker shows every option as its
    /// own radio button, so the Picker's id alone leaves them unidentified.
    static func segmentID(_ format: HaloRenderSettings.Format) -> String {
        switch format {
        case .pngSequence: "halo.render.format.png"
        case .movie: "halo.render.format.movie"
        }
    }

    /// Each Size segment's id, as for Format.
    static func segmentID(_ size: HaloRenderSize) -> String {
        switch size {
        case .full: "halo.render.size.full"
        case .half: "halo.render.size.half"
        }
    }
}

/// The Size choice: the composition's size or half of it.
enum HaloRenderSize: String, CaseIterable {
    case full = "Full"
    case half = "Half"
}
