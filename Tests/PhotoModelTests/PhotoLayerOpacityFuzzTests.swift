// PhotoLayerOpacityFuzzTests.swift: adversarial opacity input for PhotoLayer's
// initializer and PhotoWorkspace.setOpacity: NaN payloads and signs, signed
// zero, subnormals, the floats either side of 0 and 1, and random bit
// patterns. Opacity must always land in 0...1 with no negative zero. Runs on
// Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoLayerOpacityFuzzTests {
    @Test(arguments: [
        -Double.nan,
        Double(nan: 0x1234, signaling: false),
        -Double(nan: 0x1234, signaling: true),
        Double(bitPattern: 0x7FFF_FFFF_FFFF_FFFF),
        Double(bitPattern: 0xFFF0_0000_0000_0001),
    ])
    func everyNaNFallsBackToOpaque(input: Double) {
        let layer = PhotoLayer(id: "x", name: "x", opacity: input)
        #expect(layer.opacity == 1)
        #expect(layer == PhotoLayer(id: "x", name: "x"))
    }

    @Test(arguments: [
        (-0.0, 0.0),
        (-Double.leastNonzeroMagnitude, 0.0),
        (Double.leastNonzeroMagnitude, Double.leastNonzeroMagnitude),
        (Double.leastNormalMagnitude, Double.leastNormalMagnitude),
        (1.0.nextDown, 1.0.nextDown),
        (1.0.nextUp, 1.0),
        (Double.greatestFiniteMagnitude, 1.0),
        (-Double.greatestFiniteMagnitude, 0.0),
    ])
    func edgeFloatsClampWithoutNegativeZero(input: Double, expected: Double) {
        let layer = PhotoLayer(id: "x", name: "x", opacity: input)
        #expect(layer.opacity == expected)
        #expect(layer.opacity.sign == .plus)
        #expect(layer.opacityPercent.sign == .plus)
    }

    @Test func randomBitPatternsStayInUnitRange() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<10_000 {
            let input = Double(bitPattern: UInt64.random(in: .min ... .max, using: &generator))
            let layer = PhotoLayer(id: "x", name: "x", opacity: input)
            #expect((0...1).contains(layer.opacity), "input bits \(input.bitPattern)")
            #expect((0...100).contains(layer.opacityPercent))
        }
    }

    @Test func setOpacityIgnoresEveryNaNAndClampsTheRest() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        guard let id = workspace.layers.first?.id else {
            Issue.record("a new canvas has a layer")
            return
        }
        workspace.setOpacity(id, percent: 40)
        for nan in [Double.nan, -Double.nan, Double.signalingNaN, Double(nan: 7, signaling: false)] {
            workspace.setOpacity(id, percent: nan)
            #expect(workspace.layers.first?.opacity == 0.4)
        }
        workspace.setOpacity(id, percent: -0.0)
        #expect(workspace.layers.first?.opacity.sign == .plus)
        workspace.setOpacity(id, percent: .greatestFiniteMagnitude)
        #expect(workspace.layers.first?.opacity == 1)
        workspace.setOpacity(id, percent: -.infinity)
        #expect(workspace.layers.first?.opacity == 0)
    }

    @Test func setOpacityRandomBitPatternsStayInUnitRange() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        guard let id = workspace.layers.first?.id else {
            Issue.record("a new canvas has a layer")
            return
        }
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<10_000 {
            let percent = Double(bitPattern: UInt64.random(in: .min ... .max, using: &generator))
            workspace.setOpacity(id, percent: percent)
            let opacity = workspace.layers.first?.opacity ?? .nan
            #expect((0...1).contains(opacity), "percent bits \(percent.bitPattern)")
        }
    }
}
