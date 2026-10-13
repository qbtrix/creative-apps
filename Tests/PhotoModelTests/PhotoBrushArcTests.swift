// PhotoBrushArcTests.swift: a fast drag along a curve paints the curve, not
// the straight chords between the pointer samples. A quick hand, or a window
// busy with slow events, sends samples a hundred pixels apart; dabs laid on
// the straight line between each pair turn a circle into a polygon. The test
// draws the top half of a circle from samples 18° apart (110 px, 4.3 px of
// chord sag) with a small hard brush and checks the paint against the true
// arc. The first and last segments are skipped, so a smoother may wait for
// the next sample or guess past the ends. Runs on Linux and macOS.
import CoreRaster
import Foundation
import PhotoModel
import Testing

@Suite struct PhotoBrushArcTests {
    @Test func sparseSamplesAlongAnArcPaintTheArcNotItsChords() throws {
        let (cx, cy, radius) = (500.0, 500.0, 350.0)
        let angles = stride(from: 180.0, through: 360.0, by: 18.0).map { $0 * .pi / 180 }
        let samples = angles.map { point(cx + radius * cos($0), cy + radius * sin($0)) }
        var workspace = try whiteImage(1000, 600)
        workspace.setToolOption(.size(3))
        workspace.selectTool(.brush)
        workspace.drag(from: samples[0], to: samples[0])
        for (a, b) in zip(samples, samples.dropFirst()) { workspace.drag(from: a, to: b) }
        workspace.endDrag()
        let layer = try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] })
        let inside = angles[1]...angles[angles.count - 2]

        // Fully painted pixels sit within half a pixel of a dab, so with every
        // dab within 1 px of the arc, none is more than 1.5 px off it.
        var worst = 0.0
        for y in 0..<layer.height {
            for x in 0..<layer.width {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                let angle = atan2(dy, dx) + (dy < 0 ? 2 * .pi : 0)
                guard inside.contains(angle), try layer.pixel(x: x, y: y).r <= 0.01 else { continue }
                worst = max(worst, abs((dx * dx + dy * dy).squareRoot() - radius))
            }
        }
        #expect(worst <= 1.5, "paint lies \(worst) px off the arc; the dabs follow the chords")

        // And the arc itself is painted, every quarter degree of it.
        var gaps = 0
        for angle in stride(from: inside.lowerBound, through: inside.upperBound, by: .pi / 720) {
            let (x, y) = (Int(cx + radius * cos(angle)), Int(cy + radius * sin(angle)))
            if try layer.pixel(x: x, y: y).r >= 0.5 { gaps += 1 }
        }
        #expect(gaps == 0, "\(gaps) points along the arc are left unpainted")
    }
}
