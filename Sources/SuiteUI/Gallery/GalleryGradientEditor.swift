// GalleryGradientEditor.swift: the gallery's `gradient-editor` page (gradient-fill GF-2; GF-8 runs its intents through
// `GradientCommands` on a local target with a `History`). A preview rect painted with the page's own fill (a two-stop
// linear fill, blue to white, 0°, in the preview's box) beside GradientEditor. Each intent the editor sends runs as its
// command in `GalleryGradientBoard`'s catalog and writes one line, `<command id> [<step>, <n> in History] <intent>` or
// `<command id> [refused: <why>] <intent>`, to `suite.gallery.log` (the intent last, so a drag token ends the line), so
// a stop drag shows as one undo step and the preview follows with no rule of its own. The preview's value reads "<type>, <n> stops, <angle>°" for the journey. The page is its own area
// in `SuiteGallery.areas`.
import SuiteKernel
import SwiftUI

enum GalleryGradientEditor {
    static let name = "gradient-editor"

    static let pages: GalleryPages = [name: { AnyView(GalleryGradientEditorPage()) }]

    /// The preview's box, the space the page's fill points are in.
    static let box = Rect(minX: 0, minY: 0, maxX: Double(SuiteSize.contentMinimum.width), maxY: Double(SuiteSize.contentMinimum.height))

    /// The page's fill to start: blue to white, left to right across the box's middle.
    static let start = Fill.linear(
        stops: [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 1)), GradientStop(offset: 1, color: .white)],
        start: Point(x: box.minX, y: (box.minY + box.maxY) / 2), end: Point(x: box.maxX, y: (box.minY + box.maxY) / 2))

    /// `fill` after `intent`, through the kernel's rules, with no History; an edit the rules refuse leaves it as it
    /// is. The render budget tests' child pages apply intents with it; the page itself runs them on its board.
    static func applied(_ intent: GradientIntent, to fill: Fill) -> Fill {
        switch intent {
        case .type(let type): GradientRules.converted(fill, to: type, in: box)
        case .add(let offset): GradientRules.addingStop(fill, at: offset)?.fill ?? fill
        case .move(let index, let offset, _): GradientRules.movingStop(fill, index: index, to: offset).fill
        case .remove(let index): GradientRules.removingStop(fill, index: index) ?? fill
        case .color(let index, let color, _): GradientRules.recoloring(fill, index: index, to: color)
        case .angle(let degrees, _): GradientRules.rotated(fill, to: degrees, in: box)
        }
    }

    /// The preview's value: "linear, 3 stops, 45°"; a radial has no angle and a solid no stops.
    static func summary(_ fill: Fill) -> String {
        let type = GradientRules.type(of: fill)
        guard type != .solid else { return type.rawValue }
        let angle = GradientRules.angle(of: fill).map { ", \(GradientEditorText.angle($0))" } ?? ""
        return "\(type.rawValue), \(fill.stops.count) stops\(angle)"
    }
}

/// The page's live target: one fill in the preview's box and the History its steps go in; the fill commands run on it.
struct GalleryGradientBoard: GradientFillTarget {
    private(set) var fill = GalleryGradientEditor.start
    private(set) var history = History<Fill>()
    var fillSelection: FillSelection? { FillSelection(fill: fill, box: GalleryGradientEditor.box) }
    var fillHelp: String? { nil }

    mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        history.record(name, self.fill, key: drag.map { "\(name):\($0)" })
        self.fill = GradientRules.mapped(fill, from: box, to: GalleryGradientEditor.box)
    }

    static let catalog = try? CommandCatalog<GalleryGradientBoard>(app: "gallery", GradientCommands.specs(GalleryGradientBoard.self), history: { $0.history })

    /// Runs `intent`'s command; the log line: the step it made, or why it was refused, then the intent.
    mutating func send(_ intent: GradientIntent) -> String {
        let command = intent.command
        guard let catalog = Self.catalog else { return "\(command.id) [no catalog] \(intent)" }
        do {
            let outcome = try catalog.run(command.id, params: command.params, on: &self)
            return "\(command.id) [\(outcome.undoStep ?? "no step"), \(history.steps.count) in History] \(intent)"
        } catch { return "\(command.id) [refused: \(error)] \(intent)" }
    }

    /// Takes back the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = fill
        let moved = history.undo { old in defer { current = old }; return current }
        fill = current
        return moved
    }
}

/// The `gradient-editor` page: the preview, the editor and the log under them.
struct GalleryGradientEditorPage: View {
    @State private var board = GalleryGradientBoard()
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                GalleryGradientPreview(fill: board.fill)
                ScrollView {
                    InspectorSection("Fill") {
                        GradientEditor(fill: board.fill, box: GalleryGradientEditor.box, onIntent: send)
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

    private func send(_ intent: GradientIntent) {
        log.append(board.send(intent))
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// The preview: the box painted with `fill`. Static text, so its summary reaches AXValue, what the journey's
/// `.value` reads; a plain element sends it only as its value description (#4229, #262).
private struct GalleryGradientPreview: View {
    let fill: Fill

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: fill.shading(in: rect, box: GalleryGradientEditor.box))
        }
        .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .accessibilityElement()
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel("Fill preview")
        .accessibilityValue(GalleryGradientEditor.summary(fill))
        .accessibilityIdentifier("suite.gallery.gradient-editor.preview")
    }
}
