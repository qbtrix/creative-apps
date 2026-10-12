// PhotoLayerInitTests.swift: PhotoLayer's initializer keeps opacity in 0...1
// for any input, NaN and infinities included. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoLayerInitTests {
    @Test func nanOpacityFallsBackToOpaque() {
        let layer = PhotoLayer(id: "x", name: "x", opacity: .nan)
        #expect(layer.opacity == 1)
        #expect(layer.opacityPercent == 100)
    }

    @Test func signalingNaNOpacityFallsBackToOpaque() {
        let layer = PhotoLayer(id: "x", name: "x", opacity: .signalingNaN)
        #expect(layer.opacity == 1)
    }

    @Test(arguments: [
        (Double.infinity, 1.0),
        (-Double.infinity, 0.0),
        (2.5, 1.0),
        (-0.5, 0.0),
        (0.0, 0.0),
        (0.4, 0.4),
        (1.0, 1.0),
    ])
    func opacityClampsToUnitRange(input: Double, expected: Double) {
        let layer = PhotoLayer(id: "x", name: "x", opacity: input)
        #expect(layer.opacity == expected)
        #expect((0...1).contains(layer.opacity))
    }
}
