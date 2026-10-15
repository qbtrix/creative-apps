// LibraryPhotoItemTests.swift: the develop values and PhotoItem's grown shape
// (path, pixel size, develop, availability) from the spine contract (SP-2).
// Runs on Linux and macOS.
import CoreColor
import Foundation
@testable import LibraryModel
import Testing

private let epoch = Date(timeIntervalSince1970: 0)

@Test func anExistingCallKeepsTheSampleDefaults() {
    let photo = PhotoItem(name: "IMG_0001", captureDate: epoch, color: Color3(0.2, 0.4, 0.6))
    #expect(photo.path == nil)
    #expect(photo.pixelSize == PixelSize(width: 4032, height: 3024))
    #expect(photo.develop == .neutral && photo.develop.isNeutral)
    #expect(photo.availability == .available)
}

@Test func slidersClampAndNonFiniteValuesGiveZero() {
    #expect(DevelopSettings.neutral.setting(.exposure, to: .nan).value(.exposure) == 0)
    #expect(DevelopSettings.neutral.setting(.exposure, to: .nan).isNeutral)
    #expect(DevelopSettings.neutral.setting(.exposure, to: .infinity).value(.exposure) == 0)
    #expect(DevelopSettings.neutral.setting(.exposure, to: 9).value(.exposure) == 5)
    #expect(DevelopSettings.neutral.setting(.contrast, to: 500).value(.contrast) == 100)
    #expect(DevelopSettings.neutral.setting(.tint, to: -500).value(.tint) == -100)
    #expect(DevelopGroup.tone.sliders == [.exposure, .contrast, .highlights, .shadows])
    #expect(DevelopGroup.color.sliders == [.temperature, .tint])
}

@Test func pastingAdjustmentsKeepsTheCrop() {
    let crop = CropSettings(angle: 5, rect: UnitRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5), aspect: .square)
    let target = DevelopSettings.neutral.setting(crop: crop)
    let source = DevelopSettings.neutral.setting(.exposure, to: 1).setting(crop: nil)
    let pasted = target.pastingAdjustments(from: source)
    #expect(pasted.crop == crop)
    #expect(pasted.value(.exposure) == 1)
    #expect(!pasted.isAdjustmentNeutral)
    #expect(target.isAdjustmentNeutral && !target.isNeutral)
}

@Test func cropRatiosFollowThePhotosOrientation() {
    let portrait = PixelSize(width: 4000, height: 6000)
    let landscape = PixelSize(width: 6000, height: 4000)
    #expect(CropAspect.threeTwo.ratio(for: portrait) == 2.0 / 3.0)
    #expect(CropAspect.threeTwo.ratio(for: landscape) == 3.0 / 2.0)
    #expect(CropAspect.free.ratio(for: landscape) == nil)
    #expect(CropAspect.square.ratio(for: portrait) == 1)
    #expect(CropAspect.original.ratio(for: portrait) == 4000.0 / 6000.0)
    #expect(CropAspect.original.ratio(for: PixelSize(width: 10, height: 0)) == nil)
}

@Test func anEmptyHistogramHasZeroHeights() {
    #expect(HistogramBins.empty.heights.red.allSatisfy { $0 == 0 })
    #expect(HistogramBins.empty.heights.blue.count == HistogramBins.binCount)
}

@Test func cullSummarySaysStarsFlagAndLabel() {
    let base = PhotoItem(name: "a", captureDate: epoch, color: Color3(0, 0, 0))
    #expect(base.cullSummary == "No stars")
    #expect(PhotoItem(name: "a", captureDate: epoch, color: Color3(0, 0, 0), rating: 1).cullSummary == "1 star")
    #expect(PhotoItem(name: "a", captureDate: epoch, color: Color3(0, 0, 0), rating: 3, flag: .reject).cullSummary
        == "3 stars, Rejected")
    #expect(PhotoItem(name: "a", captureDate: epoch, color: Color3(0, 0, 0), rating: 3, isFlagged: true, label: .red)
        .cullSummary == "3 stars, Picked, Red")
}

@Test func availabilityHelpSaysWhyAFileCantBeRead() {
    #expect(PhotoAvailability.available.help == nil)
    #expect(PhotoAvailability.missing.help == "The file is missing.")
    #expect(PhotoAvailability.unreadable("not an image file").help
        == "Library can't read this file: not an image file.")
}

@Test func copiesCarryTheNewFields() {
    let crop = CropSettings(angle: 0, rect: .full, aspect: .original)
    let photo = PhotoItem(
        name: "IMG_1", captureDate: epoch, color: Color3(1, 0, 0), rating: 2, label: .blue, path: "/f/IMG_1.jpg",
        pixelSize: PixelSize(width: 600, height: 400), develop: DevelopSettings.neutral.setting(crop: crop),
        availability: .missing)
    let renamed = photo.withID("IMG_1 2")
    #expect(renamed.id == "IMG_1 2")
    #expect(renamed.path == photo.path && renamed.pixelSize == photo.pixelSize)
    #expect(renamed.develop == photo.develop && renamed.availability == .missing)
    #expect(renamed.rating == 2 && renamed.label == .blue)
    let resized = photo.withSize(PixelSize(width: 300, height: 300))
    #expect(resized.id == photo.id && resized.pixelSize == PixelSize(width: 300, height: 300))
    #expect(resized.develop == photo.develop && resized.path == photo.path && resized.availability == .missing)
}
