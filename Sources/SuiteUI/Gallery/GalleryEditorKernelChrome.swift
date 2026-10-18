// GalleryEditorKernelChrome.swift: the editor-kernel page's chrome (EK-30) on
// the fakes: Export opens ExportSheet and walks a fake run to 10 of 10; the
// stroke pad paints a StrokePacer-paced drag at PointerPressure under a
// BrushCursorMark. The pad's samples stay in its own state.
import SuiteKernel
import SwiftUI

enum GalleryEditorKernelChrome {
    static let formats = [FormatChoice(id: "png", name: "PNG", hasQuality: false), FormatChoice(id: "jpeg", name: "JPEG", hasQuality: true)]
    static let pick = ExportPick(format: "png", scale: 1, quality: 0.9)
    static let brush = 24.0

    static func fakeSteps(_ pick: ExportPick) -> [ExportRun<ExportPick>] {
        (0...10).map { .running(pick, done: $0, total: 10) } + [.finished(pick, ["editor-kernel.png"])]
    }
}

struct GalleryEditorKernelChromePanel: View {
    @State private var run: ExportRun<ExportPick> = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Button("Export…") { run = .editing(GalleryEditorKernelChrome.pick) }.accessibilityIdentifier("suite.gallery.export")
            GalleryStrokePad()
        }
        .sheet(isPresented: Binding(get: { run != .idle }, set: { if !$0 { run = .idle } })) {
            SuiteExportSheet(
                ExportSheetRows(run, formats: GalleryEditorKernelChrome.formats) { $0 }, formats: GalleryEditorKernelChrome.formats,
                onFormat: { f in edit { $0.format = f } }, onScale: { s in edit { $0.scale = s } },
                onQuality: { q in edit { $0.quality = q } }, onExport: start, onClose: { run = .idle })
        }
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

struct GalleryStrokePad: View {
    struct Dot: Hashable { var point: CGPoint, pressure: Double, starts: Bool }

    @State private var dots: [Dot]
    @State private var hover: CGPoint?
    @State private var drawing = false
    @State private var pacer = StrokePacer<Dot>()

    init(dots: [Dot] = [], hover: CGPoint? = nil) { (_dots, _hover) = (State(initialValue: dots), State(initialValue: hover)) }

    var body: some View {
        let shown = dots
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
                    let dot = Dot(point: value.location, pressure: PointerPressure.current, starts: !drawing)
                    drawing = true
                    pacer.add(dot) { dots += $0 }
                }
                .onEnded { _ in pacer.stop(); drawing = false })
        .onAppear { PointerPressure.watch() }
        .accessibilityElement()
        .accessibilityLabel("Stroke pad")
        .accessibilityValue("\(dots.filter(\.starts).count) strokes")
        .accessibilityIdentifier("suite.gallery.stroke-pad")
    }
}
