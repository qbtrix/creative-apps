// PhotoKeepLayersTests.swift: the words and buttons of "Keep layers?"
// (photo-documents, PJ-1): the informative text names the flat file and the
// new document beside it, for PNG and JPEG, and each button has its title,
// identifier and answer. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoKeepLayersTests {
    /// A 4 x 3 white image through RawCodec, opened as `name`, with a second layer.
    private func layered(_ name: String) throws -> PhotoWorkspace {
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.openImage(try RawCodec().encode(white, as: .png, quality: 1), name: name, codec: RawCodec())
        workspace.addLayer()
        return workspace
    }

    @Test func messageNamesTheFlatFileAndTheNewDocument() throws {
        let beach = try layered("beach.png")
        #expect(beach.saveAction == .askKeepLayers(.png))
        #expect(PhotoKeepLayers.title == "Keep layers?")
        #expect(beach.keepLayersMessage(format: .png) == """
            beach.png can keep only one flat layer. Save as Photo Document writes beach.ora next to it \
            with every layer, mask and adjustment, and leaves beach.png as it is.
            """)
    }

    @Test func messageHandlesJPEG() throws {
        let photo = try layered("trip.JPG")
        #expect(photo.saveAction == .askKeepLayers(.jpeg))
        let message = photo.keepLayersMessage(format: .jpeg)
        #expect(message.hasPrefix("trip.JPG can keep only one flat layer."))
        #expect(message.contains("writes trip.ora next to it"))
        #expect(message.hasSuffix("leaves trip.JPG as it is."))
    }

    @Test func messageWithNoNameUsesTheFormatsName() throws {
        var untitled = try whiteImage()
        untitled.addLayer()
        let message = untitled.keepLayersMessage(format: .jpeg)
        #expect(message.hasPrefix("Untitled.jpg can keep only one flat layer."))
        #expect(message.contains("writes Untitled.ora next to it"))
    }

    @Test func choicesCarryTitlesIdentifiersAndAnswers() {
        let choices = PhotoKeepLayers.choices(format: .jpeg)
        #expect(choices.map(\.title) == ["Save as Photo Document", "Flatten into JPEG", "Cancel"])
        #expect(choices.map(\.identifier) == [
            "photo.file.keep-layers.document", "photo.file.keep-layers.flatten", "photo.file.keep-layers.cancel",
        ])
        #expect(choices.map(\.answer) == [.saveDocument, .flatten(.jpeg), .cancel])
        #expect(PhotoKeepLayers.answer(forButton: 0, format: .png) == .saveDocument)
        #expect(PhotoKeepLayers.answer(forButton: 1, format: .png) == .flatten(.png))
        #expect(PhotoKeepLayers.answer(forButton: 2, format: .png) == .cancel)
        #expect(PhotoKeepLayers.answer(forButton: 7, format: .png) == .cancel)
        #expect(PhotoKeepLayers.answer(forButton: -1, format: .png) == .cancel)
    }
}
