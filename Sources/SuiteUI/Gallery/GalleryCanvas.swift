// GalleryCanvas.swift: the gallery's canvas pages (canvas-marks CM-11).
// `canvas` and `canvas-pt` put a 400 x 300 document in a CanvasViewport with
// a zoom pill (`suite.gallery.canvas.zoom`, "100 %"); the page takes the
// zoom keys itself through CanvasNavigating, so ⌘= walks the live stops and,
// under -SuiteGalleryFakes, the fake's doubling. A tool drag logs once on its
// end in document pixels (`drag (0,0)→(100,0) ends 1`); a Space-drag pans and
// logs nothing. `canvas-pt`'s ruler corner reads "pt" (SJ9). `marks` draws
// every canvas mark over one document at 100 % or 400 %: SelectionHandlesEditor
// (`handle bottomRight`, `keepAspect` with ⇧, the box on end, `rotate 90`),
// each hit frame's smallest side, the point mark's on-screen size, the
// grid's line count and a drag through the marks (SJ10, SJ21). Its chips
// clear the selection (no handles) and the grid (cells 0, no lines).
// `surface` and `surface-empty` show CanvasSurface with a 400 x 300 artboard
// and a 0 x 0 one, which draws 1 x 1 pt, and log the artboard's rect
// (SJ26). Every page's log is the element `suite.gallery.log`. `probe` is
// the one-element page the probe journeys read.
import AppKit
import SuiteKernel
import SwiftUI

enum GalleryCanvas {
    @MainActor static let pages: GalleryPages = [
        "canvas": { AnyView(GalleryViewportPage(unit: "px")) },
        "canvas-pt": { AnyView(GalleryViewportPage(unit: "pt")) },
        "marks": { AnyView(GalleryMarksPage()) },
        "surface": { AnyView(GallerySurfacePage(artboard: CGSize(width: 400, height: 300))) },
        "surface-empty": { AnyView(GallerySurfacePage(artboard: .zero)) },
        "probe": { AnyView(GalleryProbePage()) },
    ]

    /// Every page's document, in pixels.
    static let document = CGSize(width: 400, height: 300)

    /// A zoom as the pill reads it: "200 %".
    static func percent(_ zoom: Double) -> String { "\(Int((zoom * 100).rounded())) %" }

    /// A point as the log writes it: "(100,0)", whole pixels.
    static func point(_ p: CGPoint) -> String { "(\(Int(p.x.rounded())),\(Int(p.y.rounded())))" }

    /// A size as the log writes it: "12×12".
    static func size(_ s: CGSize) -> String { "\(Int(s.width.rounded()))×\(Int(s.height.rounded()))" }

    /// The handle a resize took, from which of the box's edges moved; nil when none did.
    static func handle(from start: CGRect, to next: CGRect) -> String? {
        let moved = { (a: CGFloat, b: CGFloat) in abs(a - b) > 0.001 }
        let v = moved(start.minY, next.minY) ? "top" : moved(start.maxY, next.maxY) ? "bottom" : ""
        let h = moved(start.minX, next.minX) ? "left" : moved(start.maxX, next.maxX) ? "right" : ""
        if v.isEmpty { return h.isEmpty ? nil : h }
        return h.isEmpty ? v : v + h.prefix(1).uppercased() + h.dropFirst()
    }
}

/// A page's log: the newest 40 lines, each drag's end counted. The whole log
/// is the label of `suite.gallery.log`; the newest line shows at the foot.
private struct GalleryCanvasLog {
    private(set) var entries: [String] = []
    private(set) var drags = 0

    mutating func add(_ line: String) {
        entries = Array((entries + [line]).suffix(40))
    }

    /// One drag's end: `<what> ends <n>`.
    mutating func ended(_ what: String) {
        drags += 1
        add("\(what) ends \(drags)")
    }
}

private struct GalleryCanvasLogLine: View {
    let log: GalleryCanvasLog

    var body: some View {
        let all = log.entries.joined(separator: "\n")
        HStack(spacing: SuiteSpacing.s) {
            Text(log.entries.last ?? "Drag on the canvas")
                .font(SuiteFont.timecode)
                .foregroundStyle(SuiteColor.secondaryText)
                .lineLimit(1)
                .accessibilityHidden(true)
            ProbeElement("suite.gallery.log", label: all, value: all, size: CGSize(width: 1, height: 1))
        }
    }
}

/// `canvas` and `canvas-pt`: the viewport, its zoom pill and the drag log.
private struct GalleryViewportPage: View {
    let unit: String
    @Environment(\.galleryRequest) private var request
    @State private var zoom = 1.0
    @State private var viewport = CGSize.zero
    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?
    @State private var log = GalleryCanvasLog()

    private var navigation: any CanvasNavigating {
        request?.fakes == true ? FakeCanvasNavigating() : SuiteCanvasNavigating()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text(GalleryCanvas.percent(zoom))
                .font(SuiteFont.timecode)
                .accessibilityElement()
                .accessibilityLabel(GalleryCanvas.percent(zoom))
                .accessibilityIdentifier("suite.gallery.canvas.zoom")
            CanvasViewport(
                documentSize: GalleryCanvas.document, zoom: zoom, rulerUnit: unit,
                onSize: { viewport = $0 },
                onDrag: { from, to in
                    if dragStart == nil { dragStart = from }
                    dragEnd = to
                },
                onDragEnd: endDrag,
                onKey: key
            ) {
                SuiteColor.artboard
            } overlay: {
                EmptyView()
            }
            GalleryCanvasLogLine(log: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    /// ⌘= and ⌘- step the zoom, ⌘0 fits; every other key goes on to the viewport.
    private func key(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.contains(.command) else { return .ignored }
        let next: Double
        switch press.key {
        case "=", "+": next = navigation.zoomedIn(from: zoom)
        case "-": next = navigation.zoomedOut(from: zoom)
        case "0":
            next = navigation.fit(
                document: PlaneExtent(width: GalleryCanvas.document.width, height: GalleryCanvas.document.height),
                in: PlaneExtent(width: viewport.width, height: viewport.height), margin: Double(SuiteSpacing.xxl))
        default: return .ignored
        }
        zoom = next
        log.add("zoom \(next.formatted(.number.precision(.fractionLength(0...2))))")
        return .handled
    }

    private func endDrag() {
        guard let start = dragStart, let end = dragEnd else { return }
        log.ended("drag \(GalleryCanvas.point(start))→\(GalleryCanvas.point(end))")
        dragStart = nil
        dragEnd = nil
    }
}

/// `marks`: every canvas mark over one document, with the readouts SJ10 and SJ21 check.
private struct GalleryMarksPage: View {
    private static let point = CGPoint(x: 320, y: 80)
    private static let cells = 3
    @State private var zoom = 1.0
    @State private var selection: CGRect? = CGRect(x: 60, y: 60, width: 160, height: 120)
    @State private var grid = true
    @State private var dragStart: CGRect?
    @State private var turned: Double?
    @State private var drags = (from: CGPoint?.none, to: CGPoint?.none)
    @State private var log = GalleryCanvasLog()

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(spacing: SuiteSpacing.xs) {
                chip("suite.gallery.marks.zoom", "400 %", zoom == 4)
                chip("suite.gallery.marks.selection", "Selection", selection != nil)
                chip("suite.gallery.marks.grid", "Grid", grid)
            }
            CanvasViewport(
                documentSize: GalleryCanvas.document, zoom: zoom,
                onDrag: { from, to in drags = (drags.from ?? from, to) },
                onDragEnd: endCanvasDrag
            ) {
                SuiteColor.artboard
            } overlay: {
                marks
            }
            GalleryCanvasLogLine(log: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
        .onAppear(perform: measure)
    }

    @ViewBuilder private var marks: some View {
        let board = CGRect(origin: .zero, size: CGSize(width: 400 * zoom, height: 300 * zoom))
        ZStack(alignment: .topLeading) {
            ViewportGuideMarks(guides: [.vertical(x: 200), .horizontal(y: 150)], zoom: zoom, viewport: board)
            PathMarks(
                anchors: [
                    PathAnchor(point: CGPoint(x: 40, y: 260), kind: .corner),
                    PathAnchor(point: CGPoint(x: 140, y: 220), kind: .smooth,
                               handleIn: CGPoint(x: 110, y: 250), handleOut: CGPoint(x: 170, y: 190)),
                ],
                segments: [PathSegment(from: 0, to: 1)], zoom: zoom)
            MotionPathMarks(points: [CGPoint(x: 260, y: 260), CGPoint(x: 300, y: 230), CGPoint(x: 360, y: 250)],
                            zoom: zoom)
            if grid {
                CanvasGrid(rect: CGRect(x: 240, y: 20, width: 140, height: 120), cells: Self.cells, zoom: zoom)
            }
            CanvasPointMark(point: Self.point, zoom: zoom)
            if let selection {
                SelectionOutline(rect: selection, zoom: zoom)
                SelectionHandlesEditor(rect: selection, zoom: zoom, onResize: resize, onRotate: { turned = $0 },
                                       onEnd: endHandleDrag)
            }
        }
    }

    /// One switch: a ChipRow of one chip, so its identifier lands on that chip alone.
    private func chip(_ id: String, _ title: String, _ isOn: Bool) -> some View {
        ChipRow([ChipItem(id: id, title: title, isOn: isOn)]) { toggle($0) }
            .help(title)
            .suiteControl(id: id, enabled: true, reason: nil)
    }

    private func toggle(_ id: String) {
        switch id {
        case "suite.gallery.marks.zoom": zoom = zoom == 4 ? 1 : 4
        case "suite.gallery.marks.selection":
            selection = selection == nil ? CGRect(x: 60, y: 60, width: 160, height: 120) : nil
        default: grid.toggle()
        }
        measure()
    }

    /// The readouts that hold at one zoom: hit frames, the point mark, the grid.
    private func measure() {
        if let selection {
            let hits = SelectionHandleDrag.hitRects(rect: selection, zoom: zoom).values
            let side = CGSize(width: hits.map(\.width).min() ?? 0, height: hits.map(\.height).min() ?? 0)
            log.add("hits \(hits.count) min \(GalleryCanvas.size(side))")
        } else {
            log.add("handles none")
        }
        let mark = CanvasPointMark.frame(point: Self.point, zoom: zoom).size
        log.add("point \(GalleryCanvas.size(mark)) zoom \(Int(zoom))")
        let lines = CanvasGrid.lines(rect: CGRect(x: 240, y: 20, width: 140, height: 120),
                                     cells: grid ? Self.cells : 0, zoom: zoom)
        log.add("grid \(lines.vertical.count)×\(lines.horizontal.count)")
    }

    private func resize(_ next: CGRect) {
        guard let current = selection else { return }
        if dragStart == nil {
            dragStart = current
            log.add("handle \(GalleryCanvas.handle(from: current, to: next) ?? "none")")
            if NSEvent.modifierFlags.contains(.shift) { log.add("keepAspect") }
        }
        selection = next
    }

    private func endHandleDrag() {
        if let turned {
            log.ended("rotate \(Int(turned.rounded()))")
        } else if let box = selection {
            log.ended("rect \(GalleryCanvas.point(box.origin)) \(GalleryCanvas.size(box.size))")
        }
        dragStart = nil
        turned = nil
    }

    private func endCanvasDrag() {
        guard let from = drags.from, let to = drags.to else { return }
        log.ended("drag \(GalleryCanvas.point(from))→\(GalleryCanvas.point(to))")
        drags = (nil, nil)
    }
}

/// `surface` and `surface-empty`: CanvasSurface's artboard, centred, and its rect.
private struct GallerySurfacePage: View {
    let artboard: CGSize
    @State private var log = GalleryCanvasLog()

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            GeometryReader { geometry in
                CanvasSurface(artboard: artboard)
                    .onAppear { record(geometry.size) }
                    .onChange(of: geometry.size) { _, size in record(size) }
            }
            GalleryCanvasLogLine(log: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    private func record(_ size: CGSize) {
        let board = CanvasSurface<EmptyView>.fitted(artboard, in: size, inset: SuiteSize.canvasInset)
        log.add("artboard \(GalleryCanvas.size(board.size)) at \(GalleryCanvas.point(board.origin))")
    }
}

/// `probe`: a ProbeElement under a caption naming it (it draws nothing itself).
private struct GalleryProbePage: View {
    var body: some View {
        Text("suite.gallery.probe carries \"Saved\" as its label.")
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { ProbeElement("suite.gallery.probe", label: "Saved", value: "Saved") }
    }
}
