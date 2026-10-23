// ImagingGPUTests.swift: the GPU entry points (suite-imaging IM-16, slice
// IM-gpu). `systemBackend()` gives a backend where Metal exists; `display`
// writes a resident surface into a texture with the tone program and the
// display step in one write, equal to the CPU running the program's
// adjustments and then the display step's list within 2 levels; nothing
// public in ImagingGPU.swift names MetalBackend. macOS only (Metal): on Linux
// this file compiles to nothing. The fixture is LiveToneSurfaceTests'.
#if canImport(Metal)
import CoreColor
import CoreRaster
import CoreRender
import Foundation
import Metal
import Testing
import SuiteImaging

@Suite(.enabled(if: LiveToneFixture.device != nil, "needs a Metal device"))
struct ImagingGPUTests {
    typealias F = LiveToneFixture

    /// The system backend once its display pipelines compiled (at most 30 s).
    static func ready() async throws -> ImagingGPU.Backend {
        let backend = try #require(ImagingGPU.systemBackend())
        for _ in 0..<300 where !backend.isReady { try await Task.sleep(for: .milliseconds(100)) }
        try #require(backend.isReady, "the display pipelines never compiled")
        return backend
    }

    @Test func systemBackendWhereMetalExists() async throws {
        let backend = try await Self.ready()
        #expect(backend.isHealthy)
        #expect(backend.device.registryID == F.device?.registryID, "the system device")
        #expect(backend.renderBackend.isHealthy)
    }

    @Test func programInWrite() async throws {
        let backend = try await Self.ready()
        let base = try F.picture()
        let surface = try backend.upload(base)
        let target = try F.target(backend.device)
        try ImagingGPU.display(surface, into: target, program: ImagingProgram.program(F.settings),
                               displaySteps: ImagingColor.displaySteps(to: .sRGB))
        #expect(surface.writes == 1, "one pass")
        let expected = try F.cpu(base, steps: ImagingProgram.adjustments(F.settings))
        #expect(F.drift(F.bytes(target), expected) <= 2, "the write drifts from the program on the CPU")
        #expect(F.drift(F.bytes(target), try F.cpu(base, steps: [])) > 2, "the program changes the picture")
    }

    @Test func displayStepsLast() async throws {
        let backend = try await Self.ready()
        let base = try F.picture()
        let surface = try backend.upload(base)
        let target = try F.target(backend.device)
        let steps = ImagingColor.displaySteps(to: .displayP3)
        let program = ImagingProgram.program(F.settings)
        try ImagingGPU.display(surface, into: target, program: program, displaySteps: steps)
        #expect(surface.writes == 1, "program and display step are one pass")
        let adjustments = ImagingProgram.adjustments(F.settings)
        #expect(F.drift(F.bytes(target), try F.cpu(base, steps: adjustments + steps.cpu)) <= 2,
                "the write drifts from the CPU picture plus the display step")
        #expect(F.drift(F.bytes(target), try F.cpu(base, steps: adjustments)) > 2, "the P3 step changes the picture")
    }

    @Test func liveSurfaceTakesTheDisplayStep() throws {
        let device = try #require(F.device)
        let base = try F.picture()
        let live = try LiveToneSurface(device: device, base: base, tileSize: F.tile)
        let target = try F.target(device)
        let steps = ImagingColor.displaySteps(to: .displayP3)
        try ImagingGPU.display(live, into: target, program: ImagingProgram.program(F.settings), displaySteps: steps,
                               region: F.whole)
        #expect(live.writes == 4 && live.uploads == 4, "one write per tile, nothing uploaded again")
        let expected = try F.cpu(base, steps: ImagingProgram.adjustments(F.settings) + steps.cpu)
        #expect(F.drift(F.bytes(target), expected) <= 2)
    }

    @Test func nothingPublicNamesMetalBackend() throws {
        let text = try ImagingBoundaryTests.read("Sources/SuiteImaging/Route/ImagingGPU.swift")
        let exposed = text.split(separator: "\n").map(ImagingBoundary.code).filter { $0.contains("public ") }
        #expect(!exposed.isEmpty)
        for line in exposed {
            #expect(!line.contains("MetalBackend") && !line.contains("CoreRenderMetal"), "\(line)")
        }
    }
}
#endif
