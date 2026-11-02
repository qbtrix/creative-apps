// GalleryPenPaths.swift: the gallery's `pen-paths` page (pen-paths PN-2, PN-3; PN-8 runs its intents through
// `PathCommands` on a local target with a `History`). An artboard with a sample path on it under PathEditOverlay, a
// Pen and Direct Selection picker, and the `suite.gallery.log` line the journey reads. Each intent the overlay sends
// runs as its command in `GalleryPenBoard`'s catalog and writes one line, `<command id> [<step>, <n> in History]
// <intent>` or `<command id> [refused: <why>] <intent>` (a view command's step reads "no step"), so an anchor drag of
// many moves under one token shows as one undo step. The Pen's closed or finished paths are added beside the sample,
// which stays the path in edit.
import SuiteKernel
import SwiftUI

enum GalleryPenPaths {
    static let name = "pen-paths"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryPenPathsPage()) }]

    /// The sample path on the artboard's right half: a closed contour of two
    /// corners and two smooth anchors, in document pixels.
    static let sample = PathInEdit(id: "sample", path: VectorPath(contours: [VectorContour(
        anchors: [
            VectorAnchor(point: Point(x: 260, y: 80)),
            VectorAnchor(point: Point(x: 400, y: 130), handleIn: Point(x: 370, y: 80), handleOut: Point(x: 430, y: 180), kind: .smooth),
            VectorAnchor(point: Point(x: 360, y: 290)),
            VectorAnchor(point: Point(x: 250, y: 220), handleIn: Point(x: 290, y: 280), handleOut: Point(x: 210, y: 160), kind: .smooth),
        ],
        closed: true)]), toDocument: .identity)
}

/// The page's live target: the sample path in edit, the paths the Pen added, the draft and the selected points, and
/// the History their steps go in; the path commands run on it.
struct GalleryPenBoard: PathEditTarget {
    /// What one undo step puts back: the path in edit and the added paths.
    struct Shapes: Hashable, Sendable {
        var path = GalleryPenPaths.sample
        var added: [VectorPath] = []
    }

    var penDraft: PenDraft?
    var anchorSelection = Selection<AnchorRef>()
    private(set) var shapes = Shapes()
    private(set) var history = History<Shapes>()
    var pathInEdit: PathInEdit? { shapes.path }
    var pathHelp: String? { nil }

    mutating func addPath(_ path: VectorPath, name: String) throws -> String {
        history.record(name, shapes)
        shapes.added.append(path)
        return "added-\(shapes.added.count)"
    }

    mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws {
        history.record(name, shapes, key: drag.map { "\(name):\($0)" })
        shapes.path.path = path
    }

    static let catalog = try? CommandCatalog<GalleryPenBoard>(app: "gallery", PathCommands.specs(GalleryPenBoard.self), history: { $0.history })

    /// Runs `intent`'s command; the log line: the step it made, or why it was refused, then the intent.
    mutating func send(_ intent: PathIntent) -> String {
        let command = intent.command
        guard let catalog = Self.catalog else { return "\(command.id) [no catalog] \(intent)" }
        do {
            let outcome = try catalog.run(command.id, params: command.params, on: &self)
            return "\(command.id) [\(outcome.undoStep ?? "no step"), \(history.steps.count) in History] \(intent)"
        } catch { return "\(command.id) [refused: \(error.description)] \(intent)" }
    }

    /// The log after `line`: a line whose step folded into the open one (same command, same step count) replaces the
    /// last line, so one drag is one line; the newest 200 lines stay.
    static func logging(_ line: String, after log: [String]) -> [String] {
        var log = log
        let head = { (line: String) in line.prefix { $0 != "]" } }
        if let last = log.last, !line.contains("no step"), !line.contains("[refused"), head(last) == head(line) { log.removeLast() }
        log.append(line)
        return Array(log.suffix(200))
    }

    /// Takes back the last step; false when there is none. The selection is cleared, since its points may be gone.
    mutating func undo() -> Bool {
        var current = shapes
        let moved = history.undo { old in defer { current = old }; return current }
        shapes = current
        if moved { anchorSelection = Selection() }
        return moved
    }
}

struct GalleryPenPathsPage: View {
    @State private var tool = PenTool.pen
    @State private var board = GalleryPenBoard()
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            SegmentedTabs(
                "Tool", tabs: PenTool.allCases.map { InspectorOption(id: $0, title: $0.title) }, selection: tool,
                id: "suite.gallery.pen-tool"
            ) { tool = $0 }
            .fixedSize()
            SuiteColor.artboard
                .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
                .overlay(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        if !board.shapes.added.isEmpty {
                            let parts = PathMarks.parts(board.shapes.added.flatMap(\.contours), toView: .identity)
                            PathMarks.outline(anchors: parts.anchors, segments: parts.segments, zoom: 1)
                                .stroke(SuiteColor.overlayInk, lineWidth: 1)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        PathEditOverlay(draft: board.penDraft, path: board.pathInEdit, selection: board.anchorSelection, tool: tool, zoom: 1) {
                            log = GalleryPenBoard.logging(board.send($0), after: log)
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: SuiteRadius.medium))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Pen canvas")
                .accessibilityValue("One sample path")
                .accessibilityIdentifier("suite.gallery.pen-canvas")
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
