// TimelineLanesView.swift: TL-21's lanes renderer, a CALayer per lane drawn
// through CoreGraphics with TimelineLook's rules, redrawing only the lanes
// TimelineLaneLayers.dirty names. `cacheDisplay` (the snapshots) uses `draw(_:)`;
// clicks stay with TimelineLaneInput until TL-22. macOS only.
import AppKit
import SwiftUI

/// One lane's drawn values, Equatable so the view redraws a lane only when they change.
struct TimelineLaneDrawing: Equatable, Sendable {
    let keys: [TimelineKey]  // in frame order
    let spans: [ClosedRange<Int>]
    let pickedFrames: Set<Int>
    let isSelected: Bool
    let mapping: FrameMapping
    let hovered: Bool  // the bed turns rowHover
    let ringed: Int?  // the frame of the key under the pointer, in the accent ring

    init<ID>(_ track: TimelineTrack<ID>, mapping: FrameMapping, hover: TimelineLaneHover? = nil) {
        keys = track.keys.sorted { $0.frame < $1.frame }
        (spans, pickedFrames, isSelected) = (track.spans, track.pickedFrames, track.isSelected)
        (self.mapping, hovered, ringed) = (mapping, hover != nil, hover?.key)
    }
}

/// The lane tokens resolved for one appearance, as sRGB hex.
struct TimelineLanePalette: Equatable, Sendable {
    let bed, hoverBed, tint, clip, tween, ring, keyIdle, keyPicked, edgeIdle, edgePicked: UInt32
    let tintAlpha: CGFloat  // SuitePalette.tintDark in the dark appearances, tintLight in the light

    @MainActor init(_ appearance: NSAppearance) {
        bed = SuitePalette.laneBed.value(for: appearance)
        hoverBed = SuitePalette.rowHover.value(for: appearance)
        tint = SuitePalette.stateSelected.value(for: appearance)
        clip = TimelineLook.clipFill.value(for: appearance)
        tween = SuitePalette.textTertiary.value(for: appearance)
        ring = SuitePalette.accent.value(for: appearance)
        keyIdle = TimelineLook.keyFill(picked: false, atPlayhead: false).value(for: appearance)
        keyPicked = TimelineLook.keyFill(picked: true, atPlayhead: false).value(for: appearance)
        edgeIdle = TimelineLook.keyEdge(picked: false).color.value(for: appearance)
        edgePicked = TimelineLook.keyEdge(picked: true).color.value(for: appearance)
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        tintAlpha = dark ? SuitePalette.tintDark : SuitePalette.tintLight
    }

    func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// Draws one lane into a CoreGraphics context whose y runs down from the lane's top.
enum TimelineLanePainter {
    static func draw(_ lane: TimelineLaneDrawing, palette: TimelineLanePalette, size: CGSize, in context: CGContext) {
        let bed = TimelineLaneGeometry.bed(width: size.width, height: size.height)
        let bedPath = Path(roundedRect: bed, cornerRadius: SuiteRadius.lane).cgPath
        paint(bedPath, fill: palette.color(lane.hovered ? palette.hoverBed : palette.bed), in: context)
        if lane.isSelected { paint(bedPath, fill: palette.color(palette.tint, alpha: palette.tintAlpha), in: context) }
        for span in lane.spans {
            let block = TimelineLaneGeometry.block(span, mapping: lane.mapping, bed: bed)
            let shape = Path(roundedRect: block, cornerRadius: TimelineLaneGeometry.radius(of: block))
            paint(shape.cgPath, fill: palette.color(palette.clip), in: context)
        }
        paint(tweens(of: lane, mid: bed.midY).cgPath, stroke: palette.color(palette.tween), width: SuiteSpacing.xxs, in: context)
        let size = SuiteSize.timelineKeyframe
        for key in lane.keys {
            let picked = lane.pickedFrames.contains(key.frame)
            let center = CGPoint(x: tickX(lane.mapping, key.frame), y: bed.midY)
            let glyph = TimelineLook.keyPath(key.shape).glyph
            let shape = TimelineLaneGeometry.keyShape(glyph, center: center, size: size).cgPath
            paint(shape, fill: palette.color(picked ? palette.keyPicked : palette.keyIdle), in: context)
            paint(shape, stroke: palette.color(picked ? palette.edgePicked : palette.edgeIdle),
                  width: CGFloat(TimelineLook.keyEdge(picked: picked).width), in: context)
            guard key.frame == lane.ringed else { continue }
            // The ring's centre line sits its half width beyond a 1 pt gap.
            let out = SuiteSize.focusRingGap + SuiteSize.focusRing / 2
            let ring = TimelineLaneGeometry.keyShape(glyph, center: center, size: size + out * 2).cgPath
            paint(ring, stroke: palette.color(palette.ring), width: SuiteSize.focusRing, in: context)
        }
    }

    /// The tweens between consecutive keys: a line, a step after a hold key, a curve glyph on a wide eased gap.
    private static func tweens(of lane: TimelineLaneDrawing, mid: CGFloat) -> Path {
        let glyph = SuiteSpacing.xs
        var tween = Path()
        for (a, b) in zip(lane.keys, lane.keys.dropFirst()) {
            let (ax, bx) = (tickX(lane.mapping, a.frame), tickX(lane.mapping, b.frame))
            let segment = TimelineLook.segment(from: a, at: Double(ax), to: b, at: Double(bx))
            switch segment.kind {
            case .line: tween.addLines([CGPoint(x: ax, y: mid), CGPoint(x: bx, y: mid)])
            case .step: tween.addLines([CGPoint(x: ax, y: mid + glyph), CGPoint(x: bx, y: mid + glyph), CGPoint(x: bx, y: mid)])
            }
            if let x = segment.curveGlyphX.map({ CGFloat($0) }) {
                tween.move(to: CGPoint(x: x - glyph, y: mid + glyph))
                tween.addCurve(to: CGPoint(x: x + glyph, y: mid - glyph),
                               control1: CGPoint(x: x, y: mid + glyph), control2: CGPoint(x: x, y: mid - glyph))
            }
        }
        return tween
    }

    private static func paint(_ path: CGPath, fill: CGColor? = nil, stroke: CGColor? = nil, width: CGFloat = 1,
                              in context: CGContext) {
        if let fill { context.addPath(path); context.setFillColor(fill); context.fillPath() }
        if let stroke { context.addPath(path); context.setStrokeColor(stroke); context.setLineWidth(width); context.strokePath() }
    }
}

/// One lane's layer: draws its lane with its palette, with no implicit animation.
final class TimelineLaneLayer: CALayer {
    var lane: TimelineLaneDrawing?
    var palette: TimelineLanePalette?

    override init() {
        super.init()
        needsDisplayOnBoundsChange = true
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? TimelineLaneLayer { (lane, palette) = (other.lane, other.palette) }
    }

    required init?(coder: NSCoder) { nil }

    override func action(forKey event: String) -> (any CAAction)? { nil }

    override func draw(in ctx: CGContext) {
        guard let lane, let palette else { return }
        ctx.saveGState()
        if !contentsAreFlipped() {  // the painter's y runs down
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
        }
        TimelineLanePainter.draw(lane, palette: palette, size: bounds.size, in: ctx)
        ctx.restoreGState()
    }
}

/// The lanes in one view, a layer per lane, tiled top down at the lane height.
final class TimelineLanesView: NSView {
    private(set) var lanes: [TimelineLaneDrawing] = []
    private(set) var laneLayers: [TimelineLaneLayer] = []
    private(set) var draws = 0  // lane redraws asked of the layers
    private var palette: TimelineLanePalette?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {}
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Shows `new`, redrawing the lanes that differ from those shown, or all on a new palette.
    func update(_ new: [TimelineLaneDrawing]) {
        let resolved = TimelineLanePalette(effectiveAppearance)
        var dirty = TimelineLaneLayers.dirty(old: lanes, new: new)
        if resolved != palette { (palette, dirty) = (resolved, Set(new.indices)) }
        lanes = new
        let wanted = new.count
        while laneLayers.count > wanted { laneLayers.removeLast().removeFromSuperlayer() }
        while laneLayers.count < wanted {
            let lane = TimelineLaneLayer()
            lane.contentsScale = window?.backingScaleFactor ?? lane.contentsScale
            layer?.addSublayer(lane)
            laneLayers.append(lane)
        }
        place()
        redraw(dirty)
    }

    private func redraw(_ indices: Set<Int>) {
        for index in indices.sorted() where laneLayers.indices.contains(index) && lanes.indices.contains(index) {
            (laneLayers[index].lane, laneLayers[index].palette) = (lanes[index], palette)
            laneLayers[index].setNeedsDisplay()
            draws += 1
        }
    }

    private func place() {
        let frames = TimelineLaneLayers.frames(count: laneLayers.count, width: bounds.width)
        for (layer, frame) in zip(laneLayers, frames) where layer.frame != frame { layer.frame = frame }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        place()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        update(lanes)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let scale = window?.backingScaleFactor else { return }
        for layer in laneLayers { layer.contentsScale = scale }
        redraw(Set(lanes.indices))
    }

    /// Every lane through CoreGraphics, for `cacheDisplay`.
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let palette = TimelineLanePalette(effectiveAppearance)
        for (lane, frame) in zip(lanes, TimelineLaneLayers.frames(count: lanes.count, width: bounds.width)) {
            context.saveGState()
            context.translateBy(x: frame.minX, y: frame.minY)
            TimelineLanePainter.draw(lane, palette: palette, size: frame.size, in: context)
            context.restoreGState()
        }
    }
}

/// TimelineLanesView in SwiftUI, at the width SwiftUI gives it.
struct TimelineLanes: NSViewRepresentable {
    let lanes: [TimelineLaneDrawing]

    func makeNSView(context: Context) -> TimelineLanesView { TimelineLanesView(frame: .zero) }

    func updateNSView(_ view: TimelineLanesView, context: Context) { view.update(lanes) }
}
