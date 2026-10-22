// ImagingProgramTests.swift: AdjustSettings compiled to tone steps, and the
// route that runs them (suite-imaging IM-4). Mutations (IM-4):
// SuiteImaging.ImagingProgram (`.gammaSameMeaning`, `.cpuListEqualsGpuList`,
// `.order`).
import CoreRaster
import CoreRender
import Testing
import SuiteImaging

@Suite struct ImagingProgramTests {
    static let edited = AdjustSettings(
        exposure: 0.5,
        levels: AdjustLevels(inputBlack: 0.05, inputWhite: 0.95, gamma: 1.6, outputBlack: 0, outputWhite: 1),
        curve: AdjustCurve(points: [AdjustCurvePoint(x: 0, y: 0), AdjustCurvePoint(x: 0.5, y: 0.6), AdjustCurvePoint(x: 1, y: 1)]),
        hueSaturation: AdjustHueSaturation(hue: 20, saturation: -40, lightness: 10))

    static let contrast = ToneAdjustment.contrast(25)

    /// A step's kind, for order checks.
    static func kind(_ step: ToneAdjustment) -> String {
        switch step {
        case .exposure: "exposure"
        case .levels: "levels"
        case .curves: "curve"
        case .hueSaturation: "hueSaturation"
        default: "tone"
        }
    }

    @Test func neutralGivesNothing() {
        #expect(ImagingProgram.adjustments(.neutral) == [])
        #expect(ImagingProgram.program(.neutral) == [])
    }

    @Test func order() {
        let steps = ImagingProgram.adjustments(Self.edited, tone: [Self.contrast])
        #expect(steps.map(Self.kind) == ["tone", "exposure", "levels", "curve", "hueSaturation"])
        #expect(ImagingProgram.program(Self.edited, tone: [.adjustment(Self.contrast)]).first == .adjustment(Self.contrast))
    }

    /// Levels' gamma means the same thing on both lists: core's gamma, not its reciprocal.
    @Test func gammaSameMeaning() {
        let gammas = ImagingProgram.adjustments(Self.edited).compactMap { step -> Float? in
            if case .levels(_, _, let gamma, _, _, _) = step { return gamma } else { return nil }
        }
        #expect(gammas == [1.6])
    }

    /// Every settings step reaches the CPU list, so the lists can't differ by a dropped step.
    @Test func cpuListEqualsGpuList() {
        let cpu = ImagingProgram.adjustments(Self.edited)
        let gpu = ImagingProgram.program(Self.edited)
        #expect(cpu.count == 4)
        #expect(cpu.count == gpu.count)
    }

    /// The CPU backend renders both lists to the same picture, within one level.
    @Test func cpuEqualsGpu() throws {
        let cpu = CPUBackend()
        var ramp = try PixelBuffer(width: 16, height: 1)
        for x in 0..<16 {
            let v = Float(x) / 15
            try ramp.setPixel(x: x, y: 0, RGBA(r: v, g: 1 - v, b: v * 0.5, a: 1))
        }
        var stepwise = try cpu.surface(ramp)
        for step in ImagingProgram.adjustments(Self.edited, tone: [Self.contrast]) {
            stepwise = try cpu.adjusted(stepwise, step)
        }
        let program = try ToneProgram(operations: ImagingProgram.program(Self.edited, tone: [.adjustment(Self.contrast)]))
        let onePass = try cpu.adjusted(try cpu.surface(ramp), tone: program)
        let a = try cpu.read(stepwise), b = try cpu.read(onePass)
        for x in 0..<16 {
            let p = try a.pixel(x: x, y: 0), q = try b.pixel(x: x, y: 0)
            for (u, w) in [(p.r, q.r), (p.g, q.g), (p.b, q.b)] {
                #expect(abs(u - w) <= 1.0 / 255, "x \(x)")
            }
        }
    }

    /// A step whose family isn't on Metal yet sends the whole list to the CPU.
    @Test func colorStepChoosesCPU() {
        let color = ToneAdjustment.vibrance(20)
        #expect(RenderOp.notOnMetalYet.contains(color.family))
        #expect(ImagingRoute.choose(preferGPU: true, steps: [.exposure(stops: 1), color]) == .cpu)
        #expect(ImagingRoute.choose(preferGPU: true, steps: [.exposure(stops: 1)]) == .gpu)
        #expect(ImagingRoute.choose(preferGPU: false, steps: [.exposure(stops: 1)]) == .cpu)
    }
}
