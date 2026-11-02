// ImagingGPUTargetTests.swift: where a resident render writes (suite-imaging
// IM-8, slice IM-photo). `backend(_:)` finds the GPU backend behind a route's
// backend and none behind the CPU's; a `Target` write puts a surface into its
// texture as `display` does, through the tone program when one is given; and
// nothing public in ImagingGPU+Target.swift names MetalBackend. macOS only
// (Metal): on Linux this file compiles to nothing. The fixture is
// LiveToneSurfaceTests'.
#if canImport(Metal)
import CoreRaster
import CoreRender
import Metal
import Testing
import SuiteImaging

@Suite(.enabled(if: LiveToneFixture.device != nil, "needs a Metal device"))
struct ImagingGPUTargetTests {
    typealias F = LiveToneFixture

    @Test func backendBehindARoute() async throws {
        let gpu = try await ImagingGPUTests.ready()
        #expect(ImagingGPU.backend(CPUBackend()) == nil, "the CPU has no GPU backend")
        let found = try #require(ImagingGPU.backend(gpu.renderBackend), "the route's GPU backend")
        #expect(found.device.registryID == gpu.device.registryID)
    }

    @Test func targetWritesThePicture() async throws {
        let gpu = try await ImagingGPUTests.ready()
        let base = try F.picture()
        let surface = try gpu.renderBackend.surface(base)
        defer { gpu.renderBackend.release(surface) }
        let texture = try F.target(gpu.device)
        let target = ImagingGPU.Target(texture, on: gpu)
        #expect(target.id == ImagingGPU.Target(texture, on: gpu).id, "the same texture")
        #expect(target.id != ImagingGPU.Target(try F.target(gpu.device), on: gpu).id, "another texture")
        try target.write(surface, x: 0, y: 0)
        #expect(F.drift(F.bytes(texture), try F.cpu(base, steps: [])) <= 2, "the picture as it is")
    }

    @Test func targetRunsTheTone() async throws {
        let gpu = try await ImagingGPUTests.ready()
        let base = try F.picture()
        let surface = try gpu.renderBackend.surface(base)
        defer { gpu.renderBackend.release(surface) }
        let texture = try F.target(gpu.device)
        let tone = try ToneProgram(operations: ImagingProgram.program(F.settings))
        try ImagingGPU.Target(texture, on: gpu).write(surface, x: 0, y: 0, tone: tone)
        let expected = try F.cpu(base, steps: ImagingProgram.adjustments(F.settings))
        #expect(F.drift(F.bytes(texture), expected) <= 2, "the write drifts from the program on the CPU")
        #expect(F.drift(F.bytes(texture), try F.cpu(base, steps: [])) > 2, "the tone changes the picture")
    }

    @Test func nothingPublicNamesMetalBackend() throws {
        let text = try ImagingBoundaryTests.read("Sources/SuiteImaging/Route/ImagingGPU+Target.swift")
        let exposed = text.split(separator: "\n").map(ImagingBoundary.code).filter { $0.contains("public ") }
        #expect(exposed.count >= 4)
        for line in exposed {
            #expect(!line.contains("MetalBackend") && !line.contains("CoreRenderMetal"), "\(line)")
        }
    }
}
#endif
