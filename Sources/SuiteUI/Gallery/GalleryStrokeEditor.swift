// GalleryStrokeEditor.swift: the gallery's `stroke-editor` page (stroke-style SS-2; SS-9 runs its intents through
// `StrokeCommands` on a local target with a `History`). A preview path, a zig-zag with corners and open ends so the
// join and cap show, drawn with the page's own stroke (2 pt black to start), beside StrokeEditor with the dash and trim
// rows waiting on core. Each intent the editor sends writes one line, `<command id> <intent>`, to `suite.gallery.log`,
// and the page applies add, remove, colour, width, join and cap to its stroke so the preview follows; dash and trim
// only log until SS-9. The page is listed in `GalleryInspector.pages`, beside the other inspector pages.
import SuiteKernel
import SwiftUI

enum GalleryStrokeEditor {
    static let name = "stroke-editor"

    /// The page's stroke to start: 2 pt black, miter, butt.
    static let start = VectorStroke(width: 2)

    /// `stroke` after `intent`, for the intents the page applies itself; dash and trim leave it as it is.
    static func applied(_ intent: StrokeIntent, to stroke: VectorStroke?) -> VectorStroke? {
        if intent == .add { return stroke ?? VectorStroke() }
        guard intent != .remove, var stroke else { return nil }
        switch intent {
        case .color(let color, _): stroke.color = color
        case .width(let width, _): stroke.width = StrokeRules.clampedWidth(width)
        case .join(let join): stroke.join = join
        case .cap(let cap): stroke.cap = cap
        case .add, .remove, .dash, .trim: break
        }
        return stroke
    }
}

/// The `stroke-editor` page: the preview, the editor and the log under them.
struct GalleryStrokeEditorPage: View {
    @State private var stroke: VectorStroke? = GalleryStrokeEditor.start
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                GalleryStrokePreview(stroke: stroke)
                ScrollView {
                    InspectorSection("Stroke") {
                        StrokeEditor(stroke: stroke, help: nil, dashHelp: StrokeRules.waitingCore, onIntent: send)
                    }
                    .padding(.vertical, SuiteSpacing.m)
                }
                // No scroller: a legacy scroller's page area is an unnamed button
                // with no identifier to the app audit, as in LayerTreeList.
                .scrollIndicators(.never)
                .frame(width: SuiteSize.inspectorWidth.ideal)
                .background(SuiteColor.panel)
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func send(_ intent: StrokeIntent) {
        stroke = GalleryStrokeEditor.applied(intent, to: stroke)
        log.append("\(intent.command.id) \(intent)")
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// The preview: a zig-zag across the artboard, stroked with `stroke`; empty when there is none.
private struct GalleryStrokePreview: View {
    let stroke: VectorStroke?

    var body: some View {
        Canvas { context, size in
            guard let stroke else { return }
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.15, y: size.height * 0.7))
            path.addLine(to: CGPoint(x: size.width * 0.35, y: size.height * 0.3))
            path.addLine(to: CGPoint(x: size.width * 0.55, y: size.height * 0.7))
            path.addLine(to: CGPoint(x: size.width * 0.85, y: size.height * 0.3))
            let color = Color(Color.Resolved(
                red: Float(stroke.color.r), green: Float(stroke.color.g), blue: Float(stroke.color.b),
                opacity: Float(stroke.color.a)))
            context.stroke(path, with: .color(color), style: StrokeStyle(
                lineWidth: CGFloat(stroke.width), lineCap: Self.cap(stroke.cap), lineJoin: Self.join(stroke.join)))
        }
        .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
        .background(SuiteColor.artboard)
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .accessibilityElement()
        .accessibilityLabel("Stroke preview")
        .accessibilityValue(stroke.map { "\(StrokeEditorText.points($0.width)) \($0.join.rawValue) \($0.cap.rawValue)" } ?? "No stroke")
        .accessibilityIdentifier("suite.gallery.stroke-editor.preview")
    }

    private nonisolated static func cap(_ cap: StrokeCap) -> CGLineCap {
        switch cap {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }

    private nonisolated static func join(_ join: StrokeJoin) -> CGLineJoin {
        switch join {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }
}
