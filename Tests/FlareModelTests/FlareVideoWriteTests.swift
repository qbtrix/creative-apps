// FlareVideoWriteTests.swift: export-pack FV-4 (docs/blueprints/flare/features/export-pack.md), on FakeMedia through
// FakeVideoMedia's sink log. Every planned frame is drawn from the plan's scene at its scene frame, rasterized at the
// plan's size and appended to the one sink `services.media` opened, in order, then `finish` once; Cancel forwards
// `cancel` (the writer deletes the partial file) and no file comes back.
import FlareCore
@testable import FlareModel
import Foundation
import SuiteKernel
import SuiteModel
import Synchronization
import Testing

/// `Bounce.flare` as the journey opens it (2 s at 30 fps), the sheet on `format` at long edge 8.
private func bounce(_ format: ExportFormat) -> FlareWorkspace {
    var document = FlareFixtures.bounce
    document.scenes[0].fps = 30; document.scenes[0].durationFrames = 60
    var w = FlareWorkspace(services: .fake()); w.load(document)
    _ = w.openExport(); w.setExportFormat(format); w.setExportSize(.longEdge(8))
    return w
}

/// Numbers each frame it draws (its first byte) and keeps the lists and backgrounds it was asked for, in order.
private final class NumberedRasterizer: FrameRasterizing {
    let log = Mutex<(lists: [StageDrawList], transparent: [Bool], frames: [MediaFrame])>(([], [], []))

    func png(_: StageDrawList, scale _: Double, transparent _: Bool) throws -> Data { FakeRasterizer.png }

    func frame(_ list: StageDrawList, width: Int, height: Int, transparent: Bool) throws -> MediaFrame {
        try log.withLock {
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            bytes[0] = UInt8($0.frames.count % 256)
            let frame = try MediaFrame(width: width, height: height, rgba: bytes)
            $0.lists.append(list); $0.transparent.append(transparent); $0.frames.append(frame)
            return frame
        }
    }
}

struct FlareVideoWriteTests {
    @Test(.tags(.finishLast), arguments: [ExportFormat.mp4, .gif])
    func framesReachTheSinkInOrderThenFinishOnce(format: ExportFormat) async throws {
        let w = bounce(format)
        let plan = try w.exportVideoPlan(), document = try #require(w.document), scene = try #require(w.selectedScene)
        let media = FakeVideoMedia(), raster = NumberedRasterizer(), path = "Exports/Bounce.\(format.rawValue)"
        let fractions = Mutex<[Double]>([])
        let written = try await FakeExport(frameDelay: .zero).writeVideo(
            document, sceneID: scene.id, plan: plan, to: path, media: media, rasterizer: raster
        ) { f in fractions.withLock { $0.append(f) } }
        #expect(written == path)
        let (lists, transparent, frames) = raster.log.withLock { ($0.lists, $0.transparent, $0.frames) }
        #expect(frames.count == 60 && frames.allSatisfy { $0.width == plan.width && $0.height == plan.height })
        #expect(media.events == [.open(path)] + frames.map(FakeSinkEvent.append) + [.finish])
        #expect(media.media.movies[path] == frames && media.media.cancelled.isEmpty)
        var drawn = ExportScan.withoutText(document)
        drawn.scenes[0] = plan.scene(drawn.scenes[0])
        let expected = plan.frames.map { FakeStage().drawList(drawn, sceneID: scene.id, frame: Int($0.sceneFrame), editing: nil) }
        #expect(lists == expected)
        #expect(lists.allSatisfy { $0.background.a == (format == .gif ? 0 : 1) })
        #expect(Set(transparent) == [format == .gif])
        #expect(fractions.withLock { $0 }.last == 1)
        if format == .mp4 { #expect(media.media.settings[path] == plan.movie) }
    }

    @Test(.tags(.cancelDeletes), arguments: [ExportFormat.mp4, .gif])
    func cancelForwardsCancelAndReportsNoFile(format: ExportFormat) async throws {
        let w = bounce(format)
        let plan = try w.exportVideoPlan(), document = try #require(w.document), sceneID = try #require(w.selectedScene).id
        let media = FakeVideoMedia(), path = "Exports/Bounce.\(format.rawValue)"
        let run = Task {
            try await LiveExportAdapter(stage: FakeStage()).writeVideo(
                document, sceneID: sceneID, plan: plan, to: path, media: media, rasterizer: FakeRasterizer()
            ) { f in if f >= 3.0 / 60 { withUnsafeCurrentTask { $0?.cancel() } } }
        }
        let result = await run.result
        #expect(throws: CancellationError.self) { try result.get() }
        let events = media.events
        #expect(events.first == .open(path) && events.last == .cancel)
        #expect(events.filter { $0 == .cancel }.count == 1 && !events.contains(.finish))
        #expect(events.count == 1 + 3 + 1, "three frames in, then the cancel")
        #expect(media.media.movies[path] == nil && media.media.cancelled == [path])
    }

    @Test(.tags(.cancelDeletes)) func aRefusedFrameCancelsTheFile() async throws {
        let w = bounce(.gif)
        let plan = try w.exportVideoPlan(), document = try #require(w.document), sceneID = try #require(w.selectedScene).id
        struct Wrong: FrameRasterizing {
            func png(_: StageDrawList, scale _: Double, transparent _: Bool) throws -> Data { FakeRasterizer.png }
            func frame(_: StageDrawList, width: Int, height: Int, transparent _: Bool) throws -> MediaFrame {
                try MediaFrame(width: width + 1, height: height, rgba: Array(repeating: 0, count: (width + 1) * height * 4))
            }
        }
        let media = FakeVideoMedia()
        await #expect(throws: SuiteError.self) {
            try await LiveExportAdapter(stage: FakeStage()).writeVideo(
                document, sceneID: sceneID, plan: plan, to: "Bounce.gif", media: media, rasterizer: Wrong()) { _ in }
        }
        #expect(media.events == [.open("Bounce.gif"), .cancel] && media.media.cancelled == ["Bounce.gif"])
    }

    @Test func theFakeRasterizerDrawsAFrameAtThePlansSize() throws {
        let list = StageDrawList(width: 10, height: 10, background: .white, items: [])
        let clear = try FakeRasterizer().frame(list, width: 6, height: 4, transparent: true)
        let opaque = try FakeRasterizer().frame(list, width: 6, height: 4, transparent: false)
        #expect(clear.width == 6 && clear.height == 4 && clear.rgba[3] == 0 && opaque.rgba[3] == 255)
        #expect(opaque.rgba == Array(repeating: 255, count: 6 * 4 * 4))
        #expect(clear.rgba == Array([[UInt8]](repeating: [255, 255, 255, 0], count: 24).joined()))
    }

    @Test(arguments: [(1, 1, true), (3, 5, false), (3, 5, true), (550, 400, false)])
    func theFakeRasterizersFrameIsThePixelAtEverySpot(width: Int, height: Int, transparent: Bool) throws {
        let list = StageDrawList(width: 10, height: 10, background: FlareColor(r: 0.2, g: 0.4, b: 0.6), items: [])
        let frame = try FakeRasterizer().frame(list, width: width, height: height, transparent: transparent)
        let pixel: [UInt8] = [51, 102, 153, transparent ? 0 : 255]
        #expect(frame.rgba.count == width * height * 4)
        #expect(stride(from: 0, to: frame.rgba.count, by: 4).allSatisfy { Array(frame.rgba[$0..<$0 + 4]) == pixel })
    }

    @Test func anUnavailableFakeExportWritesNothing() async throws {
        let w = bounce(.mp4)
        let plan = try w.exportVideoPlan(), document = try #require(w.document), media = FakeVideoMedia()
        await #expect(throws: NotBuilt(reason: "Off.")) {
            try await FakeExport(unavailable: "Off.").writeVideo(
                document, sceneID: "scene-1", plan: plan, to: "x.mp4", media: media, rasterizer: FakeRasterizer()) { _ in }
        }
        #expect(media.events.isEmpty)
    }
}

extension Tag {
    @Tag static var cancelDeletes: Self
    @Tag static var finishLast: Self
}
