// PhotoStroke.swift: what each tool does with a drag on the canvas. The canvas
// sends every pointer move as `drag(from:to:pressure:modifiers:zoom:)` in
// canvas pixels (a click is a drag that doesn't move), with its modifier keys
// and the zoom, or a display frame's moves at once as `drags(_:zoom:)`, one
// revision for all of them, and `endDrag()` when the pointer lifts; one drag
// is one undo step. Today's `drag(from:to:pressure:sampling:)` and
// `drags(_:)` stay as wrappers (`sampling` is Option, zoom 1).
//
// Drags route by component: with a Free Transform in progress every drag goes
// to `transformDrag` (PhotoTransform.swift), which moves, scales or turns the
// box and records one step on release; otherwise by tool, marquee to
// `selectionDrag` (PhotoSelectionMask.swift), crop to `cropDrag`
// (PhotoCropTool+Kernel.swift), eyedropper to `sampleDrag` (PhotoSample+Kernel.swift),
// a Pen drag adds a draft point on release (`runPath`, PhotoPaths+Kernel.swift),
// and the rest paint or move here.
//
//   brush, eraser  a round stroke through the pointer samples on the selected
//                  layer: a centripetal Catmull-Rom curve (SuiteKernel's
//                  StrokeSmoother, PhotoBrush+Kernel.swift), so sparse samples
//                  from a fast hand still paint a curve. A segment is painted
//                  once the sample after it arrives (the last one on mouse-up),
//                  cut into pieces flat to a quarter pixel, each a capsule
//                  whose width follows the pressure (size x pressure), so the
//                  edge is continuous, never scalloped. Each pixel keeps the
//                  most coverage the stroke gave it, so overlaps never build
//                  past the stroke's opacity. The brush lays the paint color
//                  over the pixels as they were before the stroke; the eraser
//                  scales them (color and alpha) toward transparent. Undo keeps
//                  the tiles the stroke painted, as they were, so no event
//                  walks the whole layer ("Paint", "Erase").
//   clone          with Option held at the press, or with no
//                  source yet, the press samples the clone source and the
//                  drag paints nothing; otherwise clone dabs (PhotoRetouch)
//                  at the brush's size along the pointer samples on the
//                  selected layer, each dab once (a move skips the one the
//                  event before ended on), one undo step ("Clone").
//   heal           the same as clone, but each dab takes its tone from where
//                  it lands (PhotoRetouch), one undo step ("Heal").
//   marquee        the rectangle from the press to the pointer is the
//                  selection; a click deselects (PhotoSelectionMask.swift).
//   crop           the same rectangle is the pending crop (Apply Crop commits
//                  it); a click drops it (PhotoCropTool+Kernel.swift).
//   eyedropper     the color under the pointer becomes the brush color, never
//                  an undo step (PhotoSample+Kernel.swift).
//   select         a press on a layer's pixel (`selectPressMoves`) picks it,
//                  unless it is picked already, and the drag shifts every
//                  picked image layer, in whole pixels, as one step ("Move
//                  Layer", "Move Layers" for several); a press on empty canvas
//                  draws a box, and a click picks (PhotoSelect+Kernel.swift).
//   bucket, spot heal, remove
//                  nothing until the release runs one command, one undo step
//                  (PhotoRetouchRelease.swift).
//
// Brush, eraser, clone and heal write through `paintTarget()`: the selected
// layer's pixels, or on an adjustment layer nothing, with the refusal in
// `statusMessage` from the press that tried. Every dab is weighted by the
// selection's coverage (PhotoSelectionMask.swift); with no selection the
// weight is skipped, so paint costs what it did. Those four change only
// pixels (`dragPaintsOnly`), so the window draws their strokes on a copy of
// the workspace and takes it back once (`adoptLiveStroke(_:)`).
//
// ponytail: capsules write through PixelBuffer.pixel/setPixel one pixel at a
// time, with source-over and the eraser's scaling inline, and visit each
// piece's whole box, so very large brushes on tight curves cost more; a
// CoreRaster stamp op is the upgrade once brushes get textures. Linux-safe.
import CoreRaster
import SuiteKernel

/// Where a paint stroke writes. A mask's coverage is its gray (red
/// channel), alpha always 1, so the brush paints black to hide and white to
/// reveal; PV-5 makes `paintTarget()` give `.mask`.
public enum PaintTarget: Hashable, Sendable {
    case pixels(PhotoLayer.ID)
    case mask(PhotoLayer.ID)
}

/// A drag in progress, from its first `drag` to `endDrag`.
struct PhotoStroke: Sendable, Equatable {
    var tool: PhotoTool
    var start: Mask.Point
    /// Brush, eraser and clone: the layer; by tile index, each painted tile as it
    /// was before the stroke and its pixels' coverage so far (row-major, the
    /// tile's size); and the last four pointer samples, the kernel's window.
    var layerID: PhotoLayer.ID?
    var before: [Int: PixelBuffer] = [:]
    var coverage: [Int: [Float]] = [:]
    var samples: [StrokeSample] = []
    /// Brush and eraser: the undo step's name when a command, not a drag, made the stroke ("Brush Stroke").
    var stepName: String?
    /// Move: the layer list before the drag.
    var layersBefore: [PhotoLayer] = []
    /// Marquee: the modifier keys `selectionDrag` saw last (Shift adds,
    /// Option subtracts, PV-5).
    var modifiers: DragModifiers = []
    /// Gradient: where the pointer is now; the gradient runs from `start` to here on release.
    var end: Mask.Point?
    /// Shift at the press, for Select's toggle and box join.
    var extending = false
    /// Area tools: the lasso's path, the last zoom, the Marquee's starting selection (PhotoAreaTool.swift).
    var points: [Mask.Point] = []
    var zoom: Double = 1
    var areaBefore: PhotoAreaBefore?
    /// Free Transform: the draft at the press and the handle the press took (nil off the box).
    var transformFrom: TransformDraft?
    var transformHandle: TransformHandle?
    /// Heal: the stroke's points so far, for `retouch.heal` on release.
    /// Remove: the points the stroke passed, from `start`, a quarter of the brush apart.
    var path: [Mask.Point] = []
    /// Select pressed on a layer: the drag moves the picks, as a body drag on an implied draft the compositor
    /// lifts (`moveDraft`, `transformFrom` set; the release lays its move into the offsets, `endMove`), or by
    /// offsets every sample for picks the lift can't draw. `picksBefore` is the selection before the press, for
    /// the click a move that went nowhere becomes.
    var movesLayer = false
    var picksBefore: Selection<PhotoLayer.ID>?
}

extension PhotoWorkspace {
    /// Where brush, eraser, clone and heal write: the selected layer's
    /// pixels; nil with no layer selected, or on an adjustment layer, with
    /// `statusMessage` "Select an image layer in the sidebar to paint on."
    /// set in this call.
    public mutating func paintTarget() -> PaintTarget? {
        guard let layer = selectedLayer else { return nil }
        if case .adjustment = layer.kind {
            statusMessage = "Select an image layer in the sidebar to paint on."
            return nil
        }
        return .pixels(layer.id)
    }

    /// The Select tool's instruction line: how to pick and move layers, or
    /// why an adjustment layer (which has no place on the canvas) can't move.
    public var moveHint: String { canMoveSelection ? Self.selectHint : Self.moveRefusal }

    static let selectHint = "Drag a layer to move it, click one to select it, Shift-click to add or remove one, or drag on empty canvas to box several."

    /// Whether a picked layer can move: at least one is an image layer. The
    /// Select tool's transform rows show only then.
    public var canMoveSelection: Bool { !movableSelectedLayers.isEmpty }

    static let moveRefusal = "Select an image layer in the sidebar to move it."

    /// The pixel layer `paintTarget()` gives, if any.
    mutating func paintLayerID() -> PhotoLayer.ID? {
        guard case .pixels(let id)? = paintTarget() else { return nil }
        return id
    }

    /// `drag(from:to:pressure:modifiers:zoom:)` with Option for `sampling`, at zoom 1.
    public mutating func drag(
        from start: Mask.Point, to end: Mask.Point, pressure: Double = 1, sampling: Bool = false
    ) {
        drag(from: start, to: end, pressure: pressure, modifiers: sampling ? [.option] : [], zoom: 1)
    }

    /// The active tool's drag from `start` to `end`, in canvas pixels.
    /// `pressure` (0...1, a tablet's; a mouse sends 1) scales the brush.
    /// `modifiers` are the keys held (Option at the press makes the clone
    /// tool sample its source); `zoom` is points per canvas pixel, for hit
    /// tolerances.
    public mutating func drag(
        from start: Mask.Point, to end: Mask.Point, pressure: Double = 1, modifiers: DragModifiers,
        zoom: Double = 1
    ) {
        guard let canvas else { return }
        if selectPressMoves(at: start) { beginSelectMove(at: start, extending: modifiers.contains(.shift)) }
        if transformDraft != nil { return transformDrag(from: start, to: end, modifiers: modifiers, zoom: zoom) }
        let begun = stroke == nil
        if begun, tool == .eyedropper { return sampleDrag(at: end) }
        var current = stroke ?? PhotoStroke(tool: tool, start: start, layerID: selectedLayerID)
        stroke = nil
        switch current.tool {
        case .brush, .eraser:
            if begun {
                current.layerID = paintLayerID()
                paint(&current, adding: start, pressure: pressure)
            }
            paint(&current, adding: end, pressure: pressure)
        case .clone, .heal:
            if begun, modifiers.contains(.option) || cloneSource == nil {
                setCloneSource(at: start)
                current.layerID = nil
            } else {
                if begun { current.layerID = paintLayerID() }
                guard let id = current.layerID else { break }
                // A move after the press starts on the dab the last event laid, so it skips that one.
                let last = current.samples.last.map { Mask.Point($0.point) }
                current.samples = [StrokeSample(point: end.kernel)]
                if current.tool == .heal { current.path += last == nil ? [start, end] : [end] }
                stamp(
                    along: [last ?? start, end], size: brushOptions.size, layer: id, before: &current.before,
                    coverage: &current.coverage, skippingFirst: last != nil)
            }
        case .marquee, .ellipse, .lasso, .polygon, .wand:
            areaDrag(&current, to: end, modifiers: modifiers, zoom: zoom, in: canvas)
        case .crop:
            cropDrag(current, to: end, modifiers: modifiers, zoom: zoom, in: canvas)
        case .eyedropper, .bucket, .spotHeal:
            break
        case .remove:
            trace(&current, to: end)
        case .gradient, .pen:
            current.end = end
        case .select where current.movesLayer:
            moveSelectedLayers(current, to: end)
        case .select:
            if begun { current.extending = modifiers.contains(.shift) }
            current.end = end
        case .text:
            break
        }
        stroke = current
    }

    /// Several pointer moves in order, as one change to the canvas: one
    /// revision whose damage covers them all, however many samples a display
    /// frame brought.
    public mutating func drags(
        _ events: [(from: Mask.Point, to: Mask.Point, pressure: Double, modifiers: DragModifiers)], zoom: Double = 1
    ) {
        let start = revision
        for event in events {
            drag(from: event.from, to: event.to, pressure: event.pressure, modifiers: event.modifiers, zoom: zoom)
        }
        foldRevisions(since: start)
    }

    /// Whether a canvas drag pressed at `press` runs on the window's live transform copy (LiveTransformCopy): Free
    /// Transform's drags, and a Select drag pressed on a layer (`selectPressMoves`), so no sample re-runs the editor.
    public func dragRunsLive(pressAt press: Mask.Point) -> Bool { transformDraft != nil || selectPressMoves(at: press) }

    /// Whether a Select press at `point` moves layers rather than drawing a box: it lands on a layer's pixel
    /// (`layerHit`), with no Free Transform up and no drag under way. The one rule the window's routing and
    /// `drag` share, read at the press.
    public func selectPressMoves(at point: Mask.Point) -> Bool {
        tool == .select && transformDraft == nil && stroke == nil && layerHit(at: Point(x: point.x, y: point.y)) != nil
    }

    /// A Select press on a layer: that layer joins the picks unless it is one (the kernel's click: alone it
    /// replaces them, with Shift it joins), then the drag moves them, on Move's implied draft when the lift can
    /// draw it, else by offsets.
    private mutating func beginSelectMove(at start: Mask.Point, extending: Bool) {
        let before = layerSelection
        if let hit = layerHit(at: Point(x: start.x, y: start.y)), !before.contains(hit) {
            setSelectPicks(SelectTool.click(before, hit: hit, extending: extending))
        }
        var current = PhotoStroke(tool: .select, start: start, layerID: nil, layersBefore: layers, movesLayer: true)
        (current.extending, current.picksBefore) = (extending, before)
        if let draft = moveDraft() {
            (current.transformFrom, current.transformHandle) = (draft, .inside)
            transformDraft = draft
        }
        stroke = current
    }

    /// Whether the canvas shows Free Transform's box and handles: a draft is
    /// up and it isn't a Select move's implied one.
    public var showsTransformBox: Bool { transformDraft != nil && stroke?.movesLayer != true }

    /// Whether a drag now changes only the picture's pixels: brush, eraser,
    /// clone or heal with no Free Transform under way. The window draws such a
    /// stroke on a copy and takes it back with `adoptLiveStroke(_:)`, so the
    /// stroke's samples don't re-run every panel.
    public var dragPaintsOnly: Bool {
        transformDraft == nil && [.brush, .eraser, .clone, .heal].contains(tool)
    }

    /// The Gradient tool's line while it drags, from the press to where the
    /// pointer is now, in canvas pixels, for the canvas overlay; nil with no
    /// gradient drag or one that hasn't moved.
    public var gradientDrag: (from: Mask.Point, to: Mask.Point)? {
        guard let stroke, stroke.tool == .gradient, let end = stroke.end, end != stroke.start else { return nil }
        return (stroke.start, end)
    }

    /// `dragShowsLineOnly` for a drag pressed at `press`: false for a Select press that moves layers.
    public func dragShowsLineOnly(pressAt press: Mask.Point) -> Bool { dragShowsLineOnly && !selectPressMoves(at: press) }

    /// Whether the drag under way only moves an overlay mark over the canvas until its release
    /// (the Gradient tool's line, Remove's outline, and the area, Crop and Select tools' selection,
    /// crop or select box), so the window can keep its samples off the workspace the panels read. An area or Crop
    /// tool's whole gesture, the press too, changes nothing the panels show until the release lands
    /// its one step, so it is true for those tools before the press (#6020), and for Select until a
    /// press on a layer makes its drag a move (`dragShowsLineOnly(pressAt:)` reads that at the press).
    public var dragShowsLineOnly: Bool {
        (stroke?.tool == .gradient && transformDraft == nil) || stroke?.tool == .remove
            || (transformDraft == nil && stroke?.movesLayer != true && Self.overlayDragTools.contains(tool))
    }

    /// The tools whose drag draws a selection or a crop box: the area tools, Crop and Select.
    static let overlayDragTools: Set<PhotoTool> = [.marquee, .ellipse, .lasso, .polygon, .wand, .crop, .select]

    /// Becomes `live`: a copy of this workspace a stroke drew on
    /// (`dragPaintsOnly`). Ignored when `live` is another image (another
    /// canvas or layer stack), so a stroke never overwrites a newer document.
    public mutating func adoptLiveStroke(_ live: PhotoWorkspace) {
        guard live.canvas == canvas, live.layers.map(\.id) == layers.map(\.id) else { return }
        self = live
    }

    /// `drags(_:zoom:)` with Option for `sampling`, at zoom 1.
    public mutating func drags(_ moves: [(from: Mask.Point, to: Mask.Point, pressure: Double, sampling: Bool)]) {
        drags(moves.map { (from: $0.from, to: $0.to, pressure: $0.pressure, modifiers: $0.sampling ? .option : []) })
    }

    /// Ends the drag: records its undo step, or for a click, clears what a
    /// click clears.
    public mutating func endDrag() {
        guard var done = stroke else { return }
        stroke = nil
        if let before = done.transformFrom {
            if done.movesLayer { return endMove(done) }
            // A press on no handle moved nothing itself (the handles' own drag records its steps).
            if done.transformHandle != nil, transformDraft != before { record(.draft(before), named: "Transform") }
            return
        }
        switch done.tool {
        case .brush, .eraser:
            paint(&done, adding: nil, pressure: 1)
            guard let id = done.layerID, !done.before.isEmpty else { return }
            record(.tiles(layer: id, done.before), named: done.stepName ?? (done.tool == .brush ? "Paint" : "Erase"))
        case .clone:
            guard let id = done.layerID, !done.before.isEmpty else { return }
            record(.tiles(layer: id, done.before), named: "Clone")
        case .heal:
            guard done.layerID != nil else { return }
            healStroke(done)
        case .marquee, .ellipse, .lasso, .polygon, .wand:
            endAreaDrag(done)
        case .bucket, .spotHeal, .remove:
            retouchRelease(done)
        case .crop, .eyedropper:
            break
        case .select where done.movesLayer:
            if done.layersBefore == layers { return selectClick(done) }
            let moved = zip(done.layersBefore, layers).filter { $0.offsetX != $1.offsetX || $0.offsetY != $1.offsetY }
            record(.layers(done.layersBefore, selected: selectedLayerID), named: moved.count > 1 ? "Move Layers" : "Move Layer")
        case .select:
            selectRelease(done)
        case .gradient:
            guard let end = done.end else { return }
            do { try drawGradient(from: done.start, to: end) } catch { statusMessage = "Couldn't draw the gradient." }
        case .text:
            openTextBox(at: done.start)
        case .pen:
            runPath(.penAdd(done.start.kernel, handleOut: done.end?.kernel))
        }
    }

    /// A drag's rectangle clipped to the canvas; nil for a click or a drag
    /// that stays outside.
    static func dragRect(_ a: Mask.Point, _ b: Mask.Point, in canvas: CanvasSize) -> PixelRect? {
        let dx = b.x - a.x, dy = b.y - a.y
        guard dx * dx + dy * dy >= 1 else { return nil }
        return PixelRect(from: a, to: b).intersection(canvas.rect)
    }

    /// The draft a Select move runs on: the one picked image layer's whole
    /// bounds, when the compositor can lift it (`liftKey`). Nil for several
    /// picked layers, a text layer or a layer the lift can't draw (one under a
    /// visible layer, masked, styled, blended): those move by offsets.
    private func moveDraft() -> TransformDraft? {
        let targets = movableSelectedLayers
        guard targets.count == 1, let at = targets.first, let box = bounds(of: layers[at]) else { return nil }
        var probe = self
        probe.transformDraft = TransformDraft(layerID: layers[at].id, box: box)
        return probe.liftKey == nil ? nil : probe.transformDraft
    }

    /// Self with the draft a Select move of the picks begins (`moveDraft`), so
    /// the canvas makes the lift's pixels before the press, as it does once a
    /// Free Transform draft shows; nil when the tool isn't Select, a draft is
    /// already up, or the next drag wouldn't lift.
    public var movePrepared: PhotoWorkspace? {
        guard tool == .select, transformDraft == nil, let draft = moveDraft() else { return nil }
        var ahead = self
        ahead.transformDraft = draft
        return ahead
    }

    /// A lifted Select move's release: the draft goes and its move, rounded to
    /// canvas pixels, goes into the layer's offsets as one "Move Layer" step
    /// (no resample; the keyboard's is `moveSelectedLayers(dx:dy:)`). The
    /// release's picture covers where the layer was and is, so the lift lands.
    /// One that went nowhere is the click (`selectClick`).
    private mutating func endMove(_ done: PhotoStroke) {
        defer { transformDraft = nil }
        guard let draft = transformDraft, let at = index(of: draft.layerID) else { return }
        let was = bounds(of: layers[at])
        let (dx, dy) = (draft.transform.dx.rounded(), draft.transform.dy.rounded())
        if dx != 0 || dy != 0, abs(dx) < 1e7, abs(dy) < 1e7, !done.layersBefore.isEmpty {
            record(.layers(done.layersBefore, selected: selectedLayerID), named: "Move Layer")
            layers[at].offsetX += Int(dx)
            layers[at].offsetY += Int(dy)
        } else {
            selectClick(done)
        }
        if let was, let now = bounds(of: layers[at]) { touch(.region(was.union(now))) } else { touch(.all) }
    }

    /// A Select press on a layer that moved nothing: the kernel's click from the picks before the press, so Shift
    /// on a picked layer still takes it out.
    private mutating func selectClick(_ done: PhotoStroke) {
        guard let before = done.picksBefore else { return }
        layerSelection = before
        selectRelease(done)
    }

    /// Moves every picked image layer to where it was at the press plus the
    /// drag so far, so the whole drag is one change from `layersBefore`.
    private mutating func moveSelectedLayers(_ current: PhotoStroke, to end: Mask.Point) {
        guard selectedLayerID != nil else { return }
        let targets = movableSelectedLayers
        guard !targets.isEmpty else {
            statusMessage = Self.moveRefusal
            return
        }
        let dx = end.x - current.start.x, dy = end.y - current.start.y
        guard dx.isFinite, dy.isFinite, abs(dx) < 1e7, abs(dy) < 1e7 else { return }
        // Where the moved layers were and are: the canvas changes nowhere else.
        var damage = PhotoDamage.none
        for at in targets {
            guard let before = current.layersBefore.first(where: { $0.id == layers[at].id }) else { continue }
            let x = before.offsetX + Int(dx.rounded()), y = before.offsetY + Int(dy.rounded())
            guard x != layers[at].offsetX || y != layers[at].offsetY else { continue }
            let was = bounds(of: layers[at])
            layers[at].offsetX = x
            layers[at].offsetY = y
            if let was, let now = bounds(of: layers[at]) {
                damage = damage.union(.region(was.union(now)))
            } else {
                damage = .all
            }
        }
        if damage != .none { touch(damage) }
    }

    /// Adds a pointer sample to the stroke (nil: the stroke ends) and paints
    /// what that makes paintable: the first sample's dab, then the segment
    /// before the newest sample, or on the end the last segment.
    private mutating func paint(_ current: inout PhotoStroke, adding point: Mask.Point?, pressure: Double) {
        if let point {
            guard point.x.isFinite, point.y.isFinite, abs(point.x) < 1e7, abs(point.y) < 1e7,
                current.samples.last?.point != point.kernel
            else { return }
            let clamped = pressure.isNaN ? 1 : min(max(pressure, 0), 1)
            current.samples = current.samples.suffix(3) + [StrokeSample(point: point.kernel, pressure: clamped)]
            if current.samples.count == 1 { return lay([point], from: clamped, to: clamped, &current) }
        }
        guard let piece = PhotoStroke.smoothed(current.samples, ending: point == nil) else { return }
        lay(piece.points, from: piece.from, to: piece.to, &current)
    }

    /// Paints capsules along `points` (canvas pixels) on the stroke's layer,
    /// the pressure going from `start` to `end`; one point paints a dab.
    private mutating func lay(
        _ points: [Mask.Point], from start: Double, to end: Double, _ current: inout PhotoStroke
    ) {
        guard !points.isEmpty, let id = current.layerID, let at = index(of: id),
            var tiled = pixels.removeValue(forKey: id)
        else { return }
        let pieces = max(points.count - 1, 1)
        var touched = PixelRect(x: 0, y: 0, width: 0, height: 0)
        for k in 0..<pieces {
            let (a, b) = (Double(k) / Double(pieces), Double(k + 1) / Double(pieces))
            // Every index is inside the buffer and every value finite, so a capsule can't throw.
            let ends = (points[k], points[min(k + 1, points.count - 1)])
            if let area = try? capsule(
                ends.0, ends.1, pressures: (start + (end - start) * a, start + (end - start) * b), on: &tiled,
                layer: layers[at], stroke: &current)
            {
                touched = touched.union(area)
            }
        }
        pixels[id] = tiled
        if !touched.isEmpty { touch(.region(touched)) }
    }

    /// One capsule from `a` to `b` (canvas pixels), its radius following the
    /// pressure from one end to the other. Returns the canvas region it
    /// covers, or nil when it missed the layer.
    private func capsule(
        _ a: Mask.Point, _ b: Mask.Point, pressures: (Double, Double), on tiled: inout TiledPixels, layer: PhotoLayer,
        stroke: inout PhotoStroke
    ) throws -> PixelRect? {
        let options = stroke.tool == .eraser ? eraserOptions : brushOptions
        // Half a pixel at the least, so the soft edge below is never zero wide.
        let ra = max(options.size / 2 * pressures.0, 0.5), rb = max(options.size / 2 * pressures.1, 0.5)
        let ax = a.x - Double(layer.offsetX), ay = a.y - Double(layer.offsetY)
        let dx = b.x - a.x, dy = b.y - a.y, length2 = dx * dx + dy * dy, r = max(ra, rb)
        let box = PixelRect(
            from: Mask.Point(x: min(ax, ax + dx) - r, y: min(ay, ay + dy) - r),
            to: Mask.Point(x: max(ax, ax + dx) + r, y: max(ay, ay + dy) + r))
        guard let area = box.intersection(PixelRect(x: 0, y: 0, width: tiled.width, height: tiled.height)) else {
            return nil
        }
        let hardness = options.hardnessPercent / 100
        let opacity = Float(options.opacityPercent / 100)
        let paint = options.linearColor
        let erasing = stroke.tool == .eraser
        let weight = coverageWeight(offsetX: layer.offsetX, offsetY: layer.offsetY)
        for i in tiled.tileIndices(in: area) where tiled.tiles.indices.contains(i) {
            let rect = tiled.tileRect(i)
            guard let part = area.intersection(rect) else { continue }
            // The tile as it was before the stroke: kept from the first paint in it on.
            let base = stroke.before[i] ?? tiled.tiles[i]
            var coverage =
                stroke.coverage.removeValue(forKey: i) ?? [Float](repeating: 0, count: rect.width * rect.height)
            var painted = false
            for y in part.y..<part.maxY {
                for x in part.x..<part.maxX {
                    // The nearest point of the piece, and the radius there.
                    let px = Double(x) + 0.5 - ax, py = Double(y) + 0.5 - ay
                    let along = length2 > 0 ? min(max((px * dx + py * dy) / length2, 0), 1) : 0
                    let ex = px - along * dx, ey = py - along * dy, radius = ra + (rb - ra) * along
                    // Coverage falls from 1 to 0 over the soft edge: the outer (1 - hardness)
                    // of the radius, and never less than a pixel, so hard edges antialias.
                    let softness = max((1 - hardness) * radius, min(1, radius))
                    let t = min(max((radius - (ex * ex + ey * ey).squareRoot()) / softness, 0), 1)
                    var cover = Float(t * t * (3 - 2 * t))
                    if let weight { cover *= weight(x, y) }
                    let (tx, ty) = (x - rect.x, y - rect.y)
                    let j = ty * rect.width + tx
                    guard cover > coverage[j] else { continue }
                    coverage[j] = cover
                    let a = cover * opacity, keep = 1 - cover * opacity
                    let p = try base.pixel(x: tx, y: ty)
                    let out = erasing
                        ? RGBA(r: p.r * keep, g: p.g * keep, b: p.b * keep, a: p.a * keep)
                        : RGBA(r: paint.r * a + p.r * keep, g: paint.g * a + p.g * keep, b: paint.b * a + p.b * keep,
                               a: a + p.a * keep)
                    try tiled.tiles[i].setPixel(x: tx, y: ty, out)
                    painted = true
                }
            }
            guard painted || stroke.before[i] != nil else { continue }
            stroke.before[i] = base
            stroke.coverage[i] = coverage
        }
        return area.offsetBy(layer.offsetX, layer.offsetY)
    }
}
