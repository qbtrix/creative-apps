// PhotoOrientation+Kernel.swift (orientation-crop OC-12): Photo on the kernel's Orientation. Photo
// bakes every turn and flip into the pixels, so its image always faces up and a new orientation
// is applied to the pixels as they are, as at most one flip then one turn. Each is an exact
// CoreRaster op on every layer's pixels and mask, with its offset moved so the layer keeps its
// place; the whole change is one undo step. Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace: OrientationTarget {
    /// One exact op on the whole image: a quarter or half turn clockwise, or a mirror.
    enum OrientationStep: Hashable, Sendable { case turn(QuarterTurn), flip(FlipAxis) }

    /// Why the image can't turn or flip: no image, or Free Transform is open; nil when it can.
    public var orientationHelp: String? { canvas == nil ? Self.noImage : flipHelp }

    /// Photo's pixels hold every turn, so the image always faces up.
    public var orientation: Orientation { .up }

    /// Faces the image `o` from how it looks now, as one undo step named `name`.
    public mutating func setOrientation(_ o: Orientation, name: String) throws {
        if let help = orientationHelp { throw PhotoRefusal(help) }
        guard let steps = Self.orientationSteps.first(where: { Self.product($0) == o }), !steps.isEmpty else { return }
        record(.group([.stack(stackState), .selection(selection, selectionMask)]), named: name)
        for step in steps { face(step) }
        pendingCrop = nil
        touch(.all)
    }

    /// Image > Flip Canvas: mirrors every layer across the whole canvas as one undo step.
    public mutating func flipCanvas(_ axis: FlipAxis) throws {
        try setOrientation(Orientation.up.flipped(axis), name: axis == .horizontal ? "Flip Horizontal" : "Flip Vertical")
    }

    /// Every orientation as a flip then a turn, the identity first.
    static let orientationSteps: [[OrientationStep]] = [
        [], [.turn(.degrees90)], [.turn(.degrees180)], [.turn(.degrees270)], [.flip(.horizontal)], [.flip(.vertical)],
        [.flip(.horizontal), .turn(.degrees90)], [.flip(.horizontal), .turn(.degrees270)],
    ]

    /// The kernel's orientation for `steps` taken in order from up.
    static func product(_ steps: [OrientationStep]) -> Orientation {
        steps.reduce(Orientation.up) { o, step in
            switch step {
            case .flip(let axis): o.flipped(axis)
            case .turn(.degrees90): o.rotated(clockwise: true)
            case .turn(.degrees180): o.rotated(clockwise: true).rotated(clockwise: true)
            case .turn(.degrees270): o.rotated(clockwise: false)
            }
        }
    }

    /// `buffer` turned or mirrored by `step`.
    static func faced(_ buffer: PixelBuffer, _ step: OrientationStep) -> PixelBuffer {
        switch step {
        case .turn(let turn): buffer.rotated(turn)
        case .flip(let axis): buffer.flipped(axis == .horizontal ? .horizontal : .vertical)
        }
    }

    /// Applies `step` to every layer, its mask, its offset, the selection and the canvas.
    private mutating func face(_ step: OrientationStep) {
        guard let canvas else { return }
        let (w, h) = (canvas.width, canvas.height)
        for (at, layer) in layers.enumerated() {
            // A layer's own size always flattens, so this skips only a layer without pixels.
            guard let buffer = try? pixels[layer.id]?.flattened() else { continue }
            let (x, y, lw, lh) = (layer.offsetX, layer.offsetY, buffer.width, buffer.height)
            let offset = switch step {
            case .flip(let axis): axis == .horizontal ? (w - (x + lw), y) : (x, h - (y + lh))
            case .turn(.degrees90): (h - (y + lh), x)
            case .turn(.degrees180): (w - (x + lw), h - (y + lh))
            case .turn(.degrees270): (y, w - (x + lw))
            }
            pixels[layer.id] = TiledPixels(Self.faced(buffer, step))
            if let mask = try? masks[layer.id]?.flattened() { masks[layer.id] = TiledPixels(Self.faced(mask, step)) }
            layers[at].offsetX = offset.0
            layers[at].offsetY = offset.1
        }
        // Every layer hears once, a layer without pixels (an adjustment layer) too.
        for layer in layers {
            switch step {
            case .turn(let turn): layerGeometryChanged(layer.id, .rotated(turn))
            case .flip(let axis): layerGeometryChanged(layer.id, .flippedCanvas(axis))
            }
        }
        switch step {
        case .flip(let axis) where selectionMask == nil:
            selection = selection.map { r in
                axis == .horizontal ? PixelRect(x: w - r.maxX, y: r.y, width: r.width, height: r.height)
                    : PixelRect(x: r.x, y: h - r.maxY, width: r.width, height: r.height)
            }
        case .turn(.degrees90), .turn(.degrees270):
            self.canvas = CanvasSize(width: h, height: w)
            fallthrough
        default:
            selection = nil
            selectionMask = nil
        }
    }
}
