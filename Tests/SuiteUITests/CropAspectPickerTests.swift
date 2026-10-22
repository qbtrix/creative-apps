// CropAspectPickerTests.swift (orientation-crop OC-5): every chip of the crop aspect picker sends a crop command, the
// orientation toggle is disabled with a reason for Free and 1:1, and a custom 0 is refused with a sentence. macOS
// only (SuiteUI).
import SuiteKernel
@testable import SuiteUI
import Testing

private struct CropFake: CropTarget {
    var cropFrame: CropFrame?
    var cropHelp: String? { nil }
    var cropBounds: Rect { Rect(minX: 0, minY: 0, maxX: 1, maxY: 1) }
    mutating func setCropFrame(_ f: CropFrame?, name: String) throws { cropFrame = f }
    mutating func applyCrop() throws {}
}

@MainActor @Suite struct CropAspectPickerTests {
    @Test func everyChipSendsItsCommand() {
        let ids = Set(CropCommands.cropSpecs(CropFake.self).map(\.id))
        #expect(CropAspectPicker.chips.map(\.id) == CropAspectChoice.allCases)
        for chip in CropAspectPicker.chips {
            #expect(chip.identifier == chip.id.identifier, "\(chip.title) has no identifier")
            #expect(ids.contains(chip.id.command), "\(chip.title) is bare")
        }
        #expect(ids.contains(CropAspectPicker.toggleCommand))
    }

    @Test func toggleDisabledForFreeAndSquare() {
        #expect(CropAspectPicker.toggleHelp(.free).enabled == false)
        #expect(CropAspectPicker.toggleHelp(.ratio(width: 1, height: 1)).enabled == false)
        let square = CropAspectPicker.toggleHelp(.ratio(width: 1, height: 1)).text
        #expect(square != CropAspectPicker.toggleHelp(.ratio(width: 4, height: 5)).text, "a disabled toggle doesn't say why")
        #expect(CropAspectPicker.toggleHelp(.ratio(width: 4, height: 5)).enabled)
        #expect(CropAspectPicker.toggleHelp(.ratio(width: 4, height: 5)).text.contains("crop.swap"))
        guard case .problem = CropAspectChoices.custom(width: "0", height: "5") else {
            Issue.record("0 was taken as a width"); return
        }
    }
}
