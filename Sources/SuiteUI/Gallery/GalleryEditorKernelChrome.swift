// GalleryEditorKernelChrome.swift: the editor-kernel page's chrome (EK-30) on
// the fakes: Export opens SuiteExportSheet and walks a fake run to 10 of 10;
// the stroke pad paints a SuiteStrokePacer-paced drag at SuitePointerPressure
// under a BrushCursorMark. The pad's samples stay in its own state; its
// stroke count is also a ProbeElement (`suite.gallery.stroke-pad.strokes`).
// EK-31: with the panel focused, a tool letter (B, V) picks its tool through
// ToolKeys and the `suite.gallery.tool-status` line names it.
import SuiteKernel
import SwiftUI

enum GalleryEditorKernelChrome {
    static let formats = [FormatChoice(id: "png", name: "PNG", hasQuality: false), FormatChoice(id: "jpeg", name: "JPEG", hasQuality: true)]
    static let pick = ExportPick(format: "png", scale: 1, quality: 0.9)
    static let brush = 24.0

    /// The panel's tools, picked by their letters through ToolKeys.
    enum Tool: String, PaletteTool, CaseIterable {
        case move, brush
        var title: String { rawValue.capitalized }
        var systemImage: String { self == .move ? "cursorarrow" : "paintbrush.pointed" }
        var unavailableHelp: String? { nil }
        var shortcut: Character? { self == .move ? "v" : "b" }
        var gesture: ToolGesture { self == .move ? .movesContent : .paints }
    }

    static func fakeSteps(_ pick: ExportPick) -> [ExportRun<ExportPick>] {
        (0...10).map { .running(pick, done: $0, total: 10) } + [.finished(pick, ["editor-kernel.png"])]
    }
}

struct GalleryEditorKernelChromePanel: View {
    @State private var run: ExportRun<ExportPick> = .idle
    @State private var tool = GalleryEditorKernelChrome.Tool.move
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Button("Export…") { run = .editing(GalleryEditorKernelChrome.pick) }.accessibilityIdentifier("suite.gallery.export")
            GalleryStrokePad()
            GalleryToolStatus(tool: tool)
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in pick(press) }
        .onAppear { focused = true }
        .sheet(isPresented: Binding(get: { run != .idle }, set: { if !$0 { run = .idle } })) {
            SuiteExportSheet(
                ExportSheetRows(run, formats: GalleryEditorKernelChrome.formats) { $0 }, formats: GalleryEditorKernelChrome.formats,
                onFormat: { f in edit { $0.format = f } }, onScale: { s in edit { $0.scale = s } },
                onQuality: { q in edit { $0.quality = q } }, onExport: start, onClose: { run = .idle })
        }
    }

    /// A tool letter with Shift or nothing held picks its tool; any other key goes on.
    private func pick(_ press: KeyPress) -> KeyPress.Result {
        guard press.characters.count == 1, let key = press.characters.first,
              press.modifiers.isDisjoint(with: [.command, .control, .option]),
              let picked = ToolKeys.tool(forKey: key, in: GalleryEditorKernelChrome.Tool.allCases)
        else { return .ignored }
        tool = picked
        return .handled
    }

    private func edit(_ change: (inout ExportPick) -> Void) {
        guard case .editing(var options) = run else { return }
        change(&options)
        run = .editing(options)
    }

    private func start() {
        guard case .editing(let options) = run else { return }
        Task {
            for step in GalleryEditorKernelChrome.fakeSteps(options) where run != .idle {
                run = step
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }
}

/// The panel's status line: the tool ToolKeys picked.
struct GalleryToolStatus: View {
    let tool: GalleryEditorKernelChrome.Tool

    var body: some View {
        let text = "Tool: \(tool.title)"
        Text(text)
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .accessibilityLabel(text)
            .accessibilityValue(text)
            .accessibilityIdentifier("suite.gallery.tool-status")
    }
}

struct GalleryStrokePad: View {
    struct Dot { var point: CGPoint, pressure: Double, starts: Bool }

    @State private var dots: [Dot]
    @State private var hover: CGPoint?
    @State private var drawing = false
    @State private var pacer = SuiteStrokePacer<Dot>()

    init(dots: [Dot] = [], hover: CGPoint? = nil) { _dots = State(initialValue: dots); _hover = State(initialValue: hover) }

    var body: some View {
        let shown = dots
        let strokes = "\(dots.filter(\.starts).count) strokes"
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for (a, b) in zip(shown, shown.dropFirst()) where !b.starts {
                    let line = Path { $0.move(to: a.point); $0.addLine(to: b.point) }
                    let width = GalleryEditorKernelChrome.brush * max(b.pressure, 0.1)
                    context.stroke(line, with: .color(SuiteColor.overlayInk), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
            BrushCursorMark(point: hover, diameter: GalleryEditorKernelChrome.brush, zoom: 1)
        }
        .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
        .background(SuiteColor.artboard)
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .contentShape(.rect)
        .onContinuousHover { phase in if case .active(let p) = phase { hover = p } else { hover = nil } }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    hover = value.location
                    let dot = Dot(point: value.location, pressure: SuitePointerPressure.current, starts: !drawing)
                    drawing = true
                    pacer.add(dot) { dots += $0 }
                }
                .onEnded { _ in pacer.stop(); drawing = false })
        .onAppear { SuitePointerPressure.watch() }
        .accessibilityElement()
        .accessibilityLabel("Stroke pad")
        .accessibilityValue(strokes)
        .accessibilityIdentifier("suite.gallery.stroke-pad")
        // AppKit hands a plain element's SwiftUI value back as nil (#262), so a test reads the count here.
        .overlay(alignment: .topLeading) {
            ProbeElement("suite.gallery.stroke-pad.strokes", label: strokes, size: CGSize(width: 1, height: 1))
        }
    }
}
