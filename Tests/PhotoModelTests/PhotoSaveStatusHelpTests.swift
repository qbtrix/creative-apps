import PhotoModel
import Testing

@Suite struct PhotoSaveStatusHelpTests {
    @Test func everyStatusExplainsItself() {
        for status in PhotoSaveStatus.allCases {
            #expect(!status.help(fileName: "beach.png").isEmpty)
            #expect(!status.help(fileName: nil).isEmpty)
        }
    }

    @Test func savedNamesTheFile() {
        #expect(PhotoSaveStatus.saved.help(fileName: "beach.png") == "All changes are saved in beach.png.")
    }

    @Test func autosavedIsOnlyARecoveryCopy() {
        let help = PhotoSaveStatus.editedAutosaved.help(fileName: "beach.png")
        #expect(help.contains("recovery copy"))
        #expect(help.contains("beach.png"))
    }

    @Test func notSavedPointsToSaveAs() {
        #expect(PhotoSaveStatus.notSaved.help(fileName: "beach.png").contains("Save As"))
    }

    @Test func noNameReadsThisImage() {
        #expect(PhotoSaveStatus.edited.help(fileName: nil) == "Changes since this image was last saved.")
        #expect(PhotoSaveStatus.saved.help(fileName: "").contains("this image"))
    }
}
