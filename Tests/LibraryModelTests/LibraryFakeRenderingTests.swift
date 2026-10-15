// LibraryFakeRenderingTests.swift: the loupe, develop, crop and export fakes
// show every change a journey asserts: a slider step lifts the loupe by one
// byte level, `.fail` says why, crop centers the aspect, export never
// overwrites a name.
import Foundation
import Testing
import CoreColor
import CoreRaster

@testable import LibraryModel

private let date = Date(timeIntervalSince1970: 0)

private func gray(_ name: String = "IMG_0001", width: Int = 300, height: Int = 200) -> PhotoItem {
    PhotoItem(name: name, captureDate: date, color: Color3(0.5, 0.5, 0.5),
              pixelSize: PixelSize(width: width, height: height))
}

@Test func loupeExposureStepLiftsEveryChannelByOne() async throws {
    let loupe = FakeLoupe()
    let photo = gray()
    let plain = try await loupe.render(photo, settings: .neutral, longSide: 300, quality: .full)
    let lifted = try await loupe.render(photo, settings: DevelopSettings.neutral.setting(.exposure, to: 0.01),
                                        longSide: 300, quality: .full)
    #expect(plain.image.size == lifted.image.size)
    let before = plain.image.rgba8, after = lifted.image.rgba8
    #expect(before.count == after.count)
    for i in stride(from: 0, to: min(before.count, after.count), by: 4) {
        for c in 0..<3 where Int(after[i + c]) != Int(before[i + c]) + 1 {
            Issue.record("byte \(i + c): \(before[i + c]) became \(after[i + c])")
            return
        }
        #expect(after[i + 3] == before[i + 3])
    }
    let pixels = 300 * 200
    #expect(lifted.histogram.red.reduce(0, +) == pixels)
    #expect(lifted.histogram.green.reduce(0, +) == pixels)
    #expect(lifted.histogram.blue.reduce(0, +) == pixels)
    #expect(lifted.quality == .full)
}

@Test func loupePreviewIsCappedAndFullKeepsTheLongSide() async throws {
    let photo = gray(width: 6000, height: 4000)
    let full = try await FakeLoupe().render(photo, settings: .neutral, longSide: 2048, quality: .full)
    #expect(full.image.size.longSide == 2048)
    let preview = try await FakeLoupe().render(photo, settings: .neutral, longSide: 2048, quality: .preview)
    #expect(preview.image.size.longSide == 512)
}

@Test func loupeAndExporterFailOnPurpose() async throws {
    let photo = gray()
    await #expect(throws: LibraryError.renderFailed("the preview failed on purpose")) {
        try await FakeLoupe(mode: .fail).render(photo, settings: .neutral, longSide: 300, quality: .full)
    }
    let exporter = FakeExporter(mode: .fail)
    let plan = exporter.plan([photo], options: ExportOptions(longEdge: 16, folder: "/out"), existingNames: [])
    let item = try #require(plan.items.first)
    await #expect(throws: LibraryError.renderFailed("the preview failed on purpose")) {
        try await exporter.render(item, photo: photo)
    }
    #expect(throws: LibraryError.renderFailed("the preview failed on purpose")) {
        try FakeDevelop(mode: .fail).render(PixelBuffer(rgba8: [0, 0, 0, 255], width: 1, height: 1), settings: .neutral)
    }
}

@Test func developReturnsTheBufferAndAnEmptyHistogram() throws {
    let buffer = try PixelBuffer(rgba8: [10, 20, 30, 255], width: 1, height: 1)
    let develop = FakeDevelop()
    #expect(try develop.render(buffer, settings: DevelopSettings.neutral.setting(.exposure, to: 1)) == buffer)
    #expect(try develop.histogram(of: buffer) == .empty)
}

@Test func cropCentersTheAspectAndStraightenShrinks() throws {
    let crop = FakeCrop()
    let size = PixelSize(width: 6000, height: 4000)
    let square = try crop.initial(aspect: .square, angle: 0, photo: size)
    #expect(abs(square.rect.width - 4000.0 / 6000.0) < 1e-9)
    #expect(abs(square.rect.height - 1) < 1e-9)
    #expect(abs(square.rect.x - (1 - 4000.0 / 6000.0) / 2) < 1e-9)
    let turned = try crop.straightened(square, angle: 10, photo: size)
    #expect(turned.rect.width < square.rect.width)
    #expect(turned.angle == 10)
    let frame = try crop.frame(square, photo: size)
    #expect(frame.width == 4000 && frame.height == 4000)
    let moved = try crop.dragged(square, handle: .right, dx: 6000, dy: 0, photo: size)
    #expect(moved.rect.x + moved.rect.width <= 1 + 1e-9)
}

@Test func exporterPlansFreshNamesAndFittedSizes() async throws {
    let exporter = FakeExporter()
    let photo = gray(width: 6000, height: 4000)
    let one = exporter.plan([photo], options: ExportOptions(folder: "/out"), existingNames: ["IMG_0001.jpg"])
    #expect(one.items.map(\.fileName) == ["IMG_0001 2.jpg"])
    let sample = PhotoItem(name: "IMG_1", captureDate: date, color: Color3(1, 0, 0),
                           pixelSize: PixelSize(width: 6000, height: 4000))
    let plan = exporter.plan([sample, sample], options: ExportOptions(longEdge: 2048, folder: "/out"),
                             existingNames: ["IMG_1.jpg"])
    #expect(plan.items.map(\.fileName) == ["IMG_1 2.jpg", "IMG_1 3.jpg"])
    #expect(plan.items.first?.size == PixelSize(width: 2048, height: 1365))
    let item = try #require(plan.items.first)
    let image = try await exporter.render(item, photo: sample)
    #expect(image.size == item.size)
}
