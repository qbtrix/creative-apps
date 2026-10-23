// PathGesture.swift (pen-paths PN-3): the Pen and point editor's gesture
// mapping, pure and testable. Overlay view points in, the kernel's
// document-space PathIntents out: a Pen click adds an anchor, a press-drag
// one with a handle, a click near the first of three or more anchors closes;
// Direct Selection selects, moves anchors and handles under one drag token
// (Option breaks a handle) and marquees; keys nudge, remove, finish, cancel.
// PathEditOverlay draws it and feeds it presses, drags and keys.
import SuiteKernel
import SwiftUI

/// What the overlay edits: the draft and path (document space), the selected anchors, the tool and the zoom.
struct PathContext: Sendable {
    var draft: PenDraft?
    var path: PathInEdit?
    var selection: Selection<AnchorRef>
    var tool: PenTool
    var zoom: Double
    var scale: Double { PathMarks.scale(zoom) }
    func document(_ view: CGPoint) -> Point { Point(x: view.x / scale, y: view.y / scale) }
}

/// The keys the overlay answers.
enum PathKey: Sendable {
    case left, right, up, down, delete, returnKey, escape

    init?(_ key: KeyEquivalent) {
        switch key {
        case .leftArrow: self = .left
        case .rightArrow: self = .right
        case .upArrow: self = .up
        case .downArrow: self = .down
        case .delete, .deleteForward: self = .delete
        case .return: self = .returnKey
        case .escape: self = .escape
        default: return nil
        }
    }
}

/// What a click at the pointer would do, which picks the pointer's look.
enum PathCursorHint: Sendable {
    case penAdd, close, addPoint, removePoint, moveAnchor, moveHandle, marquee
}

/// One press-drag-release on the overlay, as path intents. Locations are
/// overlay view points (document pixels times the zoom); intents carry
/// document-space points and deltas. A drag's edits share the press's token.
struct PathGesture: Sendable {
    enum Press: Sendable, Equatable {
        case pen, close, insert, removeAnchor(AnchorRef), anchor, handle(AnchorRef, HandleEnd), marquee(extend: Bool)
    }

    private(set) var pressed: Press?
    private(set) var start = Point(x: 0, y: 0), current = Point(x: 0, y: 0)
    private var last = Point(x: 0, y: 0), token = "", scale = 1.0

    /// True when the view distance from the press to `current` is past `PenRules.anchorTolerance`.
    private var moved: Bool { hypot(current.x - start.x, current.y - start.y) * scale > PenRules.anchorTolerance }

    /// The Pen's anchor and the out handle it pulls, while a Pen press drags.
    var penHandle: (anchor: Point, handle: Point)? { pressed == .pen && moved ? (start, current) : nil }

    /// The marquee being dragged, document space.
    var marquee: Rect? {
        guard case .marquee = pressed, moved else { return nil }
        return Rect(minX: min(start.x, current.x), minY: min(start.y, current.y), maxX: max(start.x, current.x), maxY: max(start.y, current.y))
    }

    /// Starts a gesture at `location` over `hit`; the intents to run now.
    mutating func press(at location: CGPoint, hit: PathHit?, modifiers: KeyModifiers, token: String, in context: PathContext) -> [PathIntent] {
        (scale, self.token) = (context.scale, token)
        (start, current, last) = (context.document(location), context.document(location), context.document(location))
        switch context.tool {
        case .pen:
            if Self.closes(at: location, in: context) {
                pressed = .close
            } else if context.draft == nil, context.path != nil, case .segment? = hit {
                pressed = .insert
            } else if context.draft == nil, context.path != nil, case .anchor(let ref)? = hit {
                pressed = .removeAnchor(ref)
            } else {
                pressed = .pen
            }
            return []
        case .directSelect:
            switch hit {
            case .handle(let ref, let end)?:
                pressed = .handle(ref, end)
                return []
            case .anchor(let ref)?:
                pressed = .anchor
                return context.selection.contains(ref) ? [] : [.select(anchors: [ref], rect: nil, extend: modifiers.contains(.shift))]
            case .segment?, nil:
                pressed = .marquee(extend: modifiers.contains(.shift))
                return []
            }
        }
    }

    /// The pointer moved to `location` with the press held; the intents to run now.
    mutating func drag(to location: CGPoint, modifiers: KeyModifiers) -> [PathIntent] {
        current = Point(x: location.x / scale, y: location.y / scale)
        guard current != last else { return [] }
        defer { last = current }
        switch pressed {
        case .anchor: return [.move(dx: current.x - last.x, dy: current.y - last.y, drag: token)]
        case .handle(let ref, let end): return [.handle(ref, end, to: current, breaking: modifiers.contains(.option), drag: token)]
        default: return []
        }
    }

    /// The press let go at `location`; the intents to run now. The gesture is idle after.
    mutating func release(at location: CGPoint, modifiers: KeyModifiers) -> [PathIntent] {
        var intents = drag(to: location, modifiers: modifiers)
        switch pressed {
        case .pen: intents.append(.penAdd(start, handleOut: moved ? current : nil))
        case .close: intents.append(.close)
        case .insert: intents.append(.insert(start))
        case .removeAnchor(let ref): intents += [.select(anchors: [ref], rect: nil, extend: false), .remove]
        case .marquee(let extend):
            let extend = extend || modifiers.contains(.shift)
            if let rect = marquee {
                intents.append(.select(anchors: nil, rect: rect, extend: extend))
            } else if !extend {
                intents.append(.select(anchors: [], rect: nil, extend: false))
            }
        case .anchor, .handle, nil: break
        }
        pressed = nil
        return intents
    }

    /// True when a Pen click at `location` closes the draft: three or more
    /// anchors and the first within `PenRules.closeDistance` view points.
    static func closes(at location: CGPoint, in context: PathContext) -> Bool {
        guard context.tool == .pen, let anchors = context.draft?.contour.anchors, anchors.count >= 3, let first = anchors.first else { return false }
        let s = context.scale
        return hypot(first.point.x * s - location.x, first.point.y * s - location.y) <= PenRules.closeDistance
    }

    /// What a click at `location` over `hit` would do.
    static func hint(at location: CGPoint, hit: PathHit?, in context: PathContext) -> PathCursorHint {
        switch (context.tool, hit) {
        case (.pen, _) where closes(at: location, in: context): .close
        case (.pen, .segment?) where context.draft == nil && context.path != nil: .addPoint
        case (.pen, .anchor?) where context.draft == nil && context.path != nil: .removePoint
        case (.pen, _): .penAdd
        case (.directSelect, .handle?): .moveHandle
        case (.directSelect, .anchor?): .moveAnchor
        case (.directSelect, _): .marquee
        }
    }

    /// The intents for `key`: arrows nudge the selection 1 pixel (10 with
    /// Shift), Delete removes it, Return finishes the draft, Escape cancels the
    /// draft or else clears the selection. Empty when the key does nothing.
    static func key(_ key: PathKey, modifiers: KeyModifiers, in context: PathContext) -> [PathIntent] {
        let step = modifiers.contains(.shift) ? 10.0 : 1.0
        let picked = context.path != nil && !context.selection.ordered.isEmpty
        switch key {
        case .left, .right, .up, .down:
            guard picked else { return [] }
            let dx = key == .left ? -step : key == .right ? step : 0
            let dy = key == .up ? -step : key == .down ? step : 0
            return [.move(dx: dx, dy: dy, drag: nil)]
        case .delete: return picked ? [.remove] : []
        case .returnKey: return context.draft == nil ? [] : [.finish]
        case .escape:
            if context.draft != nil { return [.cancel] }
            return picked ? [.select(anchors: [], rect: nil, extend: false)] : []
        }
    }
}
