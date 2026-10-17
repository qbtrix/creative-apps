// CanvasHostView.swift: the canvas host's AppKit view (canvas-host CH-3): tile
// layers, and a live overlay SwiftUI never sees, cleared at once on mouse-up
// (no fade). `draw(_:)` paints the same picture for `cacheDisplay`. macOS only.
import AppKit
import SwiftUI

/// The AppKit canvas surface: tile layers, the live overlay, mouse, scroll, pinch and hover.
public final class CanvasHostView: NSView {
    public weak var delegate: (any CanvasInputDelegate)?
    public private(set) var documentSize = CGSize.zero
    public private(set) var zoom: CGFloat = 1
    public private(set) var pan = CGSize.zero
    /// The current drag's samples in view points, the overlay's path; empty between drags.
    private(set) var live: [CGPoint] = []
    private var anchor: CGPoint?
    private var images: [CanvasTileRect: CGImage?] = [:]
    private var tileLayers: [CanvasTileRect: CALayer] = [:]
    private var tracking: NSTrackingArea?
    let container = CALayer()
    let overlay = CAShapeLayer()

    override public init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        container.anchorPoint = .zero
        container.actions = ["sublayers": NSNull(), "transform": NSNull(), "bounds": NSNull(), "position": NSNull()]
        overlay.name = RenderingControlID.overlay
        overlay.fillColor = nil
        overlay.lineWidth = SuiteSpacing.xxs
        overlay.lineCap = .round
        overlay.actions = ["path": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(container)
        layer?.addSublayer(overlay)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Canvas")
        setAccessibilityIdentifier(RenderingControlID.canvas)
    }

    required init?(coder: NSCoder) { nil }
    override public var wantsUpdateLayer: Bool { true }
    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Shows `content`'s tiles: all of them when the document size changed, else only the dirty ones.
    public func show(_ content: any CanvasContentProviding) {
        let restart = content.documentSize != documentSize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if restart {
            for layer in tileLayers.values { layer.removeFromSuperlayer() }
            (tileLayers, images, documentSize) = ([:], [:], content.documentSize)
            container.bounds = CGRect(origin: .zero, size: documentSize)
            setAccessibilityValue("\(Int(documentSize.width)) × \(Int(documentSize.height)) px")
        }
        for tile in content.tiles(dirtyOnly: !restart) {
            let layer = tileLayers[tile.rect] ?? CALayer()
            if tileLayers[tile.rect] == nil {
                layer.frame = frame(of: tile.rect)
                layer.edgeAntialiasingMask = []
                container.addSublayer(layer)
                tileLayers[tile.rect] = layer
            }
            layer.contents = tile.image
            images[tile.rect] = tile.image
        }
        CATransaction.commit()
        (needsLayout, needsDisplay) = (true, true)
    }
    /// A tile's frame in the unflipped container: document row y sits at height - maxY.
    private func frame(of rect: CanvasTileRect) -> CGRect {
        CGRect(x: CGFloat(rect.x), y: documentSize.height - CGFloat(rect.y + rect.height),
               width: CGFloat(rect.width), height: CGFloat(rect.height))
    }
    /// The document fitted inside the canvas inset, times the zoom, moved by the pan, in view points.
    public var artboard: CGRect {
        let room = bounds.insetBy(dx: SuiteSize.canvasInset, dy: SuiteSize.canvasInset)
        guard documentSize.width > 0, documentSize.height > 0, room.width > 0, room.height > 0 else { return .zero }
        let scale = min(room.width / documentSize.width, room.height / documentSize.height) * zoom
        let size = CGSize(width: documentSize.width * scale, height: documentSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2 + pan.width, y: bounds.midY - size.height / 2 + pan.height,
                      width: size.width, height: size.height)
    }
    /// A view point in document points, y down from the top; zero with no artboard.
    public func documentPoint(_ point: CGPoint) -> CGPoint {
        let board = artboard
        guard board.width > 0, board.height > 0 else { return .zero }
        return CGPoint(x: (point.x - board.minX) / board.width * documentSize.width,
                       y: (board.maxY - point.y) / board.height * documentSize.height)
    }
    /// The host on the artboard, nil on the surround so clicks there pass through.
    override public func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        return artboard.contains(local) ? self : nil
    }

    override public func layout() {
        super.layout()
        let board = artboard
        let scale = documentSize.width > 0 ? board.width / documentSize.width : 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.position = board.origin
        container.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        overlay.frame = bounds
        // A tile with no pixels yet shows its edge, a hairline at any zoom.
        for (rect, layer) in tileLayers { layer.borderWidth = images[rect, default: nil] == nil && scale > 0 ? 1 / scale : 0 }
        CATransaction.commit()
    }

    override public func updateLayer() {
        layer?.backgroundColor = color(SuitePalette.canvasSurround)
        container.backgroundColor = artboardColor
        overlay.strokeColor = color(SuitePalette.accent)
        for layer in tileLayers.values { layer.borderColor = color(SuitePalette.hairline) }
    }
    private var artboardColor: CGColor { SuiteColor.artboard.resolve(in: EnvironmentValues()).cgColor }
    private func color(_ hex: SuiteHex) -> CGColor {
        let value = hex.value(for: effectiveAppearance)
        return CGColor(srgbRed: CGFloat(value >> 16 & 0xFF) / 255, green: CGFloat(value >> 8 & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    override public func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let board = artboard
        for (fill, rect) in [(color(SuitePalette.canvasSurround), bounds), (artboardColor, board)] {
            context.setFillColor(fill)
            context.fill(rect)
        }
        if documentSize.width > 0, board.width > 0 {
            let scale = board.width / documentSize.width
            context.saveGState()
            context.translateBy(x: board.minX, y: board.minY)
            context.scaleBy(x: scale, y: scale)
            context.setStrokeColor(color(SuitePalette.hairline))
            context.setLineWidth(1 / scale)
            for (rect, image) in images {
                if let image { context.draw(image, in: frame(of: rect)) } else { context.stroke(frame(of: rect)) }
            }
            context.restoreGState()
        }
        guard let path = overlay.path else { return }
        context.addPath(path)
        context.setStrokeColor(color(SuitePalette.accent))
        context.setLineWidth(overlay.lineWidth)
        context.strokePath()
    }

    override public func mouseDown(with event: NSEvent) { press(at: convert(event.locationInWindow, from: nil)) }
    override public func mouseUp(with event: NSEvent) { release() }
    override public func mouseExited(with event: NSEvent) { delegate?.hover(nil) }
    override public func mouseDragged(with event: NSEvent) {
        move(to: convert(event.locationInWindow, from: nil), pressure: Double(event.pressure),
             modifiers: Self.modifiers(event.modifierFlags))
    }
    func press(at point: CGPoint) {
        (anchor, live) = (point, [])
        redrawOverlay()
    }
    /// One drag sample: the overlay grows by `point` and the delegate hears the step in document points.
    func move(to point: CGPoint, pressure: Double = 1, modifiers: EventModifiers = []) {
        guard let from = anchor else { return }
        anchor = point
        live.append(point)
        redrawOverlay()
        delegate?.drag(from: documentPoint(from), to: documentPoint(point), pressure: pressure, modifiers: modifiers)
    }
    /// Ends the drag, a click with no move included: the delegate commits once and the overlay empties.
    func release() {
        guard anchor != nil else { return }
        anchor = nil
        delegate?.endDrag()
        live.removeAll(keepingCapacity: true)
        redrawOverlay()
    }

    /// The overlay's path through `live`, one element per sample; nil when it is empty.
    private func redrawOverlay() {
        let path = CGMutablePath()
        path.addLines(between: live)
        overlay.path = live.isEmpty ? nil : path
    }

    override public func scrollWheel(with event: NSEvent) {
        let step: CGFloat = event.hasPreciseScrollingDeltas ? 1 : SuiteSpacing.l
        pan.width += event.scrollingDeltaX * step
        pan.height -= event.scrollingDeltaY * step
        (needsLayout, needsDisplay) = (true, true)
    }
    override public func magnify(with event: NSEvent) {
        zoom = CGFloat(ZoomMath.clamped(Double(zoom * (1 + event.magnification))))
        (needsLayout, needsDisplay) = (true, true)
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override public func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        delegate?.hover(artboard.contains(point) ? documentPoint(point) : nil)
    }
    static func modifiers(_ flags: NSEvent.ModifierFlags) -> EventModifiers {
        let pairs: [(NSEvent.ModifierFlags, EventModifiers)] =
            [(.shift, .shift), (.control, .control), (.option, .option), (.command, .command), (.capsLock, .capsLock)]
        return pairs.reduce(into: EventModifiers()) { if flags.contains($1.0) { $0.insert($1.1) } }
    }
}
