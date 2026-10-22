// GalleryAreaSelect.swift (area-selection AR-7): the gallery's `area-select` page, AreaToolOptions over AreaAnts on a
// local AreaSelectTarget fake: a drag runs the tool's `select.<shape>` in the shown mode, Feather `select.feather`, and
// each command logs a line. `GalleryAreaSelectSheet` is the snapshot: the bar in each mode and the ants on a lasso.
import AppKit
import Observation
import SuiteKernel
import SwiftUI

enum GalleryAreaSelect {
    static let name = "area-select"
    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryAreaSelectPage()) }]
    static let lasso = [(60, 50), (220, 40), (300, 140), (200, 230), (80, 190)].map { Point(x: $0.0, y: $0.1) }
}

/// The page's document: the area recipe, the outline the ants trace and one History step per command.
struct GalleryAreaBoard: AreaSelectTarget {
    private(set) var areaRecipe = AreaRecipe.empty, lastAreaRecipe: AreaRecipe?, history = History<Int>()
    private(set) var outline: [[Point]] = []
    var areaHelp: String? { nil }

    mutating func setAreaRecipe(_ recipe: AreaRecipe) throws {
        if !areaRecipe.isEmpty { lastAreaRecipe = areaRecipe }
        (areaRecipe, outline) = (recipe, recipe.isEmpty ? [] : outline)
        history.record("Select", history.steps.count)
        history.endRun()
    }

    static let catalog = try? CommandCatalog<GalleryAreaBoard>(app: "gallery", AreaSelectCommands.specs(GalleryAreaBoard.self), history: { $0.history })

    /// Runs the tool's command over `points` in `mode`; the log line.
    mutating func select(_ points: [Point], _ options: AreaOptions, mode: AreaCombine) -> String {
        guard let first = points.first else { return "nothing drawn" }
        let (xs, ys, reach) = (points.map(\.x), points.map(\.y), options.tool == .wand ? options.tolerance / 2 : 0)
        let (low, high) = (Point(x: (xs.min() ?? 0) - reach, y: (ys.min() ?? 0) - reach), Point(x: (xs.max() ?? 0) + reach, y: (ys.max() ?? 0) + reach))
        var params: [String: JSONValue] = ["mode": .string(mode.rawValue)]
        switch options.tool {
        case .rect, .ellipse:
            params.merge(["minX": .number(low.x), "minY": .number(low.y), "maxX": .number(high.x), "maxY": .number(high.y)]) { $1 }
        case .lasso, .polygon:
            params["points"] = .array(points.map { .object(["x": .number($0.x), "y": .number($0.y)]) })
        case .wand:
            params.merge(["x": .number(first.x), "y": .number(first.y), "tolerance": .number(options.tolerance),
                          "contiguous": .bool(options.contiguous), "allLayers": .bool(options.allLayers)]) { $1 }
        }
        let drawn = options.tool == .lasso || options.tool == .polygon ? points
            : [low, Point(x: high.x, y: low.y), high, Point(x: low.x, y: high.y)]
        let line = run(options.tool.command, .object(params))
        if !line.contains("refused") { outline = mode == .replace ? [drawn] : outline + [drawn] }
        return "\(options.tool.command) \(mode.rawValue)" + line
    }

    /// Runs `id` through the catalog; what it did, for the log.
    mutating func run(_ id: String, _ params: JSONValue) -> String {
        guard let catalog = Self.catalog else { return ", no catalog" }
        do { return try catalog.run(id, params: params, on: &self).undoStep.map { ", \($0) (\(history.steps.count) in History)" } ?? "" }
        catch { return ", refused: \(error)" }
    }
}

/// The drag in progress; read only by the ants layer, so a sample never runs the page's body.
@MainActor @Observable final class GalleryAreaDraft {
    private(set) var points: [Point] = []

    func add(_ point: Point) { points.append(point) }
    /// The drawn points, clearing the draft.
    func take() -> [Point] { defer { points = [] }; return points }
}

struct GalleryAreaSelectPage: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    @State private var board = GalleryAreaBoard()
    @State private var options = AreaOptions()
    @State private var draft = GalleryAreaDraft()
    @State private var log: [String] = []

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Area select").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            AreaToolOptions(options: options) { control, next in
                options = next
                log.append(control == .feather ? "select.feather" + board.run("select.feather", .object(["radius": .number(next.feather)]))
                    : "\(control.command(next.tool)) \(control.rawValue)")
            }
            SuiteColor.artboard.frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
                .overlay(alignment: .topLeading) { GalleryAreaAntsLayer(outline: board.outline, draft: draft) }
                .clipShape(.rect(cornerRadius: SuiteRadius.medium))
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { draft.add(Point(x: $0.location.x, y: $0.location.y)) }
                    .onEnded { _ in
                        let flags = NSEvent.modifierFlags
                        let held = EditModifiers(rawValue: (flags.contains(.shift) ? 1 : 0) | (flags.contains(.option) ? 2 : 0))
                        log.append(board.select(draft.take(), options, mode: AreaToolOptions.shownMode(options.mode, held: held)))
                    })
                .accessibilityElement().accessibilityLabel("Area canvas")
                .accessibilityValue("\(board.outline.count) shapes").accessibilityIdentifier("suite.gallery.area-canvas")
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityValue(log.joined(separator: "\n")).accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The only view that reads the draft: the ants over the outline and the drag in progress.
private struct GalleryAreaAntsLayer: View {
    let outline: [[Point]]
    let draft: GalleryAreaDraft

    var body: some View { AreaAnts(outline: outline, draft: draft.points, zoom: 1) }
}

/// The snapshot: the bar in each mode (the wand's last, with its rows) and the ants on a lasso with a polygon drawn.
struct GalleryAreaSelectSheet: View {
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            VStack(alignment: .leading, spacing: SuiteSpacing.l) {
                ForEach(AreaCombine.allCases, id: \.self) { mode in
                    AreaToolOptions(options: AreaOptions(tool: mode == .intersect ? .wand : .lasso, mode: mode, feather: 4)) { _, _ in }
                }
            }
            .frame(width: SuiteSize.inspectorWidth.ideal)
            SuiteColor.artboard.frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
                .overlay(alignment: .topLeading) {
                    AreaAnts(outline: [GalleryAreaSelect.lasso], draft: GalleryAreaSelect.lasso.map { Point(x: $0.x + 120, y: $0.y + 60) }, zoom: 1)
                }
                .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
