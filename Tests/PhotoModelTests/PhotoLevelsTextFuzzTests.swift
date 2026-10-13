// PhotoLevelsTextFuzzTests.swift: seeded fuzz for Levels Black and White
// through text, the way a user types them. Random edits, including NaN,
// infinities, negatives, subnormals and values a hair off a step, keep black
// below white, keep both on the levelsStep grid (applying the stored value
// again changes nothing), and keep the two fields' text distinct. Each shown
// text, parsed back as a Double, gives the stored point itself. `text` copies
// NumericInput.format's rounding, since SuiteUI doesn't build on Linux.
// Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoLevelsTextFuzzTests {
    /// SplitMix64, so every run sees the same edits.
    private struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// What a field at levelsDecimals shows, rounded like NumericInput.format.
    private func text(_ value: Float) -> String {
        var scale = 1.0
        for _ in 0..<AdjustmentSettings.levelsDecimals { scale *= 10 }
        let rounded = (Double(value) * scale).rounded() / scale
        return rounded == rounded.rounded() ? String(Int64(rounded)) : String(rounded)
    }

    /// A level a user or a slider might send: mostly inside 0...1, sometimes
    /// right next to a step or a bound, sometimes junk.
    private func edit(_ generator: inout Generator) -> Float {
        let step = Float(AdjustmentSettings.levelsStep)
        switch Int.random(in: 0..<10, using: &generator) {
        case 0: return [.nan, .infinity, -.infinity, -0.0, .leastNonzeroMagnitude, -1, 2].randomElement(using: &generator) ?? 0
        case 1:
            let sign: Float = Bool.random(using: &generator) ? 1 : -1
            return Float(Int.random(in: 0...1000, using: &generator)) * step + sign * step / 2
        case 2: return Float(Int.random(in: 0...1000, using: &generator)) * step
        case 3: return [Float(1).nextDown, Float(0).nextUp, 1 - step, step].randomElement(using: &generator) ?? 0
        default: return Float.random(in: 0...1, using: &generator)
        }
    }

    @Test(arguments: [UInt64(1), 77, 251, 0xC0FFEE])
    func randomEditsKeepTheFieldsHonest(seed: UInt64) {
        var generator = Generator(state: seed)
        var settings = AdjustmentSettings()
        for _ in 0..<5000 {
            let value = edit(&generator)
            settings.apply(Bool.random(using: &generator) ? .blackPoint(value) : .whitePoint(value))
            #expect(settings.blackPoint < settings.whitePoint)
            #expect(AdjustmentSettings.levelsRange.contains(settings.blackPoint))
            #expect(AdjustmentSettings.levelsRange.contains(settings.whitePoint))
            #expect(text(settings.blackPoint) != text(settings.whitePoint))
            var again = settings
            again.apply(.blackPoint(settings.blackPoint))
            again.apply(.whitePoint(settings.whitePoint))
            #expect(again == settings)
            for point in [settings.blackPoint, settings.whitePoint] {
                let typed = Double(text(point)).map(Float.init)
                #expect(typed == point, "\(point) shows \(text(point))")
            }
        }
    }

    @Test func typingTheShownTextOfEveryStepIsANoOp() {
        for index in 1...1000 {
            var settings = AdjustmentSettings()
            settings.apply(.whitePoint(Float(index) / 1000))
            let shown = text(settings.whitePoint)
            guard let typed = Double(shown) else {
                Issue.record("\(shown) does not parse")
                continue
            }
            let before = settings
            settings.apply(.whitePoint(Float(typed)))
            #expect(settings == before, "white \(before.whitePoint) shows \(shown)")
            #expect(shown.split(separator: ".").last.map { $0.count <= AdjustmentSettings.levelsDecimals } ?? true)
        }
    }
}
