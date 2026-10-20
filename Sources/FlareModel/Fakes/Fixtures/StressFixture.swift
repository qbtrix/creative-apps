// StressFixture.swift: `stress`, the document the real-app stress journeys open (FlareJourneyTests+StressPerf).
// One 1100 × 800 scene, 600 frames at 24 fps (25 s), 200 layers holding 500 ten-point pen stars (5,000 anchors)
// on a 25 × 20 grid every 44 pt across and 40 pt down from (22, 22); star k sits on layer k % 200, so every layer
// owns stars spread over the stage. Each layer is keyed on x at 0, 300 and 599 (600 keys) by a few points, so the
// grid stays put. The stage's top-left corner (above and left of (8, 8)) is empty for a marquee to start in.
import FlareCore

extension FlareFixtures {
    public static let stress: Document = {
        // cos and sin of 0°, 36°, ... 324° (the Model has no Foundation).
        let (c36, s36, c72, s72) = (0.809017, 0.587785, 0.309017, 0.951057)
        let unit: [(Double, Double)] = [(1, 0), (c36, s36), (c72, s72), (-c72, s72), (-c36, s36),
                                        (-1, 0), (-c36, -s36), (-c72, -s72), (c72, -s72), (c36, -s36)]
        func star(at c: Point) -> FlareShape {
            let points = unit.enumerated().map { i, u in
                let radius = i.isMultiple(of: 2) ? 14.0 : 6.0
                return Point(x: c.x + radius * u.0, y: c.y + radius * u.1)
            }
            return FlareShape(points: points, fill: .solid(FlareColor(r: 0.2, g: 0.5 + Double(Int(c.y) % 5) / 10, b: 0.9)))
        }
        var shapes = [[FlareShape]](repeating: [], count: 200)
        for k in 0..<500 {
            shapes[k % 200].append(star(at: Point(x: 22 + Double(k % 25) * 44, y: 22 + Double(k / 25) * 40)))
        }
        let layers = shapes.enumerated().map { i, owned in
            Layer(id: "star-\(i + 1)", name: "Stars \(i + 1)", shapes: owned, tracks: [
                "x": [Keyframe(frame: 0, value: 0), Keyframe(frame: 300, value: Double(i % 7)), Keyframe(frame: 599, value: 0)],
            ])
        }
        return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", fps: 24, durationFrames: 600,
                                            width: 1100, height: 800, layers: layers)])
    }()
}
