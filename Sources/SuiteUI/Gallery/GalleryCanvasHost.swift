// GalleryCanvasHost.swift: the gallery's `canvas-host` page (CH-3, live since
// CH-9): CanvasHost over a 4096 x 2160 document of twenty flat swatch tiles,
// handed to the host through a CanvasTileSet (premultiplied sRGB, only the
// tiles it replaced count as dirty). The log is the page's delegate: its one
// observed change per drag is on `endDrag`, and hover names the tile under the
// pointer from a CanvasHitMap. The status line under the log reads the live
// RenderingPreference; it is its own view, so a hover or a switch never runs
// the page's body. The page runs live with or without -SuiteGalleryFakes.
import CoreGraphics
import Observation
import SwiftUI

enum GalleryCanvasHost {
    static let name = "canvas-host"
    /// The status line under the log: the hovered mark and the backend in use.
    static let statusID = "suite.gallery.canvas-host.status"

    @MainActor static let pages: GalleryPages = [name: { AnyView(CanvasHostPage()) }]
}

/// The page's document: twenty tiles in a 4 x 5 grid over 4096 x 2160, each a
/// flat swatch, as the tile set handed them on (premultiplied sRGB).
struct GalleryCanvasDocument: CanvasContentProviding {
    static let size = CGSize(width: 4096, height: 2160)
    static let columns = 4
    static let rows = 5

    let documentSize = GalleryCanvasDocument.size
    /// Every tile, its image the one the tile set shows.
    let all: [CanvasTile]
    /// The tiles the tile set replaced when this document was built.
    let dirty: [CanvasTile]

    func tiles(dirtyOnly: Bool) -> [CanvasTile] { dirtyOnly ? dirty : all }

    /// Each tile's rect, row by row.
    static var rects: [CanvasTileRect] {
        let (width, height) = (Int(size.width) / columns, Int(size.height) / rows)
        return (0..<rows).flatMap { row in
            (0..<columns).map { CanvasTileRect(x: $0 * width, y: row * height, width: width, height: height) }
        }
    }

    /// The hover name of the tile at `index` in `rects`: "Tile <row>-<column>", from 1.
    static func markID(_ index: Int) -> String { "Tile \(index / columns + 1)-\(index % columns + 1)" }

    /// One mark per tile, so hover names the tile under the pointer.
    static var hitMap: CanvasHitMap {
        var map = CanvasHitMap()
        for (index, rect) in rects.enumerated() {
            map.addRect(id: markID(index), CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
        }
        return map
    }

    /// The swatches through `tileSet`: its images, and as dirty the tiles whose image it replaced.
    @MainActor static func make(through tileSet: CanvasTileSet = CanvasTileSet()) -> GalleryCanvasDocument {
        let swatches = rects.enumerated().map { CanvasTile(rect: $1, image: swatch($0)) }
        let before = swatches.map { tileSet.image(at: $0.rect) }
        tileSet.apply(swatches, documentSize: size)
        let all = swatches.map { CanvasTile(rect: $0.rect, image: tileSet.image(at: $0.rect)) }
        let dirty = zip(all, before).filter { $0.0.image !== $0.1 }.map(\.0)
        return GalleryCanvasDocument(all: all, dirty: dirty)
    }

    /// The document's colours: palette swatches, the same in every appearance (document pixels, not chrome).
    private static let swatches: [SuiteHex] = [
        SuitePalette.accent, SuitePalette.stateSuccess, SuitePalette.stateKeyed, SuitePalette.stateSuggested,
        SuitePalette.onionBefore,
    ]

    /// A 4 x 4 opaque sRGB image of one swatch, with no alpha, so the tile set redraws it premultiplied.
    private static func swatch(_ index: Int) -> CGImage? {
        let hex = swatches[index % swatches.count].light
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.setFillColor(
            CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return context.makeImage()
    }
}

/// The page's delegate: counts drags; logs each finished drag and key; names the hovered mark.
@MainActor @Observable final class CanvasHostLog: CanvasInputDelegate {
    private(set) var lines = ["Drag on the canvas."]
    /// The mark under the pointer, from the hit map; nil off every mark.
    private(set) var hovered: String?
    @ObservationIgnored private(set) var drags = 0
    @ObservationIgnored private(set) var endDrags = 0
    @ObservationIgnored private var samples = 0
    let hitMap: CanvasHitMap

    init(hitMap: CanvasHitMap = GalleryCanvasDocument.hitMap) { self.hitMap = hitMap }

    func drag(from: CGPoint, to: CGPoint, pressure: Double, modifiers: EventModifiers) { (drags, samples) = (drags + 1, samples + 1) }
    func key(_ press: KeyPress) -> KeyPress.Result { log("key \(press.characters)"); return .handled }
    func endDrag() {
        endDrags += 1
        log("endDrag after \(samples) samples")
        samples = 0
    }

    /// Names the mark under `point`; a move that stays on one mark writes nothing.
    func hover(_ point: CGPoint?) {
        let mark = point.flatMap { hitMap.hit($0) }
        if mark != hovered { hovered = mark }
    }

    private func log(_ line: String) { lines = Array((lines + [line]).suffix(3)) }
}

/// CanvasHost on the gallery document, its event log and status line under it.
struct CanvasHostPage: View {
    #if DEBUG
    static var bodyRuns = 0
    #endif
    @State private var log: CanvasHostLog
    @State private var document: GalleryCanvasDocument
    @State private var rendering: RenderingMenuModel

    init(log: CanvasHostLog = CanvasHostLog(), suiteName: String = RenderingPreference.suiteName) {
        _log = State(initialValue: log)
        _document = State(initialValue: GalleryCanvasDocument.make())
        _rendering = State(initialValue: RenderingMenuModel(preference: RenderingPreference(suiteName: suiteName)))
    }

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(spacing: 0) {
            CanvasHost(content: document, delegate: log)
            Text(log.lines.joined(separator: "\n")).font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(SuiteSpacing.s)
                .accessibilityIdentifier("suite.gallery.canvas-host.log")
            CanvasHostStatusLine(log: log, rendering: rendering)
        }
    }
}

/// "<mark> · <status>": the hovered mark and the live preference's backend. Its own body, so the page's never reruns.
private struct CanvasHostStatusLine: View {
    let log: CanvasHostLog
    let rendering: RenderingMenuModel

    var body: some View {
        Text(Self.line(hovered: log.hovered, choice: rendering.choice, status: rendering.statusLine))
            .font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(SuiteSpacing.s)
            .accessibilityIdentifier(GalleryCanvasHost.statusID)
    }

    static func line(hovered: String?, choice: RenderingChoice, status: String) -> String {
        "\(hovered ?? "No mark") · Rendering: \(RenderingMenuItem.title(choice)) · \(status)"
    }
}
