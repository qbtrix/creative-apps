// CanvasMarks+Anchor.swift (anchor-parenting AN-5): the anchor mark, a crosshair
// in a circle; accent on hover, larger while pressed. A drag moves only the mark
// (its own state) and `onDrop` runs once at release; Shift snaps to the nine points.
import AppKit
import SuiteKernel
import SwiftUI

/// Where an anchor drag let go: on one of the box's nine points (Shift held), or at a document point.
public enum AnchorDrop: Equatable, Sendable { case at(BoxAnchor), point(CGPoint) }

/// The anchor mark at a document point, draggable; `snaps` are the box's nine points in document pixels.
public struct AnchorMark: View {
    private let point: CGPoint, zoom: Double, snaps: [BoxAnchor: CGPoint]
    private let onDrop: @MainActor (AnchorDrop) -> Void
    /// The mark's centre in view points while a drag is down.
    @State private var live: CGPoint?
    @State private var hovering = false

    public init(point: CGPoint, zoom: Double, snaps: [BoxAnchor: CGPoint], onDrop: @escaping @MainActor (AnchorDrop) -> Void) {
        (self.point, self.zoom, self.snaps, self.onDrop) = (point, zoom, snaps, onDrop)
    }

    public var body: some View {
        let s = MotionPathMarks.scale(zoom), home = CGPoint(x: point.x * s, y: point.y * s)
        let shape = AnchorMarkShape(center: live ?? home, pressed: live != nil)
        let drop = { (t: CGSize) in Self.drop(at: CGPoint(x: point.x + t.width / s, y: point.y + t.height / s), snaps: snaps,
                                               shift: NSEvent.modifierFlags.contains(.shift)) }
        ZStack(alignment: .topLeading) {
            shape.stroke(SuiteColor.overlayPaper, style: StrokeStyle(lineWidth: SuiteSize.pointMarkPaper, lineCap: .round))
                .allowsHitTesting(false).accessibilityHidden(true)
            shape.stroke(hovering || live != nil ? SuiteColor.accent : SuiteColor.overlayInk,
                         style: StrokeStyle(lineWidth: SuiteSize.pointMarkInk, lineCap: .round))
                .allowsHitTesting(false).accessibilityHidden(true)
            Color.clear
                .frame(width: SuiteSize.anchorHit, height: SuiteSize.anchorHit)
                .contentShape(Circle())
                .onHover { hovering = $0 }
                .pointerStyle(live == nil ? .grabIdle : .grabActive)
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { live = shown(drop($0.translation), s) }
                    .onEnded { live = nil; onDrop(drop($0.translation)) })
                .accessibilityElement()
                .accessibilityLabel("Anchor")
                .accessibilityIdentifier("suite.anchor.mark")
                .position(home)
        }
        .allowsWindowActivationEvents()
    }

    /// The hit radius in view points: half of `anchorHit` at every zoom.
    nonisolated static func hitRadius(zoom _: Double) -> CGFloat { SuiteSize.anchorHit / 2 }
    /// Whether `view` (view points) is within the hit radius of the mark at document point `mark`.
    nonisolated static func hits(_ view: CGPoint, mark: CGPoint, zoom: Double) -> Bool {
        let s = MotionPathMarks.scale(zoom)
        return hypot(view.x - mark.x * s, view.y - mark.y * s) <= hitRadius(zoom: zoom)
    }
    /// With `shift`, the nearest of `snaps` (none: `doc` itself); otherwise `doc`.
    nonisolated static func drop(at doc: CGPoint, snaps: [BoxAnchor: CGPoint], shift: Bool) -> AnchorDrop {
        let nearest = BoxAnchor.allCases.compactMap { at in snaps[at].map { (at, hypot($0.x - doc.x, $0.y - doc.y)) } }.min { $0.1 < $1.1 }
        guard shift, let nearest else { return .point(doc) }
        return .at(nearest.0)
    }
    /// A drop's centre in view points, where the mark sits while the drag is down.
    private func shown(_ drop: AnchorDrop, _ s: Double) -> CGPoint {
        let doc: CGPoint = switch drop {
        case .at(let at): snaps[at] ?? point
        case .point(let p): p
        }
        return CGPoint(x: doc.x * s, y: doc.y * s)
    }
}

/// A circle with a crosshair across it around `center`, in view points; larger while pressed.
private struct AnchorMarkShape: Shape {
    let center: CGPoint, pressed: Bool
    func path(in _: CGRect) -> Path {
        let r = (pressed ? SuiteSize.pointMarkRing + SuiteSize.pointMarkCross : SuiteSize.pointMarkRing) / 2
        var path = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
        path.addLines([CGPoint(x: center.x - r, y: center.y), CGPoint(x: center.x + r, y: center.y)])
        path.addLines([CGPoint(x: center.x, y: center.y - r), CGPoint(x: center.x, y: center.y + r)])
        return path
    }
}
