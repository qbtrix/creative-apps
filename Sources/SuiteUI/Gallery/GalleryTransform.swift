// GalleryTransform.swift: the gallery's `transform-handles` page
// (transform-tools TT-2, live in TT-7). A 200 × 120 TransformBox at (100, 80)
// on the 400 × 300 document, its SelectionHandlesEditor turned with it and
// TransformRows beside it, all driving a local TransformTarget with a
// History: every knob sample, handle sample and row edit runs its
// TransformCommands command through the catalog, a drag's samples under one
// token so the drag is one undo step. Each command logs a line. The box is
// the element `suite.gallery.transform-box`, at the turned box's bounds; the
// editor draws the one outline, turned (#4625). The log is `suite.gallery.log`.
import SuiteKernel
import SwiftUI

/// The page's local document: one box and its History, a drag's samples folded into one step.
struct GalleryTransformBoard: TransformTarget {
    private(set) var item = TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200))
    private(set) var history = History<TransformBox>()
    private var drag: String?
    private var turnSoFar = 0.0

    var transformSelection: TransformBox? { item }
    var transformHelp: String? { nil }

    mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        history.record(name, item, key: drag.map { CoalesceKey.key("transform", drag: $0) })
        item = t
    }

    static let catalog = try? CommandCatalog<GalleryTransformBoard>(
        app: "gallery", TransformCommands.specs(GalleryTransformBoard.self), history: { $0.history })

    /// A knob sample, the turn so far since the press: `transform.rotate` by what it turned since the last one.
    mutating func knob(turned degrees: Double) -> String {
        let token = dragToken()
        let by = degrees - turnSoFar
        turnSoFar = degrees
        return send(.rotate(by: by, drag: token))
    }

    /// A handle sample, the box so far: `transform.set` keeping the turn.
    mutating func resize(to box: Rect) -> String {
        send(.set(TransformBox(box: box, degrees: item.degrees), drag: dragToken()))
    }

    /// The release: closes the drag's run, so the next drag is its own step.
    mutating func end() -> String {
        let line = "drag ends, \(history.steps.count) in History"
        (drag, turnSoFar) = (nil, 0)
        history.endRun()
        return line
    }

    /// Runs `intent`'s command on the board through the catalog; the log line.
    mutating func send(_ intent: TransformIntent) -> String {
        let command = intent.command
        guard let catalog = Self.catalog else { return "\(command.id): no catalog" }
        do {
            let outcome = try catalog.run(command.id, params: command.params, on: &self)
            return command.id + (outcome.undoStep.map { ": \($0), \(history.steps.count) in History" } ?? "")
        } catch {
            return "\(command.id): refused, \(error)"
        }
    }

    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = item
        let undid = history.undo { old in
            defer { current = old }
            return current
        }
        item = current
        return undid
    }

    /// The open drag's token, or a new one on its first sample.
    private mutating func dragToken() -> String {
        let token = CoalesceKey.token(drag)
        drag = token
        return token
    }
}

/// `transform-handles`: one box, its handles and the transform rows.
struct GalleryTransformPage: View {
    @State private var board: GalleryTransformBoard
    @State private var log = GalleryCanvasLog()

    /// The page on `board`: a fresh box unless a snapshot hands it a turned one.
    init(board: GalleryTransformBoard = GalleryTransformBoard()) { _board = State(initialValue: board) }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                CanvasViewport(documentSize: GalleryCanvas.document, zoom: 1) {
                    SuiteColor.artboard
                } overlay: {
                    GalleryTransformMarks(item: board.item,
                                          onResize: { log.add(board.resize(to: Self.kernel($0))) },
                                          onRotate: { log.add(board.knob(turned: $0)) },
                                          onEnd: { log.add(board.end()) })
                }
                TransformRows(selection: board.item, help: board.transformHelp, flipHelp: board.flipHelp) {
                    log.add(board.send($0))
                }
                .frame(width: SuiteSize.inspectorWidth.ideal)
            }
            GalleryCanvasLogLine(log: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    nonisolated private static func kernel(_ r: CGRect) -> Rect {
        Rect(minX: Double(r.minX), minY: Double(r.minY), maxX: Double(r.maxX), maxY: Double(r.maxY))
    }
}

/// The box over the canvas: its probe at the turned box's bounds, and the handles turned with it,
/// which draw the box's one outline. Takes the board's item; the gestures go out through the closures.
struct GalleryTransformMarks: View {
    let item: TransformBox
    let onResize: @MainActor (CGRect) -> Void
    let onRotate: @MainActor (Double) -> Void
    let onEnd: @MainActor () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ProbeElement("suite.gallery.transform-box", label: "Transform box", rect: Self.probeRect(item))
            SelectionHandlesEditor(rect: Self.cg(item.box), degrees: item.degrees, zoom: 1,
                                   onResize: onResize, onRotate: onRotate, onEnd: onEnd)
        }
    }

    /// The probe's frame in document pixels: the axis-aligned bounds of `item`'s turned corners.
    nonisolated static func probeRect(_ item: TransformBox) -> CGRect { cg(TransformRules.bounds(of: item)) }

    /// A kernel rect as a CGRect.
    nonisolated static func cg(_ r: Rect) -> CGRect { CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height) }
}
