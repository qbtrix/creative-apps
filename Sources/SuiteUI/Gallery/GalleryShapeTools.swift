// GalleryShapeTools.swift: the gallery's `shape-tools` page (shape-tools SH-2, live in SH-7). ShapeToolOptions over a
// canvas, both driving a local ShapeTarget with a History: an option runs `tool.shape`, a drag runs `shape.draw` (one
// undo step), and the canvas paints each drawn shape's `ShapeRules.path`. Each command logs a line.
import AppKit
import SuiteKernel
import SwiftUI

enum GalleryShapeTools { static let name = "shape-tools" }

/// One shape on the page's board: its id, recipe and box.
struct GalleryShape: Hashable, Sendable {
    let id: String, spec: ShapeSpec, box: Rect
}

/// The page's local document: the tool's options and the shapes drawn, one History step each.
struct GalleryShapeBoard: ShapeTarget {
    private(set) var shapes: [GalleryShape] = []
    private(set) var history = History<Int>()
    private(set) var shapeTool = ShapeSpec.defaults(.rectangle)
    var shapeHelp: String? { nil }

    mutating func pickShapeTool(_ spec: ShapeSpec) { shapeTool = spec }

    mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        let id = "shape-\(shapes.count + 1)"
        shapes.append(GalleryShape(id: id, spec: spec, box: box))
        history.record(name, shapes.count - 1)
        history.endRun()
        return id
    }

    static let catalog = try? CommandCatalog<GalleryShapeBoard>(app: "gallery", ShapeCommands.specs(GalleryShapeBoard.self), history: { $0.history })

    /// The shape a drag from `from` to `to` draws with `tool`'s options: `ShapeRules.dragged`'s box and line ends.
    /// Nil for a click.
    static func shape(_ tool: ShapeSpec, from: Point, to: Point, modifiers: EditModifiers) -> GalleryShape? {
        guard let drawn = ShapeRules.dragged(tool.kind, from: from, to: to, modifiers: modifiers) else { return nil }
        var spec = tool
        (spec.start, spec.end) = (drawn.spec.start, drawn.spec.end)
        return GalleryShape(id: "", spec: spec, box: drawn.box)
    }

    /// Runs `tool.shape` for `intent`; the log line.
    mutating func pick(_ intent: ShapeIntent) -> String {
        let command = intent.command
        return "\(command.id) \(intent)" + run(command.id, command.params)
    }

    /// Runs `shape.draw` for the drag with the tool's options; the log line.
    mutating func drag(from: Point, to: Point, modifiers: EditModifiers) -> String {
        guard let drawn = Self.shape(shapeTool, from: from, to: to, modifiers: modifiers) else {
            return "drag \(shapeTool.kind.rawValue): nothing to draw"
        }
        let (spec, box) = (drawn.spec, drawn.box)
        let params: [String: JSONValue] = [
            "kind": .string(spec.kind.rawValue), "x": .number(box.minX), "y": .number(box.minY),
            "w": .number(box.width), "h": .number(box.height),
            "sides": .number(Double(spec.sides)), "points": .number(Double(spec.points)), "innerRatio": .number(spec.innerRatio),
            "cornerRadius": .number(spec.cornerRadius), "head": .number(spec.head),
            "x1": .number(spec.start.x), "y1": .number(spec.start.y), "x2": .number(spec.end.x), "y2": .number(spec.end.y),
        ]
        return "drag \(spec.kind.rawValue) \(Int(box.width)) x \(Int(box.height)): shape.draw" + run("shape.draw", .object(params))
    }

    /// Runs `id` on the board through the catalog; what it did, for the log.
    private mutating func run(_ id: String, _ params: JSONValue) -> String {
        guard let catalog = Self.catalog else { return ", no catalog" }
        do {
            let outcome = try catalog.run(id, params: params, on: &self)
            return outcome.undoStep.map { ", \($0) (\(history.steps.count) in History)" } ?? ""
        } catch {
            return ", refused: \(error)"
        }
    }

    /// The shape's `ShapeRules.path` as a path the canvas strokes; empty when the rules refuse it.
    static func painted(_ shape: GalleryShape) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        for element in (try? ShapeRules.path(shape.spec, in: shape.box))?.elements ?? [] {
            switch element {
            case .move(let to): path.move(to: CGPoint(x: to.x, y: to.y))
            case .line(let to): path.addLine(to: CGPoint(x: to.x, y: to.y))
            case .quad(let control, let to): path.addQuadCurve(to: CGPoint(x: to.x, y: to.y), control: CGPoint(x: control.x, y: control.y))
            case .cubic(let one, let two, let to):
                path.addCurve(to: CGPoint(x: to.x, y: to.y), control1: CGPoint(x: one.x, y: one.y), control2: CGPoint(x: two.x, y: two.y))
            case .close: path.closeSubpath()
            }
        }
        return path
    }
}

struct GalleryShapeToolsPage: View {
    @State private var board = GalleryShapeBoard()
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Shape tool").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            ShapeToolOptions(spec: board.shapeTool, help: ShapeRules.help(board.shapeTool)) { intent in
                log.append(board.pick(intent))
            }
            GalleryShapeCanvas(tool: board.shapeTool, shapes: board.shapes) { from, to, held in
                log.append(board.drag(from: from, to: to, modifiers: held))
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The page's canvas: the drawn shapes, and the shape under a drag in its own state so a drag sample redraws only it.
private struct GalleryShapeCanvas: View {
    let tool: ShapeSpec
    let shapes: [GalleryShape]
    let onDrawn: @MainActor (Point, Point, EditModifiers) -> Void
    @State private var live: GalleryShape?

    var body: some View {
        let (drawn, preview) = (shapes, live)
        Canvas { context, _ in
            for shape in drawn + (preview.map { [$0] } ?? []) {
                context.stroke(GalleryShapeBoard.painted(shape), with: .color(SuiteColor.overlayInk), lineWidth: 1)
            }
        }
        .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
        .background(SuiteColor.artboard)
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    live = GalleryShapeBoard.shape(tool, from: Self.point(value.startLocation), to: Self.point(value.location), modifiers: Self.held)
                }
                .onEnded { value in
                    live = nil
                    onDrawn(Self.point(value.startLocation), Self.point(value.location), Self.held)
                })
        .accessibilityElement().accessibilityLabel("Shape canvas")
        .accessibilityValue(shapes.last.map { "\(Int($0.box.width)) x \(Int($0.box.height))" } ?? "Empty")
        .accessibilityIdentifier("suite.gallery.shape-canvas")
    }

    nonisolated private static func point(_ location: CGPoint) -> Point { Point(x: location.x, y: location.y) }

    /// The modifiers held now: Shift and Option.
    @MainActor private static var held: EditModifiers {
        let flags = NSEvent.modifierFlags
        return EditModifiers(rawValue: (flags.contains(.shift) ? 1 : 0) | (flags.contains(.option) ? 2 : 0))
    }
}
