// PhotoContractsTests.swift: the shared values, document, edit and crop
// contracts (blueprint 5.1) keep their texts, titles and options. Runs on
// Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoContractsTests {
    @Test func archiveErrorsGiveTheTextsOfPJ4() {
        #expect(ArchiveError.notADocument.message == "This file isn't a Photo document.")
        #expect(ArchiveError.newerVersion(2).message
            == "This document was made by a newer Photo (format 2). Update Photo to open it.")
        #expect(ArchiveError.damaged("data/layer-2.png is missing").message
            == "This document is damaged: data/layer-2.png is missing.")
        #expect(ArchiveError.tooLarge.message == "This document is larger than Photo can open.")
    }

    @Test func cropAspectPresetsAreInOrder() {
        #expect(CropAspect.presets.map(\.title) == ["Free", "Original", "1:1", "3:2", "4:3", "16:9"])
        #expect(CropAspect.presets.first == .free)
    }

    @Test func refusalsWithTheSameTextAreEqual() {
        #expect(PhotoRefusal("x") == PhotoRefusal("x"))
        #expect(PhotoRefusal("x") != PhotoRefusal("y"))
        #expect(PhotoRefusal("Nothing to paste.").message == "Nothing to paste.")
    }

    @Test func dragModifiersHoldEachKey() {
        let both: DragModifiers = [.shift, .option]
        #expect(both.contains(.shift) && both.contains(.option))
        #expect(!DragModifiers().contains(.shift))
        #expect(DragModifiers.shift != DragModifiers.option)
    }

    @Test func cropFieldsAreTheFourNumbers() {
        #expect(CropField.allCases == [.x, .y, .width, .height])
    }
}
