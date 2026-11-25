// PhotoSelect+Kernel.swift: Photo's adapter onto SuiteKernel's shared Select tool (#6012). A point hits the topmost
// visible pixel layer whose pixel there is not clear (one pixel read per layer, no render); a box touches each
// visible pixel layer with painted pixels inside it (`paintedBounds` over the box's window, at the release only). The
// picks are `layerSelection`, the same one the Layers list shows. Photo keeps one layer picked while there are
// layers, so a click on empty canvas, or a box that touches nothing, leaves the selection as it is. A pick records
// no undo step, as the Layers list's picks don't. `selectBox` is the box the canvas draws while the drag lasts; the
// window runs the whole gesture on LiveDragLine's copy (`dragShowsLineOnly`), so only the release re-runs the
// editor. `pickOutlines` are the picked layers' painted boxes the canvas outlines while Select rests (#6149).
// Linux-safe.
import SuiteKernel

extension PhotoWorkspace: SelectTarget {
    public func layerHit(at point: Point) -> PhotoLayer.ID? {
        let (x, y) = (Int(point.x.rounded(.down)), Int(point.y.rounded(.down)))
        return layers.first { layer in
            guard layer.isVisible, let tiles = pixels[layer.id] else { return false }
            return ((try? tiles.pixel(x: x - layer.offsetX, y: y - layer.offsetY))?.a ?? 0) > 0
        }?.id
    }

    public func layerHits(in rect: Rect) -> [PhotoLayer.ID] {
        layers.filter { layer in
            guard layer.isVisible, let tiles = pixels[layer.id] else { return false }
            let x = Int(rect.minX.rounded(.down)) - layer.offsetX, y = Int(rect.minY.rounded(.down)) - layer.offsetY
            let window = PixelRect(x: x, y: y, width: Int(rect.maxX.rounded(.up)) - layer.offsetX - x,
                                   height: Int(rect.maxY.rounded(.up)) - layer.offsetY - y)
            return ((try? tiles.paintedBounds(in: window)) ?? nil) != nil
        }.map(\.id)
    }

    public var selectPicks: Selection<PhotoLayer.ID> { layerSelection }

    public mutating func setSelectPicks(_ picks: Selection<PhotoLayer.ID>) {
        guard !picks.ordered.isEmpty else { return }
        layerSelection = picks
    }

    /// The box a Select drag shows, in canvas pixels, from the press to the pointer; nil for a click or no Select drag.
    public var selectBox: Rect? {
        guard let stroke, stroke.tool == .select, let end = stroke.end else { return nil }
        let (a, b) = (Point(x: stroke.start.x, y: stroke.start.y), Point(x: end.x, y: end.y))
        return SelectTool.isBox(from: a, to: b) ? Marquee.rect(enclosing: a, b) : nil
    }

    /// The picked layers' painted boxes, in canvas pixels, that the canvas outlines while Select is the tool and
    /// no drag or Free Transform box is up (#6149); a hidden layer or one without pixels has none. Each box comes
    /// from `known` while its layer's pixels are the same (`paintedBounds(of:in:reusing:)`), so a redraw reads
    /// none; `known` keeps only the picks' boxes, and is emptied with another tool.
    public func pickOutlines(reusing known: inout [PaintedBox]) -> [PixelRect] {
        guard tool == .select else {
            known = []
            return []
        }
        guard stroke == nil, transformDraft == nil else { return [] }
        var kept: [PaintedBox] = [], boxes: [PixelRect] = []
        for id in selectedLayerIDs {
            guard let layer = layers.first(where: { $0.id == id }), layer.isVisible else { continue }
            var box = known.first { $0.layerID == id }
            if let painted = paintedBounds(of: id, in: nil, reusing: &box) {
                boxes.append(painted.offsetBy(layer.offsetX, layer.offsetY))
            }
            if let box { kept.append(box) }
        }
        known = kept
        return boxes
    }

    /// The Select drag's release: the kernel's click or box from the press to where the pointer lifted.
    mutating func selectRelease(_ done: PhotoStroke) {
        let start = Point(x: done.start.x, y: done.start.y), end = done.end.map { Point(x: $0.x, y: $0.y) } ?? start
        SelectTool.release(&self, from: start, to: end, extending: done.extending)
    }
}
