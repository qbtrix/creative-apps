// PhotoUnsavedPromptTextTests.swift: the unsaved-changes alert's words
// (photo-documents D-10): the message, Save, Don't Save and Cancel in order
// with their identifiers, and no prompt for a clean or empty image. Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoUnsavedPromptTextTests {
    @Test func theAlertNamesTheFileWithSaveDontSaveCancel() {
        #expect(PhotoUnsavedPrompt.message(for: "beach.png")
            == "Do you want to save the changes made to the document \u{201C}beach.png\u{201D}?")
        #expect(PhotoUnsavedPrompt.informativeText == "Your changes will be lost if you don't save them.")
        #expect(PhotoUnsavedPrompt.choices.map(\.title) == ["Save", "Don't Save", "Cancel"])
        #expect(PhotoUnsavedPrompt.choices.map(\.identifier)
            == ["photo.unsaved.save", "photo.unsaved.dontSave", "photo.unsaved.cancel"])
        #expect([0, 1, 2, 3, -1].map(PhotoUnsavedPrompt.answer(forButton:)) == [.save, .dontSave, .cancel, .cancel, .cancel])
    }

    @Test func onlyADirtyImageAsks() throws {
        #expect(PhotoWorkspace().unsavedPromptMessage == nil)
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.openImage(try RawCodec().encode(white, as: .png, quality: 1), name: "beach.png", codec: RawCodec())
        #expect(workspace.unsavedPromptMessage == nil)
        workspace.addLayer()
        #expect(workspace.unsavedPromptMessage == PhotoUnsavedPrompt.message(for: "beach.png"))
        var untitled = PhotoWorkspace(services: .fake)
        try untitled.newCanvas(width: 4, height: 3)
        untitled.addLayer()
        #expect(untitled.unsavedPromptMessage == PhotoUnsavedPrompt.message(for: "Untitled"))
    }
}
