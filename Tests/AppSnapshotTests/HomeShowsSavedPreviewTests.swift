// HomeShowsSavedPreviewTests.swift: the home's Recent card shows a saved
// Photo document's preview end to end on the live path (#5199). Photo's live
// services and the launcher's (`LauncherServices.make`) are built separately
// over one temp support folder, as two processes would be. Photo writes a
// real `.ora` with the live archive, publishes its thumbnail the way a save
// does (`PhotoSavedPreview`) and notes the save in the shared recents; the
// launcher's home then reads its cards from the live recents and asks the live
// thumbnails slot for each card's preview. Nothing touches the real support
// folder. macOS only.
#if os(macOS)
import CoreRaster
import Foundation
import PhotoModel
import SuiteModel
import SuiteShell
import Testing

@testable import AfterGlowApp
@testable import PhotoApp

@MainActor @Suite struct HomeShowsSavedPreviewTests {
    @Test(.timeLimit(.minutes(1))) func aPhotoSaveShowsOnTheHomesRecentCard() async throws {
        let support = FileManager.default.temporaryDirectory.appending(path: "HomeShowsSavedPreview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: support) }
        let arguments = ["-SuiteSupportDir", support.path]

        // The launcher's services exist before Photo saves, as a running home's would.
        let launcher = LauncherServices.make(arguments: arguments, support: support.path)
        #expect(launcher.pending["thumbnails"] == nil, "the live thumbnails slot isn't live")

        // Photo saves Beach.ora: the file lands, its thumbnail is published, the save is noted.
        let photo = SuiteServices.live(support: support.path, app: .photo, arguments: arguments)
        let url = support.appending(path: "Documents/Beach.ora")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
        let snapshot = PhotoDocumentSnapshot(canvas: CanvasSize(width: 4, height: 3),
                                             layers: [PhotoLayer(id: "base", name: "Background")], pixels: ["base": white])
        let archive = PhotoServices.live.archive
        try archive.container(try archive.encode(snapshot, codec: ImageIOCodec())).write(to: url)
        let path = url.path(percentEncoded: false)
        #expect(await PhotoSavedPreview.publish(documentAt: path, archive: archive, to: photo.thumbnails), "the save published nothing")
        await SuiteDocumentsBridge(app: .photo, services: photo).note(PhotoSavedPreview.ref(forPath: path), .saved)

        // The home reads its cards from the live recents and their previews from the live slot.
        let home = HomeModel(services: launcher, fileExists: { FileManager.default.fileExists(atPath: $0) })
        await home.reload(now: Date())
        let card = try #require(home.state.cards.first { $0.item.ref.path == path }, "the saved document has no Recent card")
        let previews = HomePreviews<Data>(decode: { $0 }, mark: { _ in nil })
        await previews.load(home.state.cards.map(\.item.ref), from: home.thumbnails)
        let saved = try archive.package(fromContainer: Data(contentsOf: url)).files[PhotoSavedPreview.entry]
        #expect(previews.kind(for: card.item.ref) == .preview, "the home's card shows the app's mark, not the saved preview")
        #expect(previews.pictures[card.item.ref.fileID] == saved, "the card's preview isn't the saved file's thumbnail")
    }
}
#endif
