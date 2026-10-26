// FlareExportSheetAdapter.swift: Flare's export run on SuiteUI's export sheet.
// The sheet shows while the Model's run isn't idle (`exportingOptions`), with the kernel
// rows (`ExportSheetRows`) for Flare's five formats and `sheetScale` as the
// Size row (the shared size for MP4 and GIF, `setSize`); Flare has no quality.
// Its ids hang off `flare.export`. The options slot holds FlareExportOptionRows:
// the Frame row (SVG), From, To and Step (PNG sequence), or (MP4 and GIF) the
// Scale / Long edge / Pixels chips with the mode's px fields (a placeholder for
// SuiteUI's shared Size row, #5024), Frame rate in fps, GIF's Loop forever and
// the live "W × H px · N frames · T s" readout; 1x and 2x scale chips and the Transparent
// background checkbox (SVG and PNG), the scan's warnings, the PNG file count and, in
// the error color, `exportProblem`, which Export is refused on. A finished run
// reads `exportSummary`. Every control sends a FlareIntent.Export: a format
// pick `setFormat`, Size or a chip `setScale`, a frame row `setFrames` (moving
// the other end when it would cross), Step `setStep`, the checkbox
// `setTransparent`, Export `start`, Try Again `tryAgain`, Reveal `reveal`, and
// Cancel `cancel` while the run is under way, else Done or Escape `dismiss`.
// `sheet` is the content alone, which the snapshots render.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareExportSheetAdapter: ViewModifier {
    let model: FlareWorkspace
    let perform: @MainActor (FlareIntent) -> Void

    /// The format menu: one choice per built ExportFormat, its id the raw value.
    nonisolated static let formats = ExportFormat.allCases.filter { $0.unbuiltReason == nil }
        .map { FormatChoice(id: $0.rawValue, name: title($0), hasQuality: false) }

    /// A format's name in the menu.
    nonisolated static func title(_ format: ExportFormat) -> String {
        switch format {
        case .svgFrame: "SVG frame"
        case .lottie: "Lottie"
        case .pngSequence: "PNG sequence"
        case .mp4: "MP4"
        case .gif: "GIF"
        }
    }

    private var running: Bool {
        if case .running = model.exportState { true } else { false }
    }

    /// The Model's run, its finished files read as `exportSummary` ("Exported 7 files.") after the sheet's "Exported ".
    private var run: ExportState {
        guard case .finished(let options, _) = model.exportState, let line = model.exportSummary else { return model.exportState }
        return .finished(options, [String(line.dropFirst("Exported ".count))])
    }

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { model.exportingOptions != nil }, set: { if !$0 { close() } })) { sheet }
    }

    /// The sheet's content on the Model's run; FlareExportSnapshots renders it on its own.
    @MainActor var sheet: some View {
        SuiteExportSheet(
            ExportSheetRows(run, formats: Self.formats) { ExportPick(format: $0.format.rawValue, scale: $0.sheetScale) },
            formats: Self.formats,
            idPrefix: "flare.export",
            onFormat: { id in if let format = ExportFormat(rawValue: id) { perform(.export(.setFormat(format))) } },
            onScale: { scale in perform(.export(model.exportingOptions?.format.writesVideo == true ? .setSize(.scale(scale)) : .setScale(scale))) },
            onQuality: { _ in },
            onExport: { perform(.export(.start)) },
            onClose: close,
            onTryAgain: { perform(.export(.tryAgain)) },
            onReveal: { perform(.export(.reveal)) }
        ) {
            if let options = model.exportingOptions { FlareExportOptionRows(model: model, options: options, perform: perform) }
        }
    }

    /// Cancel stops a run under way; otherwise the sheet closes.
    @MainActor private func close() {
        perform(.export(running ? .cancel : .dismiss))
    }
}

/// Flare's rows in the export sheet's options slot, for the run's `options`.
struct FlareExportOptionRows: View {
    let model: FlareWorkspace
    let options: ExportOptions
    let perform: @MainActor (FlareIntent) -> Void

    private var editing: Bool {
        if case .editing = model.exportState { true } else { false }
    }

    var body: some View {
        let last = max((model.scenes.first { $0.id == options.sceneID }?.durationFrames ?? 1) - 1, 0)
        let (from, to) = (options.frames.lowerBound, options.frames.upperBound)
        VStack(spacing: SuiteSpacing.s) {
            switch options.format {
            case .svgFrame:
                frameRow("Frame", "frame", from, max(last, from)) { perform(.export(.setFrames(from: $0, to: max($0, to)))) }
            case .pngSequence:
                frameRow("From", "from", from, max(last, from)) { perform(.export(.setFrames(from: $0, to: max($0, to)))) }
                frameRow("To", "to", to, max(last, to)) { perform(.export(.setFrames(from: min(from, $0), to: $0))) }
                InspectorStepperRow("Step", value: Double(options.step), in: 1...Double(max(last + 1, options.step, 1))) {
                    perform(.export(.setStep(Int($0.rounded()))))
                }
                .accessibilityIdentifier("flare.export.step")
            case .mp4, .gif:
                sizeRows
                InspectorStepperRow("Frame rate", value: Double(model.exportFrameRate ?? 30), in: 1...(options.format == .gif ? 50 : 60), unit: "fps") {
                    perform(.export(.setFrameRate(Int($0.rounded()))))
                }
                .accessibilityIdentifier("flare.export.fps")
                if options.format == .gif {
                    InspectorRow("Loop") {
                        Toggle("Loop forever", isOn: Binding(get: { options.loop }, set: { perform(.export(.setLoop($0))) }))
                            .toggleStyle(.checkbox)
                            .accessibilityIdentifier("flare.export.loop")
                    }
                }
            case .lottie:
                EmptyView()
            }
            if options.format != .lottie, !options.format.writesVideo {
                ChoiceChips(
                    options: [1.0, 2.0].map { InspectorOption(id: $0, title: "\(Int($0))x", identifier: "flare.export.scale.\(Int($0))x") },
                    selected: options.scale
                ) { perform(.export(.setScale($0))) }
                InspectorRow("") {
                    Toggle(
                        "Transparent background",
                        isOn: Binding(get: { options.transparentBackground }, set: { perform(.export(.setTransparent($0))) })
                    )
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("flare.export.transparent")
                }
            }
            VStack(spacing: 0) {
                ForEach(model.exportWarnings(options), id: \.self) { InspectorNote($0) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("flare.export.warnings")
            if editing, let problem = model.exportProblem {
                InspectorNote(problem, kind: .error, identifier: "flare.export.problem")
            } else if editing, options.format == .pngSequence {
                let count = model.exportFileCount
                InspectorNote(count == 1 ? "1 file" : "\(count) files", identifier: "flare.export.count")
            } else if editing, let summary = model.exportVideoSummary {
                InspectorNote(summary, identifier: "flare.export.summary")
            }
        }
    }

    /// MP4 and GIF's size mode chips and, for Long edge or Pixels, its px fields, each sending a whole `setSize`.
    @ViewBuilder private var sizeRows: some View {
        ChoiceChips(
            options: ExportSizeMode.allCases.map { InspectorOption(id: $0, title: $0.title, identifier: "flare.export.size.\($0.rawValue)") },
            selected: options.sizeMode
        ) { perform(.export(.setSize(model.exportSize($0)))) }
        switch options.size {
        case .scale: EmptyView()
        case .longEdge(let edge):
            pixelRow("Long edge", "longedge", edge) { perform(.export(.setSize(.longEdge($0)))) }
        case .pixels(let width, let height, let stretch):
            pixelRow("Width", "width", width) { perform(.export(.setSize(.pixels(width: $0, height: height, stretch: stretch)))) }
            pixelRow("Height", "height", height) { perform(.export(.setSize(.pixels(width: width, height: $0, stretch: stretch)))) }
        }
    }

    /// A whole-pixel row 1...8192 called `flare.export.<id>`.
    private func pixelRow(_ label: String, _ id: String, _ value: Int, set: @escaping @MainActor (Int) -> Void) -> some View {
        InspectorStepperRow(label, value: Double(value), in: 1...8192, unit: "px") { set(Int($0.rounded())) }
            .accessibilityIdentifier("flare.export.\(id)")
    }

    /// A whole-frame row 0...`upper` called `flare.export.<id>`.
    private func frameRow(
        _ label: String, _ id: String, _ value: Int, _ upper: Int, set: @escaping @MainActor (Int) -> Void
    ) -> some View {
        InspectorStepperRow(label, value: Double(value), in: 0...Double(upper)) { set(Int($0.rounded())) }
            .accessibilityIdentifier("flare.export.\(id)")
    }
}
