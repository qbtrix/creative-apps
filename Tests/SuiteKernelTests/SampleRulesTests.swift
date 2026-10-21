// SampleRulesTests.swift (eyedropper EY-1 written, EY-5 turned on): the one N × N mean every sampler uses, over a
// reader closure: the sizes, the import check over Sample/, the means and the hex.
import Foundation
import Testing
import SuiteKernel

@Suite struct SampleRulesTests {
    static let red = SampleRGBA(r: 255, g: 0, b: 0, a: 255), blue = SampleRGBA(r: 0, g: 0, b: 255, a: 255)
    static let clear = SampleRGBA(r: 0, g: 0, b: 0, a: 0)
    static func hex(_ color: FillColor?) -> String? { color.map(SampleRules.hex) }

    @Test func sizesAreTheThree() {
        #expect(SampleSize.allCases.map(\.title) == ["Point", "3 × 3", "5 × 5"])
        #expect(SampleSize.allCases.map(\.rawValue) == [1, 3, 5])
    }
    @Test func sampleImportsOnlyFoundationAndFlareCore() throws {
        let folder = KernelShapeTests.kernelSources.appendingPathComponent("Sample")
        let files = try KernelShapeTests.swiftFiles(under: folder)
        #expect(files == ["SampleCommands.swift", "SampleRules.swift"])
        let allowed: Set = ["Foundation", "FoundationEssentials", "FlareCore"]
        let imports = try Regex(#"^\s*(?:@testable\s+)?import\s+(\w+)"#)
        for file in files {
            let text = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(separator: "\n") {
                guard let match = try imports.firstMatch(in: String(line)), let name = match.output[1].substring else { continue }
                #expect(allowed.contains(String(name)), "Sample/\(file) imports \(name)")
            }
        }
    }
    @Test func pointOnRedReadsRed() {
        #expect(Self.hex(SampleRules.mean(x: 4, y: 4, size: .point) { _, _ in Self.red }) == "#FF0000")
    }
    @Test func pointReadsThePixelUnderIt() {
        let read: (Int, Int) -> SampleRGBA? = { x, y in x == 4 && y == 7 ? Self.red : Self.blue }
        #expect(Self.hex(SampleRules.mean(x: 4, y: 7, size: .point, read: read)) == "#FF0000")
        #expect(Self.hex(SampleRules.mean(x: 5, y: 7, size: .point, read: read)) == "#0000FF")
    }
    @Test func squareIsCentredOnThePoint() {
        // Red only in the 3 × 3 square around (10, 20): every size centred there reads red, one step off reads blue too.
        let read: (Int, Int) -> SampleRGBA? = { x, y in abs(x - 10) <= 1 && abs(y - 20) <= 1 ? Self.red : Self.blue }
        #expect(Self.hex(SampleRules.mean(x: 10, y: 20, size: .threeByThree, read: read)) == "#FF0000")
        #expect(Self.hex(SampleRules.mean(x: 11, y: 20, size: .threeByThree, read: read)) == "#AA0055")
    }
    @Test func squareIsTheMeanOfItsPixels() {
        // Above the centre row red, below it blue, the row itself transparent: half red, half blue.
        let mean = SampleRules.mean(x: 0, y: 0, size: .threeByThree) { _, y in y < 0 ? Self.red : y > 0 ? Self.blue : Self.clear }
        #expect(Self.hex(mean) == "#800080")
        #expect(mean?.a == 1)
    }
    @Test func meanWeightsAlpha() {
        let faint = SampleRGBA(r: 0, g: 0, b: 255, a: 85)
        let mean = SampleRules.mean(x: 0, y: 0, size: .threeByThree) { x, y in
            y != 0 ? nil : x < 0 ? Self.red : x > 0 ? faint : nil
        }
        #expect(Self.hex(mean) == "#BF0040")
        #expect(abs((mean?.a ?? 0) - 170.0 / 255) < 1e-9)
    }
    @Test func transparentPixelsAreSkipped() {
        let mean = SampleRules.mean(x: 2, y: 2, size: .fiveByFive) { x, y in x == 2 && y == 2 ? Self.red : Self.clear }
        #expect(Self.hex(mean) == "#FF0000")
    }
    @Test func squareOffTheEdgeAveragesWhatIsInside() {
        let mean = SampleRules.mean(x: 0, y: 0, size: .fiveByFive) { x, y in x < 0 || y < 0 ? nil : x == 0 ? Self.red : Self.blue }
        #expect(Self.hex(mean) == "#5500AA")
    }
    @Test func allTransparentIsNil() {
        #expect(SampleRules.mean(x: 0, y: 0, size: .threeByThree) { _, _ in Self.clear } == nil)
        #expect(SampleRules.mean(x: 0, y: 0, size: .point) { _, _ in nil } == nil)
    }
    @Test func hexRoundsEachChannel() {
        #expect(SampleRules.hex(FillColor(r: 1, g: 0.5, b: 0)) == "#FF8000")
        #expect(SampleRules.hex(FillColor(r: 0.001, g: 0.999, b: 0.2)) == "#00FF33")
        #expect(SampleRules.hex(FillColor(r: -1, g: 2, b: .nan)) == "#00FF00")
    }
}
