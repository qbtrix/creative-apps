// PhotoContractsTests.swift: the shared values, document, edit and crop
// contracts (blueprint 5.1) keep their texts, titles and options. Runs on
// Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoContractsTests {
    @Test func archiveErrorsGiveTheTextsOfPJ4() {
        #expect(ArchiveError.notADocument.message == "It isn't a Photo Document or an image Photo can open.")
        #expect(ArchiveError.newerVersion(2).message
            == "It was saved by a newer version of Photo. Update Photo to open it.")
        #expect(ArchiveError.damaged("data/layer-2.png is missing").message == "It is damaged and can't be read.")
        #expect(ArchiveError.tooLarge.message == "It is larger than Photo can open: up to 16 megapixels.")
    }

    @Test func archiveErrorsSpeakPlainWords() {
        let all: [ArchiveError] = [.notADocument, .newerVersion(2), .damaged("data/layer-2.png is missing"),
                                   .damaged("photo/document.json is missing"), .tooLarge]
        for error in all {
            #expect(!error.message.contains("/"), "\(error) names a path: \(error.message)")
            #expect(!error.message.contains(/format \d/), "\(error) names a format number: \(error.message)")
        }
        #expect(ArchiveError.tooLarge.message.contains("megapixels"))
        #expect(ArchiveError.notADocument.message.contains("Photo Document"))
    }

    @Test func aDamagedFileKeepsItsDetailOutOfTheAlert() {
        #expect(ArchiveError.damaged("data/layer-2.png is missing").detail == "data/layer-2.png is missing")
        #expect(ArchiveError.tooLarge.detail == nil)
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
