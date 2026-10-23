// DesignPlace+Canvas.swift (placed-images PD-u, PD-3 and PD-4): what the canvas, File > Place… and the
// inspector's Image section ask about a picture. `placedImage` is a node's picture in its frame, which the
// canvas draws by cover. `runPlace` runs a `PlaceIntent` through the catalog and says why it refused, and
// `placeActionHelp` is why Place…, Replace… or Reset Size is off: until PD-5 registers the place commands,
// both say so. An ⌥-drag that starts inside the selected unlocked picture pans its focus by the overflow,
// each step under one token (`beginPicturePan`, `panIntent`); a drop's page point is `dropPoint`, and it
// fills the selected frame or rectangle under it when Fill is on (`dropFills`). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension DesignNode {
    /// The node's picture, its box the node's frame; nil when it shows none.
    public var placedImage: PlacedImage? {
        placedAsset.map { PlacedImage(assetID: $0.id, box: frame.kernelRect, focus: placedFocus) }
    }
}

/// An ⌥-drag panning the selected picture: where it began, the focus there, and the token its steps share.
public struct DesignPicturePan: Sendable, Equatable {
    public let start: DesignPoint, focus: Point, token: String
}

extension DesignWorkspace {
    /// Why a place command can't run while the catalog has no spec for it.
    static let placeNotRegistered = "Placing pictures isn't built yet."

    /// The command `intent` runs; a place with `fill` asks to fill the selected frame.
    public static func placeCommand(_ intent: PlaceIntent, fill: Bool) -> (id: String, params: JSONValue) {
        let (id, params) = intent.command
        guard fill, case .place = intent, case .object(var fields) = params else { return (id, params) }
        fields["fill"] = .bool(true)
        return (id, .object(fields))
    }

    /// Why place command `id` can't run now; nil when it can.
    public func placeActionHelp(_ id: String = "place.image") -> String? {
        guard Self.catalog.spec(id) != nil else { return placeHelp ?? Self.placeNotRegistered }
        return Self.catalog.availability(id, on: self).why
    }

    /// Runs `intent` (with `fill`, into the selected frame) as one step; why it refused, nil when it ran.
    @discardableResult
    public mutating func runPlace(_ intent: PlaceIntent, fill: Bool = false) -> String? {
        let (id, params) = Self.placeCommand(intent, fill: fill)
        do {
            _ = try Self.catalog.run(id, params: params, on: &self)
            return nil
        } catch {
            switch error {
            case .unknownCommand: return placeActionHelp(id)
            case .unavailable(_, let why): return why
            default: return error.description
            }
        }
    }

    /// The pan an ⌥-drag from `point` starts: the selected node shows a picture under it and is unlocked.
    public func beginPicturePan(at point: DesignPoint, option: Bool, token: String = UUID().uuidString) -> DesignPicturePan? {
        guard option, let node = selectedNode, node.placedAsset != nil, node.frame.contains(point), lockHelp(node.id) == nil
        else { return nil }
        return DesignPicturePan(start: point, focus: node.placedFocus, token: token)
    }

    /// The focus step dragging `pan` to `point`: the picture follows the pointer on each axis it overflows.
    public func panIntent(_ pan: DesignPicturePan, to point: DesignPoint) -> PlaceIntent? {
        guard let selection = placedSelection else { return nil }
        let box = selection.image.box, drawn = PlaceRules.drawnRect(selection.image, natural: selection.asset.natural)
        func moved(_ focus: Double, _ delta: Double, _ excess: Double) -> Double {
            excess >= 1 ? min(max(focus - delta / excess, 0), 1) : focus
        }
        let focus = Point(x: moved(pan.focus.x, point.x - pan.start.x, drawn.width - box.width),
                          y: moved(pan.focus.y, point.y - pan.start.y, drawn.height - box.height))
        return .focus(focus, drag: pan.token)
    }

    /// A drop at (`x`, `y`) in the artwork's view at `zoom`, in page points; nil at a zoom that isn't positive.
    public static func dropPoint(x: Double, y: Double, zoom: Double) -> DesignPoint? {
        guard zoom.isFinite, zoom > 0 else { return nil }
        return DesignPoint(x: x / zoom, y: y / zoom)
    }

    /// Whether a drop at `point` fills the selection: Fill is on and it lands in the selected unlocked frame or rectangle.
    public func dropFills(at point: DesignPoint, fill: Bool) -> Bool {
        guard fill, let node = selectedNode, node.kind.holdsPicture, node.frame.contains(point) else { return false }
        return lockHelp(node.id) == nil
    }
}
