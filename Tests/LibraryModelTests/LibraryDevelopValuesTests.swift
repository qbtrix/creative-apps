// LibraryDevelopValuesTests.swift: develop DV-1. The new sliders and their
// groups, ToneCurve, DevelopLevels, the back-compatible coding and the
// fingerprint; MJ1, the old-catalog-and-new-fields walk, whose token and
// fake checks DV-2 enabled with the token over `fingerprint` and the fake
// loupe's curve and levels lifts. Runs on Linux and macOS.
import CoreColor
import Foundation
@testable import LibraryModel
import Testing

private func point(_ x: Double, _ y: Double) -> DevelopCurvePoint { DevelopCurvePoint(x: x, y: y) }

private func sortedJSON(_ settings: DevelopSettings) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return String(decoding: try encoder.encode(settings), as: UTF8.self)
}

/// One photo with every MJ1 edit: Whites 20, Saturation -10, a three-point curve, Midtones 1.2.
private func developed(_ photo: PhotoItem) throws -> PhotoItem {
    var photo = photo
    let curve = try #require(ToneCurve(points: [point(0, 0), point(0.5, 0.6), point(1, 1)]))
    photo.develop = photo.develop.setting(.whites, to: 20).setting(.saturation, to: -10)
        .setting(curve: curve).setting(levels: DevelopLevels.neutral.setting(.gamma, to: 1.2))
    return photo
}

struct LibraryDevelopValuesTests {
    @Test func newSlidersClampAndSitInTheirGroups() {
        #expect(DevelopSettings.neutral.setting(.whites, to: 900).value(.whites) == 100)
        #expect(DevelopSettings.neutral.setting(.whites, to: .nan).value(.whites) == 0)
        #expect(DevelopSettings.neutral.setting(.blacks, to: -900).value(.blacks) == -100)
        #expect(DevelopSettings.neutral.setting(.vibrance, to: 40).value(.vibrance) == 40)
        #expect(DevelopSettings.neutral.setting(.saturation, to: -.infinity).value(.saturation) == 0)
        #expect(DevelopGroup.tone.sliders == [.exposure, .contrast, .highlights, .shadows, .whites, .blacks])
        #expect(DevelopGroup.color.sliders == [.temperature, .tint, .vibrance, .saturation])
        #expect(!DevelopSettings.neutral.setting(.vibrance, to: 1).isAdjustmentNeutral)
    }

    @Test func curveSortsClampsAndPinsItsEnds() throws {
        let curve = try #require(ToneCurve(points: [point(0.9, 1.4), point(0.5, 0.6), point(0.1, -0.2)]))
        #expect(curve.points == [point(0, 0), point(0.5, 0.6), point(1, 1)])
        #expect(ToneCurve(points: [point(0.4, 0.4)]) == nil)
        #expect(ToneCurve(points: [point(0.4, 0.4), point(.nan, 0.5)]) == nil)
        #expect(ToneCurve.identity.isIdentity && !curve.isIdentity)
    }

    @Test func curveDropsCrowdedPointsAndKeepsSixteen() throws {
        let crowded = try #require(ToneCurve(points: [point(0, 0), point(0.5, 0.5), point(0.505, 0.9), point(1, 1)]))
        #expect(crowded.points == [point(0, 0), point(0.5, 0.5), point(1, 1)])
        // Exactly minGap from its neighbour is kept.
        let spaced = try #require(ToneCurve(points: [point(0, 0), point(0.01, 0.2), point(1, 1)]))
        #expect(spaced.points.count == 3)
        let twenty = (0..<20).map { point(Double($0) / 19, Double($0) / 19) }
        let kept = try #require(ToneCurve(points: twenty))
        #expect(kept.points.count == ToneCurve.maxPoints)
        #expect(kept.points.first?.x == 0 && kept.points.last?.x == 1)
    }

    @Test func curveSamples() throws {
        let diagonal = ToneCurve.identity.samples(count: 5)
        #expect(diagonal.map(\.x) == [0, 0.25, 0.5, 0.75, 1])
        #expect(diagonal.allSatisfy { abs($0.y - $0.x) < 1e-6 })
        let lifted = try #require(ToneCurve(points: [point(0, 0), point(0.5, 0.7), point(1, 1)])).samples(count: 5)
        #expect(lifted.count == 5)
        #expect((lifted.first { $0.x == 0.5 }?.y ?? 0) > 0.6)
        #expect(ToneCurve.identity.samples(count: 1).isEmpty)
    }

    @Test func levelsClampAndKeepThePointsApart() {
        let levels = DevelopLevels.neutral
        #expect(levels.setting(.inBlack, to: 0.999).inBlack == 1 - 1.0 / 255)
        #expect(levels.setting(.inWhite, to: -1).inWhite == 1.0 / 255)
        #expect(levels.setting(.inBlack, to: 0.5).setting(.inWhite, to: 0.2).inWhite == 0.5 + 1.0 / 255)
        #expect(levels.setting(.gamma, to: 50).gamma == 9.99)
        #expect(levels.setting(.gamma, to: .nan).gamma == 1)
        #expect(levels.setting(.outWhite, to: 2).value(.outWhite) == 1)
        #expect(levels.setting(.outBlack, to: 0.25).value(.outBlack) == 0.25)
    }

    @Test func oldSettingsEncodeExactlyTheSixOldKeys() throws {
        let old = #"{"contrast":0,"exposure":1,"highlights":0,"shadows":0,"temperature":0,"tint":0}"#
        #expect(try sortedJSON(DevelopSettings.neutral.setting(.exposure, to: 1)) == old)
        let decoded = try JSONDecoder().decode(DevelopSettings.self, from: Data(old.utf8))
        #expect(decoded == DevelopSettings.neutral.setting(.exposure, to: 1))
        #expect(decoded.whites == 0 && decoded.blacks == 0 && decoded.vibrance == 0 && decoded.saturation == 0)
        #expect(decoded.curve == .identity && decoded.levels == .neutral)
    }

    @Test func everyFieldRoundTrips() throws {
        let curve = try #require(ToneCurve(points: [point(0, 0.1), point(0.3, 0.2), point(1, 0.9)]))
        var levels = DevelopLevels.neutral
        for field in DevelopLevels.Field.allCases { levels = levels.setting(field, to: 0.4) }
        var all = DevelopSettings.neutral.setting(curve: curve).setting(levels: levels)
            .setting(crop: CropSettings(angle: 2, rect: .full, aspect: .free))
        for (i, slider) in DevelopSlider.allCases.enumerated() { all = all.setting(slider, to: Double(i + 1)) }
        let data = try JSONEncoder().encode(all)
        #expect(try JSONDecoder().decode(DevelopSettings.self, from: data) == all)
    }

    @Test func fingerprintCoversEveryFieldAndIsStable() throws {
        let curve = try #require(ToneCurve(points: [point(0, 0), point(0.5, 0.6), point(1, 1)]))
        let base = DevelopSettings.neutral.setting(.exposure, to: 1)
        #expect(base.fingerprint == base.fingerprint)
        #expect(base.setting(curve: curve).fingerprint != base.fingerprint)
        #expect(base.setting(levels: DevelopLevels.neutral.setting(.gamma, to: 1.2)).fingerprint != base.fingerprint)
        #expect(base.setting(.blacks, to: 3).fingerprint != base.fingerprint)
    }

    @Test func testOldCatalogAndNewFieldsWalk() async throws {
        let coding = LiveCatalogCoding()
        let golden = Data(LibraryPersistGolden.catalogV1.utf8)
        let photos = try coding.decode(golden)
        #expect(photos == LibraryPersistGolden.photos)
        #expect(photos.allSatisfy { $0.develop.curve == .identity && $0.develop.levels == .neutral })
        #expect(try coding.encode(photos) == golden)
        var edited = photos
        edited[0] = try developed(photos[0])
        #expect(try coding.decode(try coding.encode(edited)) == edited)
        let photo = try #require(photos.last), changed = try developed(photo)
        #expect(ThumbnailToken.of(changed.develop, longSide: 256) != ThumbnailToken.of(photo.develop, longSide: 256))
        let loupe = FakeLoupe()
        let neutral = try await loupe.render(photo, settings: photo.develop, longSide: 64, quality: .full)
        let developedRender = try await loupe.render(changed, settings: changed.develop, longSide: 64, quality: .full)
        #expect(neutral.image.checksum != developedRender.image.checksum)
    }

    @Test func tokenSeesACurveOnlyAndALevelsOnlyChange() throws {
        let curve = try #require(ToneCurve(points: [point(0, 0), point(0.5, 0.6), point(1, 1)]))
        let base = DevelopSettings.neutral.setting(.exposure, to: 1)
        let token = ThumbnailToken.of(base, longSide: 256)
        #expect(ThumbnailToken.of(base.setting(curve: curve), longSide: 256) != token)
        #expect(ThumbnailToken.of(base.setting(levels: DevelopLevels.neutral.setting(.gamma, to: 1.2)),
                                  longSide: 256) != token)
    }

    @Test func fakeLoupeMovesForACurveOnlyAndALevelsOnlyChange() async throws {
        let photo = PhotoItem(name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 0),
                              color: Color3(0.5, 0.5, 0.5), pixelSize: PixelSize(width: 64, height: 48))
        let curve = try #require(ToneCurve(points: [point(0, 0), point(0.5, 0.6), point(1, 1)]))
        let loupe = FakeLoupe()
        func checksum(_ settings: DevelopSettings) async throws -> String {
            try await loupe.render(photo, settings: settings, longSide: 64, quality: .full).image.checksum
        }
        let neutral = try await checksum(.neutral)
        let curved = try await checksum(DevelopSettings.neutral.setting(curve: curve))
        let levels = DevelopLevels.neutral.setting(.outBlack, to: 0.1)
        let leveled = try await checksum(DevelopSettings.neutral.setting(levels: levels))
        #expect(curved != neutral && leveled != neutral)
    }
}
