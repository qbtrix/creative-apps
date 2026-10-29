// LibraryLoupeGPURouteTests.swift: suite-imaging IM-11 (model half). The
// loupe's GPU frame: the decoded base and the develop steps the view writes
// into its resident texture, LiveDevelop's pass list as ToneAdjustments that
// render what `render` renders, the View > Rendering CPU choice keeping the
// CPU route, and the histogram taken from the decoded base developed on the
// CPU, never from the undeveloped picture the GPU starts from. A step core's
// Metal backend doesn't run yet (Saturation) keeps the CPU route.
import Foundation
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
        #expect(gpu.steps == LiveDevelop.steps(for: Self.edit))
        let cropped = Self.edit.setting(crop: CropSettings(angle: 5, rect: .full, aspect: .free))
        #expect(try await loupe.gpuFrame(Self.shot, settings: cropped, longSide: 200, preferGPU: true) == nil)
        // Saturation is core's `.color` family, not on Metal yet (`RenderOp.notOnMetalYet`): the CPU route.
        let saturated = Self.edit.setting(.saturation, to: -50)
        #expect(try await loupe.gpuFrame(Self.shot, settings: saturated, longSide: 200, preferGPU: true) == nil)
    }

    @Test func gpuFrameStartsFromTheDecodedBase() async throws {
        let loupe = Self.loupe()
        let frame = try #require(await loupe.gpuFrame(Self.shot, settings: Self.edit, longSide: 200, preferGPU: true))
        let neutral = try await loupe.render(Self.shot, settings: .neutral, longSide: 200, quality: .full)
        #expect(frame.base == neutral.image)
    }

    @Test func histogramFromBase() async throws {
        let loupe = Self.loupe()
        let frame = try #require(await loupe.gpuFrame(Self.shot, settings: Self.edit, longSide: 200, preferGPU: true))
        let preview = try await loupe.render(Self.shot, settings: Self.edit, longSide: 200, quality: .preview)
        let undeveloped = try await loupe.render(Self.shot, settings: .neutral, longSide: 200, quality: .preview)
        #expect(frame.histogram == preview.histogram)
        #expect(frame.histogram != undeveloped.histogram)
    }

    /// Vibrance (DV-12) renders: core's `.color` family, so the CPU route, never a waiting error.
    @Test func vibranceTakesTheCPURoute() async throws {
        let vibrant = Self.edit.setting(.vibrance, to: 10)
        #expect(LiveDevelop.steps(for: vibrant).contains(.vibrance(10)))
        #expect(try await Self.loupe().gpuFrame(Self.shot, settings: vibrant, longSide: 200, preferGPU: true) == nil)
    }
}
