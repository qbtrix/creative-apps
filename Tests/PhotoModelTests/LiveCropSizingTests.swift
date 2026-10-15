// LiveCropSizingTests.swift: PV-3's live crop geometry (photo-crop CP-1).
// Typed fields clamp to the canvas, a locked drag keeps its ratio, an aspect
// reshapes the crop about its center, and 1,000 seeded random inputs never
// leave the canvas, drop below 1 x 1 or break the ratio by more than 1 px.
// Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct LiveCropSizingTests {
    let crop = PhotoServices.live.crop
    let canvas = CanvasSize(width: 800, height: 600)

    private func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> PixelRect {
        PixelRect(x: x, y: y, width: w, height: h)
    }

    @Test func isBuilt() {
        #expect(crop.unavailableHelp == nil)
    }

    @Test func squareOnNoCropIsTheLargestCenteredSquare() {
        #expect(crop.applying(.ratio(1, 1), to: nil, canvas: canvas) == rect(100, 0, 600, 600))
        #expect(crop.applying(.free, to: nil, canvas: canvas) == rect(0, 0, 800, 600))
        #expect(crop.applying(.free, to: rect(5, 6, 70, 80), canvas: canvas) == rect(5, 6, 70, 80))
    }

    @Test func applyingFitsInsideTheCropAboutItsCenter() {
        #expect(crop.applying(.ratio(1, 1), to: rect(100, 100, 400, 200), canvas: canvas) == rect(200, 100, 200, 200))
        #expect(crop.applying(.ratio(16, 9), to: rect(0, 0, 160, 400), canvas: canvas) == rect(0, 155, 160, 90))
    }

    @Test func typedWidthUnderALockMovesHeight() {
        let square = rect(100, 0, 600, 600)
        #expect(crop.setting(.width, to: 400, in: square, aspect: .ratio(1, 1), canvas: canvas) == rect(100, 0, 400, 400))
        #expect(crop.setting(.height, to: 300, in: square, aspect: .ratio(1, 1), canvas: canvas) == rect(100, 0, 300, 300))
        #expect(crop.setting(.width, to: 400, in: square, aspect: .free, canvas: canvas) == rect(100, 0, 400, 600))
    }

    @Test func typedWidthPastTheBottomShrinksBothSides() {
        let wide = rect(0, 400, 100, 100)
        #expect(crop.setting(.width, to: 500, in: wide, aspect: .ratio(1, 1), canvas: canvas) == rect(0, 400, 200, 200))
        #expect(crop.setting(.width, to: 5000, in: wide, aspect: .free, canvas: canvas) == rect(0, 400, 800, 100))
    }

    @Test func typedPositionClampsWithoutResizing() {
        let box = rect(0, 0, 200, 100)
        #expect(crop.setting(.x, to: 700, in: box, aspect: .free, canvas: canvas) == rect(600, 0, 200, 100))
        #expect(crop.setting(.y, to: -40, in: box, aspect: .ratio(2, 1), canvas: canvas) == rect(0, 0, 200, 100))
        #expect(crop.setting(.y, to: 550, in: box, aspect: .free, canvas: canvas) == rect(0, 500, 200, 100))
    }

    @Test func dragFreeAndLocked() {
        let a = Mask.Point(x: 10, y: 10), b = Mask.Point(x: 210, y: 110)
        #expect(crop.dragged(from: a, to: b, aspect: .free, canvas: canvas) == rect(10, 10, 200, 100))
        #expect(crop.dragged(from: a, to: b, aspect: .ratio(1, 1), canvas: canvas) == rect(10, 10, 200, 200))
    }

    @Test func lockedDragUpAndLeftStaysAnchoredAndShrinksToFit() {
        let anchor = Mask.Point(x: 100, y: 500)
        let up = crop.dragged(from: anchor, to: Mask.Point(x: -300, y: 450), aspect: .ratio(1, 1), canvas: canvas)
        #expect(up == rect(0, 400, 100, 100))
        let clicked = crop.dragged(from: anchor, to: anchor, aspect: .ratio(1, 1), canvas: canvas)
        #expect(clicked.width >= 1 && clicked.height >= 1)
    }

    @Test func swappingTurnsTheRatio() {
        #expect(crop.swapped(.ratio(3, 2), canvas: canvas) == .ratio(2, 3))
        #expect(crop.swapped(.free, canvas: canvas) == .free)
        #expect(crop.swapped(.original, canvas: canvas) == .original)
    }

    @Test func originalIsTheCanvasRatio() {
        let base = rect(50, 50, 300, 300)
        #expect(crop.applying(.original, to: nil, canvas: canvas) == rect(0, 0, 800, 600))
        #expect(crop.applying(.original, to: base, canvas: canvas) == crop.applying(.ratio(4, 3), to: base, canvas: canvas))
        #expect(crop.applying(.original, to: base, canvas: canvas) == rect(50, 87, 300, 225))
        let a = Mask.Point(x: 10, y: 10), b = Mask.Point(x: 70, y: 400)
        #expect(crop.dragged(from: a, to: b, aspect: .original, canvas: canvas)
            == crop.dragged(from: a, to: b, aspect: .ratio(4, 3), canvas: canvas))
        #expect(crop.setting(.width, to: 400, in: base, aspect: .original, canvas: canvas) == rect(50, 50, 400, 300))
    }

    @Test func seededFuzzStaysInsideAndKeepsTheRatio() {
        var random = CropFuzzRandom(seed: 0x5EED_C0DE)
        let aspects = CropAspect.presets + CropAspect.presets.map { crop.swapped($0, canvas: canvas) }
        for step in 0..<1_000 {
            let size = CanvasSize(width: random.int(1...1_200), height: random.int(1...1_200))
            let aspect = aspects[random.int(0...(aspects.count - 1))]
            let (result, kept) = fuzzResult(step: step, random: &random, aspect: aspect, size: size)
            check(result, aspect: kept, size: size, step: step)
        }
    }

    private func fuzzResult(step: Int, random: inout CropFuzzRandom, aspect: CropAspect, size: CanvasSize)
        -> (PixelRect, CropAspect)
    {
        let w = random.int(1...size.width), h = random.int(1...size.height)
        let start = rect(random.int(0...(size.width - w)), random.int(0...(size.height - h)), w, h)
        func point() -> Mask.Point {
            Mask.Point(x: random.double(-300...Double(size.width) + 300), y: random.double(-300...Double(size.height) + 300))
        }
        switch step % 4 {
        case 0:
            let field = CropField.allCases[random.int(0...3)]
            let locked = crop.applying(aspect, to: start, canvas: size)
            return (crop.setting(field, to: random.int(-2_000...2_000), in: locked, aspect: aspect, canvas: size), aspect)
        case 1: return (crop.dragged(from: point(), to: point(), aspect: aspect, canvas: size), aspect)
        case 2: return (crop.applying(aspect, to: random.int(0...3) == 0 ? nil : start, canvas: size), aspect)
        default:
            let turned = crop.swapped(aspect, canvas: size)
            return (crop.applying(turned, to: start, canvas: size), turned)
        }
    }

    private func check(_ r: PixelRect, aspect: CropAspect, size: CanvasSize, step: Int) {
        #expect(r.width >= 1 && r.height >= 1, "step \(step): \(r) too small")
        #expect(r.x >= 0 && r.y >= 0 && r.maxX <= size.width && r.maxY <= size.height,
                "step \(step): \(r) leaves \(size.width) x \(size.height)")
        let ratio: (Double, Double)? = switch aspect {
        case .free: nil
        case .original: (Double(size.width), Double(size.height))
        case .ratio(let a, let b): (Double(a), Double(b))
        }
        guard let (rw, rh) = ratio else { return }
        let offHeight = abs(Double(r.width) * rh / rw - Double(r.height))
        let offWidth = abs(Double(r.height) * rw / rh - Double(r.width))
        #expect(min(offHeight, offWidth) <= 1, "step \(step): \(r) breaks \(aspect.title)")
    }

}

/// SplitMix64: the same 1,000 inputs on every run.
private struct CropFuzzRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound) + 1
        return range.lowerBound + Int(next() % span)
    }
    mutating func double(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(next() >> 11) / Double(1 << 53) * (range.upperBound - range.lowerBound)
    }
}
