// CropAspectPickerTests.swift (orientation-crop OC-5): every chip of the crop aspect picker and its toggle send a crop
// command, and the toggle is disabled with a reason for Free and 1:1. macOS only (SuiteUI); the rules are in
// SuiteKernelTests' CropAspectChoicesTests.
import SuiteKernel
@testable import SuiteUI
import Testing

private struct CropFake: CropTarget {
    var cropFrame: CropFrame?, cropHelp: String?, cropBounds = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)
    mutating func setCropFrame(_ f: CropFrame?, name: String) throws { cropFrame = f }
    mutating func applyCrop() throws {}
}

@MainActor @Suite struct CropAspectPickerTests {
    @Test func everyChipSendsItsCommand() {
        let ids = Set(CropCommands.cropSpecs(CropFake.self).map(\.id))
        #expect(CropAspectPicker.chips.map(\.id) == CropAspectChoice.allCases)
        #expect(CropAspectPicker.chips.allSatisfy { $0.identifier == $0.id.identifier && ids.contains($0.id.command) })
        #expect(ids.contains(CropAspectPicker.toggleCommand))
    }

    @Test func toggleDisabledForFreeAndSquare() {
        let (free, square, tall) = (CropAspectPicker.toggleHelp(.free), CropAspectPicker.toggleHelp(.ratio(width: 1, height: 1)),
                                    CropAspectPicker.toggleHelp(.ratio(width: 4, height: 5)))
        #expect(!free.enabled && !square.enabled && tall.enabled)
        #expect(square.text != tall.text && tall.text.contains("crop.swap"), "a disabled toggle doesn't say why")
    }
}
