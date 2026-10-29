// LibraryLoupeGPURouteTests.swift: suite-imaging IM-11 (model half). The
// loupe's GPU frame: the decoded base and the develop steps the view writes
// into its resident texture, LiveDevelop's pass list as ToneAdjustments that
// render what `render` renders, the View > Rendering CPU choice keeping the
// CPU route, and the histogram taken from the decoded base developed on the
// CPU, never from the undeveloped picture the GPU starts from, and taken apart
// from the frame, which develops no pixel. Vibrance, Saturation and the kinds
// stay on the GPU route: core's one-pass display program (`ToneProgram`, whose
// `map` is the kernel in Swift) draws what the CPU renders.
import Foundation
import Synchronization
import Testing
import CoreColor
import CoreRaster
import CoreRender

@testable import LibraryModel

@Suite struct LibraryLoupeGPURouteTests {
    static let shot = PhotoItem(name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 1), color: Color3(0.6, 0.4, 0.2),
                                path: "/shoot/IMG_0001.jpg", pixelSize: PixelSize(width: 400, height: 300))
    static let edit = DevelopSettings.neutral.setting(.temperature, to: 20).setting(.exposure, to: 0.7)
        .setting(.contrast, to: 30).setting(.highlights, to: -40).setting(.whites, to: 25)
        .setting(levels: DevelopLevels(inputBlack: 0.05, inputWhite: 0.9, gamma: 1.3, outputBlack: 0, outputWhite: 1))

    static func loupe() -> LiveLoupeImaging {
        LiveLoupeImaging(decoder: FakeDecoder(photos: [shot]), develop: LiveDevelop())
    }

    static func buffer(_ image: DisplayImage) throws -> PixelBuffer {
        try PixelBuffer(rgba8: image.rgba8, width: image.size.width, height: image.size.height)
    }

    @Test func stepsRenderWhatDevelopRenders() throws {
        let base = try Self.buffer(#require(FakeBehavior.gradient(for: Self.shot, longSide: 64)))
        let steps = LiveDevelop.steps(for: Self.edit)
        #expect(steps.count == LiveDevelop.passes(for: Self.edit).count)
        let cpu = CPUBackend()
        var surface = try cpu.surface(base)
        for step in steps {
            let next = try cpu.adjusted(surface, step)
            cpu.release(surface)
            surface = next
        }
        let stepped = try cpu.read(surface)
        cpu.release(surface)
        #expect(try stepped.rgba8() == LiveDevelop().render(base, settings: Self.edit).rgba8())
        #expect(LiveDevelop.steps(for: .neutral) == [])
    }

    @Test func honoursRenderingChoice() async throws {
        let loupe = Self.loupe()
        let cpu = try await loupe.gpuFrame(Self.shot, settings: Self.edit, longSide: 200, preferGPU: false)
        #expect(cpu == nil)
        let gpu = try #require(await loupe.gpuFrame(Self.shot, settings: Self.edit, longSide: 200, preferGPU: true))
        #expect(gpu.program == LiveDevelop.steps(for: Self.edit).map(ToneProgram.Operation.adjustment))
        let cropped = Self.edit.setting(crop: CropSettings(angle: 5, rect: .full, aspect: .free))
        #expect(try await loupe.gpuFrame(Self.shot, settings: cropped, longSide: 200, preferGPU: true) == nil)
    }

    @Test func gpuFrameStartsFromTheDecodedBase() async throws {
        let loupe = Self.loupe()
        let frame = try #require(await loupe.gpuFrame(Self.shot, settings: Self.edit, longSide: 200, preferGPU: true))
        let neutral = try await loupe.render(Self.shot, settings: .neutral, longSide: 200, quality: .full)
        #expect(frame.base == neutral.image)
    }

    @Test func histogramFromBase() async throws {
        let loupe = Self.loupe()
        let histogram = try await loupe.histogram(Self.shot, settings: Self.edit)
        let preview = try await loupe.render(Self.shot, settings: Self.edit, longSide: 200, quality: .preview)
        let undeveloped = try await loupe.render(Self.shot, settings: .neutral, longSide: 200, quality: .preview)
        #expect(histogram == preview.histogram)
        #expect(histogram != undeveloped.histogram)
    }

    /// Vibrance, Saturation (core's `.color` family) and Black & White / Invert keep the GPU route, the kinds included
    /// in the program, and the program draws what `render` renders within one 8-bit step.
    @Test(arguments: [
        DevelopSettings.neutral.setting(.vibrance, to: 60),
        DevelopSettings.neutral.setting(.saturation, to: -70),
        edit.setting(.vibrance, to: -40).setting(.saturation, to: 35),
        edit.setting(kinds: [.blackAndWhite(.neutral)]),
        edit.setting(.vibrance, to: 30).setting(kinds: [.invert]),
    ])
    func colorStepsStayOnTheGPU(_ settings: DevelopSettings) async throws {
        let frame = try #require(await Self.loupe().gpuFrame(Self.shot, settings: settings, longSide: 64, preferGPU: true))
        #expect(frame.program == LiveDevelop.program(for: settings))
        let base = try Self.buffer(frame.base)
        let cpu = try LiveDevelop().render(base, settings: settings).rgba8()
        let program = try ToneProgram(operations: frame.program)
        var mapped = base
        for y in 0..<base.height {
            for x in 0..<base.width { try mapped.setPixel(x: x, y: y, program.map(base.pixel(x: x, y: y))) }
        }
        let gpu = try mapped.rgba8()
        let worst = zip(gpu, cpu).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= 2, "the GPU program is off the CPU render by \(worst) of 255")
    }

    /// Quality gate #5953: a slider step on the GPU route develops no pixel on the CPU. Twenty steps of Vibrance on a
    /// cached screen-size decode call the develop renderer zero times; only the histogram, taken after, does.
    @Test func sliderStepsDevelopNothingOnTheCPU() async throws {
        let counter = CountingDevelop()
        let loupe = LiveLoupeImaging(decoder: FakeDecoder(photos: [Self.shot]), develop: counter)
        for step in 1...20 {
            let settings = Self.edit.setting(.vibrance, to: Double(step * 4))
            #expect(try await loupe.gpuFrame(Self.shot, settings: settings, longSide: 400, preferGPU: true) != nil)
        }
        #expect(counter.renders.withLock { $0 } == 0)
        _ = try await loupe.histogram(Self.shot, settings: Self.edit)
        #expect(counter.renders.withLock { $0 } == 1)
    }
}

/// LiveDevelop that counts its CPU renders.
final class CountingDevelop: DevelopRendering {
    let renders = Mutex(0)
    func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        renders.withLock { $0 += 1 }
        return try LiveDevelop().render(buffer, settings: settings)
    }
    func histogram(of buffer: PixelBuffer) throws -> HistogramBins { try LiveDevelop().histogram(of: buffer) }
}
