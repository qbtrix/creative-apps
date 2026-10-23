// PhotoBrushKernelTests.swift: Photo's brush sampled through SuiteKernel's
// stroke model (adopt-kernel-brush AB-p1, PhotoBrush+Kernel.swift): the
// smoother's window paints the first segment when the third sample arrives
// and the last one on the release, each with its own end pressures; the clone
// stamp's dabs follow the settings' spacing; the tool options keep Photo's
// ranges on the kernel's settings and take presets. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Synchronization
import Testing

@Suite struct PhotoBrushKernelTests {
    private func sample(_ x: Double, _ y: Double, _ pressure: Double = 1) -> StrokeSample {
        StrokeSample(point: Point(x: x, y: y), pressure: pressure)
    }

    @Test func theFirstSegmentComesWithTheThirdSample() throws {
        let window = [sample(8, 32), sample(24, 32), sample(40, 40)]
        #expect(PhotoStroke.smoothed(Array(window.prefix(2)), ending: false) == nil)
        let piece = try #require(PhotoStroke.smoothed(window, ending: false))
        #expect(piece.points.first == point(8, 32) && piece.points.last == point(24, 32))

        var workspace = try whiteImage()
        workspace.setToolOption(.size(4))
        workspace.selectTool(.brush)
        workspace.drag(from: point(8, 32), to: point(24, 32))
        workspace.drag(from: point(24, 32), to: point(40, 40))
        // Mid-drag, before the release: the press's dab and the segment after it.
        #expect(try layerPixel(workspace, 16, 32)?.r == 0)
    }

    @Test func theReleasePaintsTheLastSegment() throws {
        let piece = try #require(PhotoStroke.smoothed([sample(8, 8), sample(40, 8)], ending: true))
        #expect(piece.points.first == point(8, 8) && piece.points.last == point(40, 8))

        var workspace = try whiteImage()
        workspace.setToolOption(.size(4))
        stroke(&workspace, .brush, from: point(8, 8), to: point(40, 8))
        #expect(try layerPixel(workspace, 30, 8)?.r == 0)
    }

    @Test func eachPieceKeepsItsOwnEndPressures() throws {
        let window = [sample(0, 0, 0.2), sample(10, 0, 0.9), sample(20, 5, 0.5), sample(30, 5, 0.3)]
        let running = try #require(PhotoStroke.smoothed(window, ending: false))
        #expect(running.from == 0.9 && running.to == 0.5)
        #expect(running.points.first == point(10, 0) && running.points.last == point(20, 5))
        let ending = try #require(PhotoStroke.smoothed(window, ending: true))
        #expect(ending.from == 0.5 && ending.to == 0.3)
    }

    @Test func dabsFillEachPairEvenlyAndEndOnIt() {
        let centers = PhotoWorkspace.dabCenters([point(0, 0), point(10, 0), point(10, 1)], spacing: 4)
        #expect(centers.count == 5)
        #expect(centers.last == point(10, 1) && centers[3] == point(10, 0))
        #expect(abs(centers[1].x - 10.0 / 3) < 1e-9 && abs(centers[2].x - 20.0 / 3) < 1e-9)
    }

    /// Counts the coverage lookups a clone stroke makes: one per pixel of each dab's box.
    private final class Lookups: Sendable {
        private let count = Mutex(0)
        var value: Int { count.withLock { $0 } }
        func add() { count.withLock { $0 += 1 } }
    }

    private func cloneLookups(spacing: Double) throws -> Int {
        var workspace = try whiteImage(128, 64)
        workspace.selectTool(.clone)
        let brush = BrushSettings(size: 16, spacing: spacing)
        workspace.setToolOption(.preset(BrushPreset(id: "test", name: "Test", settings: brush)))
        workspace.setCloneSource(at: point(8, 8))
        let lookups = Lookups()
        PhotoWorkspace.$forcedCoverage.withValue({ _, _ in lookups.add(); return 1 }) {
            workspace.drag(from: point(20, 32), to: point(20, 32))
            workspace.drag(from: point(20, 32), to: point(84, 32))
            workspace.endDrag()
        }
        return lookups.value
    }

    @Test func cloneDabsFollowTheSettingsSpacing() throws {
        // The press lays two dabs on its point; the 64 px move with a 16 px brush lays 16 dabs
        // a quarter of the size apart, or 4 a whole size apart: 18 boxes against 6.
        let quarter = try cloneLookups(spacing: 25), whole = try cloneLookups(spacing: 100)
        #expect(whole > 0 && quarter == whole * 3, "quarter \(quarter), whole \(whole)")
    }

    @Test func optionsKeepPhotosRangesOnTheKernelSettings() {
        var options = ToolOptions()
        #expect(options.settings == BrushSettings())
        options.apply(.opacity(percent: 0))
        #expect(options.opacityPercent == 1)
        options.apply(.opacity(percent: .nan))
        options.apply(.size(.nan))
        #expect(options.opacityPercent == 1 && options.size == 20)
        options.apply(.size(900))
        options.apply(.hardness(percent: -5))
        #expect(options.size == 500 && options.hardnessPercent == 0)
    }

    @Test func aPresetSetsEverySettingAndKeepsTheColor() throws {
        #expect(Set(ToolOptions.presets.map(\.id)).count == ToolOptions.presets.count)
        var workspace = try whiteImage()
        workspace.setToolOption(.color(red: 200, green: 10, blue: 10))
        let preset = try #require(ToolOptions.presets.first { $0.id == "airbrush" })
        workspace.setToolOption(.preset(preset))
        #expect(workspace.brushOptions.settings == preset.settings)
        #expect(workspace.brushOptions.red == 200)
        let faint = BrushPreset(id: "faint", name: "Faint", settings: BrushSettings(opacity: 0))
        workspace.selectTool(.eraser)
        workspace.setToolOption(.preset(faint))
        #expect(workspace.eraserOptions.opacityPercent == 1 && workspace.brushOptions.settings == preset.settings)
    }

    @Test func thePresetMenuNamesTheMatchingPresetAndNoneOnceASettingDiffers() throws {
        var options = ToolOptions()
        #expect(options.preset?.id == "hard-round", "the default settings are Hard Round")
        options.apply(.hardness(percent: 0))
        #expect(options.preset == nil, "a soft 20 px brush is no preset")
        let soft = try #require(ToolOptions.presets.first { $0.id == "soft-round" })
        options.apply(.preset(soft))
        #expect(options.preset == soft)
        options.apply(.color(red: 9, green: 9, blue: 9))
        #expect(options.preset == soft, "the color is not part of a preset")
    }
}
