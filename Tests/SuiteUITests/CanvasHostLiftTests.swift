// CanvasHostLiftTests.swift: the canvas host's lift (CanvasHostView+Lift.swift). A lifted layer's corners land
// where its placement puts them in document pixels (y down), through the host's zoom and turn, on the tile
// path; a move changes only the transform; a drop removes the layer. macOS only.
import AppKit
import Testing

@testable import SuiteUI

@MainActor
@Suite struct CanvasHostLiftTests {
    struct Content: CanvasContentProviding {
        var documentSize: CGSize { CGSize(width: 200, height: 100) }
        func tiles(dirtyOnly: Bool) -> [CanvasTile] { [] }
    }

    /// `point` in the lifted layer's own pixels (y down), in the host's root layer.
    static func onScreen(_ point: CGPoint, of host: CanvasHostView, size: CGSize) throws -> CGPoint {
        let lifted = try #require(host.lifted)
        return lifted.convert(CGPoint(x: point.x, y: size.height - point.y), to: try #require(host.layer))
    }

    /// Document pixel `point` (y down) where the picture's tiles show it, in the host's root layer.
    static func picture(_ point: CGPoint, of host: CanvasHostView) throws -> CGPoint {
        host.container.convert(CGPoint(x: point.x, y: host.documentSize.height - point.y), to: try #require(host.layer))
    }

    /// Each corner of the lifted pixels shows where the picture shows the document point its placement names,
    /// unturned and turned.
    @Test(arguments: [0.0, 17.0])
    func liftedCornersLandWhereThePlacementPutsThem(turn degrees: Double) throws {
        let host = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))  // the document's aspect, as a viewport sizes it
        host.isEmbedded = true
        host.rotationDegrees = degrees
        host.show(Content())
        host.layoutSubtreeIfNeeded()
        let size = CGSize(width: 40, height: 20)
        let placement = CGAffineTransform(translationX: 30, y: 10).rotated(by: .pi / 6).scaledBy(x: 1.5, y: 0.5)
        host.lift(NSNull(), size: size, opacity: 0.5, placement: placement)
        for corner in [CGPoint.zero, CGPoint(x: 40, y: 0), CGPoint(x: 0, y: 20), CGPoint(x: 40, y: 20)] {
            let (got, want) = (try Self.onScreen(corner, of: host, size: size), try Self.picture(corner.applying(placement), of: host))
            #expect(abs(got.x - want.x) < 1e-6 && abs(got.y - want.y) < 1e-6, "corner \(corner): \(got) not \(want)")
        }
        if degrees == 0 {
            let topLeft = host.documentPoint(try Self.onScreen(.zero, of: host, size: size))
            #expect(abs(topLeft.x - 30) < 1e-6 && abs(topLeft.y - 10) < 1e-6, "\(topLeft)")
        }
        #expect(host.lifted?.opacity == 0.5)
    }

    @Test func aMoveSetsTheTransformAndADropRemovesTheLayer() throws {
        let host = CanvasHostView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))  // the document's aspect, as a viewport sizes it
        host.isEmbedded = true
        host.show(Content())
        host.layoutSubtreeIfNeeded()
        let size = CGSize(width: 40, height: 20)
        host.lift(NSNull(), size: size, opacity: 1, placement: .identity)
        let layer = try #require(host.lifted)
        host.moveLift(CGAffineTransform(translationX: 50, y: 25))
        #expect(host.lifted === layer, "a move made a new layer")
        let got = host.documentPoint(try Self.onScreen(.zero, of: host, size: size))
        #expect(abs(got.x - 50) < 1e-6 && abs(got.y - 25) < 1e-6, "\(got)")
        host.dropLift()
        #expect(!host.isLifted && layer.superlayer == nil)
        host.moveLift(.identity)  // nothing lifted: nothing happens
        #expect(!host.isLifted)
    }
}
