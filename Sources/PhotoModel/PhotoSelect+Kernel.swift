// PhotoSelect+Kernel.swift: Photo's adapter onto SuiteKernel's shared Select tool (#6012). A point hits the topmost
// visible pixel layer whose pixel there is not clear (one pixel read per layer, no render); a box touches each
// visible pixel layer with painted pixels inside it (`paintedBounds` over the box's window, at the release only). The
// picks are `layerSelection`, the same one the Layers list shows. Photo keeps one layer picked while there are
// layers, so a click on empty canvas, or a box that touches nothing, leaves the selection as it is. A pick records
// no undo step, as the Layers list's picks don't. `pickedBoxes` are the outlines the canvas draws round the picks
// (kept painted boxes, so a redraw reads no pixels). `selectBox` is the box the canvas draws while the drag lasts; the
// window runs the whole gesture on LiveDragLine's copy (`dragShowsLineOnly`), so only the release re-runs the
// editor. Linux-safe.
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

    /// The picked pixel layers' painted boxes, in canvas pixels, which the canvas outlines while Select is the tool
    /// (#6149); empty with any other tool or while Free Transform is up. A box that covers the whole canvas is left
    /// out: the canvas edge already shows it, so a just-opened photo gets no frame. `known` keeps one box per picked layer
    /// across calls, so a redraw or an offset-only move reads no pixels; boxes for layers no longer picked drop out.
    public func pickedBoxes(reusing known: inout [PhotoLayer.ID: PaintedBox]) -> [PixelRect] {
        guard tool == .select, transformDraft == nil else {
            known = [:]
            return []
        }
        var kept: [PhotoLayer.ID: PaintedBox] = [:]
        let boxes = layers.compactMap { layer -> PixelRect? in
            guard layerSelection.contains(layer.id), layer.isVisible, layer.kind == .pixels else { return nil }
            var box = known[layer.id]
            defer { kept[layer.id] = box }
            guard let painted = paintedBounds(of: layer.id, in: nil, reusing: &box)?.offsetBy(layer.offsetX, layer.offsetY)
            else { return nil }
            return coversCanvas(painted) ? nil : painted
        }
        known = kept
        return boxes
    }

    private func coversCanvas(_ box: PixelRect) -> Bool {
        guard let canvas else { return false }
        return box.x <= 0 && box.y <= 0 && box.x + box.width >= canvas.width && box.y + box.height >= canvas.height
    }

    /// The Select drag's release: the kernel's click or box from the press to where the pointer lifted.
    mutating func selectRelease(_ done: PhotoStroke) {
        let start = Point(x: done.start.x, y: done.start.y), end = done.end.map { Point(x: $0.x, y: $0.y) } ?? start
        SelectTool.release(&self, from: start, to: end, extending: done.extending)
    }
}
