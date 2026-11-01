// LibraryLoupeFrameTests.swift: suite-imaging IM-11 (catalog half). A GPU
// frame lands under the loupe's token rules as the full picture with its
// develop program, which the loupe's view writes over the base; a CPU render or
// a focus change takes the picture back to plain pixels (no program). A frame
// keeps the shown histogram until its own lands after it: newer than the last,
// never one from before a focus change. A loupe with no GPU route (the fake)
// hands back no frame. Runs on Linux and macOS.
@testable import LibraryModel
import CoreRender
import Testing

@Suite struct LibraryLoupeFrameTests {
    static let steps: [ToneProgram.Operation] = [.adjustment(.exposure(stops: 0.5)), .adjustment(.contrast(20))]

    static func pixels(_ value: UInt8) -> DisplayImage? {
        DisplayImage(size: PixelSize(width: 2, height: 2), rgba8: Array(repeating: value, count: 16))
    }

    static func frame(_ value: UInt8) throws -> LoupeGPUFrame {
        try LoupeGPUFrame(base: #require(pixels(value)), program: steps)
    }

    static func request(_ catalog: inout LibraryCatalog) -> LoupeRequest? {
        catalog.loupeRequest(longSide: 1024, quality: .full)
    }

    static func loupe() -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        catalog.open(catalog.order[1])
        return catalog
    }

    @Test func frameLandsAsTheFullPictureWithItsSteps() throws {
        var catalog = Self.loupe()
        let request = try #require(Self.request(&catalog))
        catalog.showLoupeFrame(try Self.frame(9), token: request.token)
        #expect(catalog.loupeSteps == Self.steps)
        #expect(catalog.loupeRender?.image == Self.pixels(9))
        #expect(catalog.loupeRender?.quality == .full)
        #expect(catalog.loupeShownToken == request.token)
    }

    /// Journeys read the loupe's checksum to see a develop step land; on the GPU route the base never changes,
    /// so the checksum has to follow the frame's program too, and stay put for the same program.
    @Test func checksumFollowsTheFramesSteps() throws {
        var catalog = Self.loupe()
        catalog.showsTestValues = true
        func checksum(_ program: [ToneProgram.Operation]) throws -> String? {
            let request = try #require(Self.request(&catalog))
            catalog.showLoupeFrame(try LoupeGPUFrame(base: #require(Self.pixels(9)), program: program), token: request.token)
            return catalog.loupeValue?.split(separator: " ").map(String.init).first { $0.count == 16 }
        }
        let plain = try checksum([])
        let stepped = try checksum(Self.steps)
        // An empty program draws the base itself, so it reads the base's checksum, as the CPU route shows it:
        // the live journey's Show Original lands on the GPU route after a CPU-route first render.
        #expect(plain == (try #require(Self.pixels(9))).checksum)
        #expect(stepped != plain)
        #expect(try checksum([.adjustment(.exposure(stops: 0.6)), .adjustment(.contrast(20))]) != stepped)
        #expect(try checksum(Self.steps) == stepped)
    }

    @Test func staleFrameNeverLands() throws {
        var catalog = Self.loupe()
        let old = try #require(Self.request(&catalog))
        let new = try #require(Self.request(&catalog))
        catalog.showLoupeFrame(try Self.frame(3), token: new.token)
        catalog.showLoupeFrame(try Self.frame(4), token: old.token)
        #expect(catalog.loupeRender?.image == Self.pixels(3))
        catalog.loupeFocusChanged()
        catalog.showLoupeFrame(try Self.frame(5), token: new.token)
        #expect(catalog.loupeSteps == nil)
    }

    @Test func cpuRenderTakesThePictureBack() throws {
        var catalog = Self.loupe()
        let first = try #require(Self.request(&catalog))
        catalog.showLoupeFrame(try Self.frame(9), token: first.token)
        let next = try #require(Self.request(&catalog))
        let cpu = try RenderedPhoto(image: #require(Self.pixels(6)), histogram: .empty, quality: .full)
        catalog.showLoupeRender(cpu, token: next.token)
        #expect(catalog.loupeSteps == nil)
        #expect(catalog.loupeRender == cpu)
    }

    @Test func focusChangeDropsTheSteps() throws {
        var catalog = Self.loupe()
        let request = try #require(Self.request(&catalog))
        catalog.showLoupeFrame(try Self.frame(9), token: request.token)
        catalog.loupeFocusChanged()
        #expect(catalog.loupeSteps == nil)
    }

    static func bins(_ shadow: Int) -> HistogramBins {
        HistogramBins(red: [], green: [], blue: [], shadowClipped: shadow, highlightClipped: 0)
    }

    @Test func histogramLandsAfterItsFrame() throws {
        var catalog = Self.loupe()
        let first = try #require(Self.request(&catalog))
        catalog.showLoupeFrame(try Self.frame(9), token: first.token)
        catalog.showLoupeHistogram(Self.bins(1), token: first.token)
        #expect(catalog.loupeRender?.histogram == Self.bins(1))
        // The next frame keeps it until its own lands; a drag's older histogram still lands, an even older one doesn't.
        let second = try #require(Self.request(&catalog)), third = try #require(Self.request(&catalog))
        catalog.showLoupeFrame(try Self.frame(8), token: third.token)
        #expect(catalog.loupeRender?.histogram == Self.bins(1))
        catalog.showLoupeHistogram(Self.bins(2), token: second.token)
        #expect(catalog.loupeRender?.histogram == Self.bins(2))
        catalog.showLoupeHistogram(Self.bins(3), token: first.token)
        #expect(catalog.loupeRender?.histogram == Self.bins(2))
        catalog.loupeFocusChanged()
        let next = try #require(Self.request(&catalog))
        catalog.showLoupeFrame(try Self.frame(7), token: next.token)
        catalog.showLoupeHistogram(Self.bins(4), token: third.token)
        #expect(catalog.loupeRender?.histogram != Self.bins(4))
    }

    @Test func fakeLoupeHasNoGPUFrame() async throws {
        let catalog = Self.loupe()
        let photo = try #require(catalog.loupeItem)
        let frame = try await FakeLoupe().gpuFrame(photo, settings: .neutral, longSide: 256, preferGPU: true)
        #expect(frame == nil)
    }
}
