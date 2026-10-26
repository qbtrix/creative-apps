// GalleryStrokeEditor.swift: the gallery's `stroke-editor` page (stroke-style SS-2; SS-9 live). A preview path, a
// zig-zag with corners and open ends so the join and cap show, painted with the page's own stroke (2 pt black to start)
// as StrokeRules.paintedPath draws it (trimmed, then dashed), beside StrokeEditor with every row live. The page drives a
// local StrokeTarget with a History: each intent the editor sends runs as its stroke command through the board's
// catalog, a scrub under one drag token is one undo step, and each writes one line, `<command id> (<outcome>)
// <intent>`, to `suite.gallery.log`. The page is listed in `GalleryInspector.pages`, beside the other inspector pages.
import SuiteKernel
import SwiftUI

enum GalleryStrokeEditor {
    static let name = "stroke-editor"

    /// The page's stroke to start: 2 pt black, miter, butt.
    static let start = VectorStroke(width: 2)

    /// `stroke` after `intent` runs through the board's catalog; unchanged when the command refuses it.
    static func applied(_ intent: StrokeIntent, to stroke: VectorStroke?) -> VectorStroke? {
        var board = GalleryStrokeBoard(stroke: stroke)
        _ = board.send(intent)
        return board.stroke
    }

    /// The preview's zig-zag across `size`, as `stroke` paints it; empty when the rules refuse it.
    static func painted(_ stroke: VectorStroke, in size: CGSize) -> VectorPath {
        let (w, h) = (Double(size.width), Double(size.height))
        let zig = VectorPath(polyline: [Point(x: w * 0.15, y: h * 0.7), Point(x: w * 0.35, y: h * 0.3),
                                        Point(x: w * 0.55, y: h * 0.7), Point(x: w * 0.85, y: h * 0.3)], closed: false)
        return (try? StrokeRules.paintedPath(zig, stroke)) ?? VectorPath(elements: [])
    }
}

/// The page's local document: one strokable layer and its History, steps under one drag token folded into one.
struct GalleryStrokeBoard: StrokeTarget {
    private(set) var stroke: VectorStroke?
    private(set) var history = History<VectorStroke?>()

    init(stroke: VectorStroke? = GalleryStrokeEditor.start) { self.stroke = stroke }

    var strokeHelp: String? { nil }
    var trimHelp: String? { nil }
    var selectedStroke: VectorStroke? { stroke }

    static let catalog = try? CommandCatalog<GalleryStrokeBoard>(
        app: "gallery", StrokeCommands.specs(GalleryStrokeBoard.self), history: { $0.history })

    mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        history.record(name, self.stroke, key: drag.map { "\(name):\($0)" })
        self.stroke = stroke
    }

    /// Runs `intent` as its stroke command through the catalog; the log line, the intent (its drag token) last.
    mutating func send(_ intent: StrokeIntent) -> String {
        let (id, params) = intent.command
        guard let catalog = Self.catalog else { return "\(id) (no catalog) \(intent)" }
        do {
            let outcome = try catalog.run(id, params: params, on: &self)
            return "\(id) (\(outcome.undoStep ?? "done"), \(history.steps.count) in History) \(intent)"
        } catch {
            return "\(id) (refused: \(error)) \(intent)"
        }
    }

    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = stroke
        let undid = history.undo { old in
            defer { current = old }
            return current
        }
        stroke = current
        return undid
    }
}

/// The `stroke-editor` page: the preview, the editor and the log under them.
struct GalleryStrokeEditorPage: View {
    @State private var board = GalleryStrokeBoard()
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                GalleryStrokePreview(stroke: board.stroke)
                ScrollView {
                    InspectorSection("Stroke") {
                        StrokeEditor(stroke: board.stroke, help: nil, dashHelp: nil, onIntent: send)
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
        log.append(board.send(intent))
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// The preview: a zig-zag across the artboard, stroked with `stroke`; empty when there is none.
private struct GalleryStrokePreview: View {
    let stroke: VectorStroke?

    var body: some View {
        Canvas { context, size in
            guard let stroke else { return }
            let color = Color(Color.Resolved(
                red: Float(stroke.color.r), green: Float(stroke.color.g), blue: Float(stroke.color.b),
                opacity: Float(stroke.color.a)))
            context.stroke(Self.path(GalleryStrokeEditor.painted(stroke, in: size)), with: .color(color), style: StrokeStyle(
                lineWidth: CGFloat(stroke.width), lineCap: Self.cap(stroke.cap), lineJoin: Self.join(stroke.join)))
        }
        .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
        .background(SuiteColor.artboard)
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .accessibilityElement()
        .accessibilityLabel("Stroke preview")
        .accessibilityValue(stroke.map(Self.value) ?? "No stroke")
        .accessibilityIdentifier("suite.gallery.stroke-editor.preview")
    }

    /// "2 pt miter butt", then the dash pattern and the trim when there are any: "… dash 10 4 trim 0 to 40%".
    @MainActor static func value(_ stroke: VectorStroke) -> String {
        var parts = ["\(StrokeEditorText.points(stroke.width)) \(stroke.join.rawValue) \(stroke.cap.rawValue)"]
        let pattern = StrokeRules.dash(of: stroke).pattern
        if !pattern.isEmpty { parts.append("dash " + pattern.map { NumericInput.text($0, decimals: 0, unit: "") }.joined(separator: " ")) }
        if let trim = StrokeRules.trim(of: stroke) { parts.append("trim \(Int((trim.start * 100).rounded())) to \(Int((trim.end * 100).rounded()))%") }
        return parts.joined(separator: " ")
    }

    /// The painted path as the canvas strokes it. It is flattened (a polyline, trimmed and dashed), so only moves,
    /// lines and closes occur.
    private nonisolated static func path(_ painted: VectorPath) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        for element in painted.elements {
            switch element {
            case .move(let to): path.move(to: CGPoint(x: to.x, y: to.y))
            case .line(let to): path.addLine(to: CGPoint(x: to.x, y: to.y))
            case .close: path.closeSubpath()
            default: break
            }
        }
        return path
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
