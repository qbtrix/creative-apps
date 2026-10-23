// AdjustKindsTests.swift (adjust-everywhere AJ-1 written disabled, AJ-5 turns
// it on): Black & White and Invert as tone steps. B&W gives a grey within one
// level and its weights move a colour's grey; the GPU program and the CPU list
// match within one level on a hue wheel; Invert twice is the input.
// Mutations (AJ-5): SuiteImaging.AdjustKinds (`.greyStaysInRange`,
// `.invertTwiceIsInput`).
import CoreRaster
import CoreRender
import Testing
import SuiteImaging

@Suite struct AdjustKindsTests {
    static let level: Float = 1.0 / 255

    /// 24 opaque hues round the wheel at full saturation, then a grey ramp of 8.
    static func hueWheel() throws -> PixelBuffer {
        var p = try PixelBuffer(width: 32, height: 1)
        for x in 0..<24 {
            let h = Float(x) / 4, f = h - h.rounded(.down), sector = Int(h)
            let rgb: (Float, Float, Float) = switch sector {
            case 0: (1, f, 0)
            case 1: (1 - f, 1, 0)
            case 2: (0, 1, f)
            case 3: (0, 1 - f, 1)
            case 4: (f, 0, 1)
            default: (1, 0, 1 - f)
            }
            try p.setPixel(x: x, y: 0, RGBA(r: rgb.0, g: rgb.1, b: rgb.2, a: 1))
        }
        for x in 24..<32 {
            let v = Float(x - 24) / 7
            try p.setPixel(x: x, y: 0, RGBA(r: v, g: v, b: v, a: 1))
        }
        return p
    }

    /// `pixels` through the CPU list, one step after another.
    static func cpu(_ kinds: [ImagingKind], _ pixels: PixelBuffer) throws -> PixelBuffer {
        let cpu = CPUBackend()
        var s = try cpu.surface(pixels)
        for step in AdjustKinds.adjustments(kinds) { s = try cpu.adjusted(s, step) }
        return try cpu.read(s)
    }

    /// `pixels` through the GPU program, as its kernel maps each pixel.
    static func gpu(_ kinds: [ImagingKind], _ pixels: PixelBuffer) throws -> PixelBuffer {
        let program = try ToneProgram(operations: AdjustKinds.program(kinds))
        var out = pixels
        for y in 0..<pixels.height {
            for x in 0..<pixels.width { try out.setPixel(x: x, y: y, program.map(try pixels.pixel(x: x, y: y))) }
        }
        return out
    }

    @Test func noKindsGiveNothing() {
        #expect(AdjustKinds.adjustments([]).isEmpty && AdjustKinds.program([]).isEmpty)
        #expect(AdjustKinds.adjustments([.invert]).count == AdjustKinds.program([.invert]).count)
    }

    /// Every pixel comes out grey, in range; a higher red weight lightens the red patch.
    @Test func greyStaysInRange() throws {
        let wheel = try Self.hueWheel()
        for route in [Self.cpu, Self.gpu] {
            let out = try route([.blackAndWhite(.neutral)], wheel)
            for x in 0..<out.width {
                let p = try out.pixel(x: x, y: 0)
                #expect(abs(p.r - p.g) <= Self.level && abs(p.g - p.b) <= Self.level, "x \(x)")
                #expect((0...1).contains(p.r) && (0...1).contains(p.b), "x \(x)")
            }
        }
        var bright = GrayWeights.neutral
        bright.red = 200
        let low = try Self.cpu([.blackAndWhite(.neutral)], wheel).pixel(x: 0, y: 0)
        let high = try Self.cpu([.blackAndWhite(bright)], wheel).pixel(x: 0, y: 0)
        #expect(high.r > low.r + 10 * Self.level)
    }

    /// The GPU program and the CPU list agree within one level on every hue.
    @Test func gpuMatchesCpu() throws {
        let wheel = try Self.hueWheel()
        var weights = GrayWeights.neutral
        (weights.yellow, weights.blue) = (120, -40)
        for kinds in [[ImagingKind.blackAndWhite(.neutral)], [.blackAndWhite(weights)], [.invert], [.blackAndWhite(weights), .invert]] {
            let a = try Self.cpu(kinds, wheel), b = try Self.gpu(kinds, wheel)
            for x in 0..<wheel.width {
                let p = try a.pixel(x: x, y: 0), q = try b.pixel(x: x, y: 0)
                for (u, w) in [(p.r, q.r), (p.g, q.g), (p.b, q.b)] { #expect(abs(u - w) <= Self.level, "\(kinds) x \(x)") }
            }
        }
    }

    /// Invert changes the picture; twice it is the input, on both routes.
    @Test func invertTwiceIsInput() throws {
        let wheel = try Self.hueWheel()
        for route in [Self.cpu, Self.gpu] {
            let once = try route([.invert], wheel), twice = try route([.invert, .invert], wheel)
            #expect(try once.pixel(x: 0, y: 0).g > 0.5)
            for x in 0..<wheel.width {
                let p = try wheel.pixel(x: x, y: 0), q = try twice.pixel(x: x, y: 0)
                for (u, w) in [(p.r, q.r), (p.g, q.g), (p.b, q.b)] { #expect(abs(u - w) <= Self.level, "x \(x)") }
            }
        }
    }
}
