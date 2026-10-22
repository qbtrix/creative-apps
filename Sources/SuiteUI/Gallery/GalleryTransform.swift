// GalleryTransform.swift: the gallery's `transform-handles` page
// (transform-tools TT-2, live in TT-7). A 200 × 120 TransformBox at (100, 80)
// on the 400 × 300 document, its SelectionHandlesEditor turned with it and
// TransformRows beside it, all driving a local TransformTarget with a
// History: every knob sample, handle sample and row edit runs its
// TransformCommands command through the catalog, a drag's samples under one
// token so the drag is one undo step. Each command logs a line. The box is
// the element `suite.gallery.transform-box`; the log is `suite.gallery.log`.
import SuiteKernel
import SwiftUI

/// The page's local document: one box and its History, a drag's samples folded into one step.
struct GalleryTransformBoard: TransformTarget {
    private(set) var item = TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200))
    private(set) var history = History<TransformBox>()
    private var drag: String?
    private var turnSoFar = 0.0
    private var drags = 0

    var transformSelection: TransformBox? { item }
    var transformHelp: String? { nil }

    mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        history.record(name, item, key: drag.map { "transform:\($0)" })
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
        let line = "\(drag ?? "drag") ends, \(history.steps.count) in History"
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
        if let drag { return drag }
        drags += 1
        drag = "drag-\(drags)"
        return "drag-\(drags)"
    }
}

/// `transform-handles`: one box, its handles and the transform rows.
struct GalleryTransformPage: View {
    @State private var board = GalleryTransformBoard()
    @State private var log = GalleryCanvasLog()

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                CanvasViewport(documentSize: GalleryCanvas.document, zoom: 1) {
                    SuiteColor.artboard
                } overlay: {
                    ZStack(alignment: .topLeading) {
                        ProbeElement("suite.gallery.transform-box", label: "Transform box", rect: rect)
                        SelectionOutline(rect: rect, zoom: 1)
                        SelectionHandlesEditor(rect: rect, degrees: board.item.degrees, zoom: 1,
                                               onResize: { log.add(board.resize(to: Self.kernel($0))) },
                                               onRotate: { log.add(board.knob(turned: $0)) },
                                               onEnd: { log.add(board.end()) })
                    }
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

    /// The board's box in document pixels, as the handles take it.
    private var rect: CGRect {
        let b = board.item.box
        return CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height)
    }

    nonisolated private static func kernel(_ r: CGRect) -> Rect {
        Rect(minX: Double(r.minX), minY: Double(r.minY), maxX: Double(r.maxX), maxY: Double(r.maxY))
    }
}
