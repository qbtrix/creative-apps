// SuiteFileDropLiveTests.swift (file-flow SF-8): the drop performs its plan and the drag source writes every
// representation. A .halo dropped on the home reaches the hand-off transport for Halo; a file opened or placed
// in an app goes to that app's document host; a dragged Library thumbnail offers the suite envelope, the PNG
// and the file URL; a dragged file keeps its path when its name holds a #, % or space. macOS only.
#if os(macOS)
import Foundation
import SuiteKernel
import SuiteModel
import Testing

@testable import SuiteShell

@MainActor
@Suite struct SuiteFileDropLiveTests {
    @Test func aHaloDroppedOnTheHomeIsHandedToHalo() async throws {
        let services = SuiteServices.fake()
        let handOffs = try #require(services.sending as? FakeHandOffs)
        let bridge = SuiteDocumentsBridge(app: .launcher, services: services, exists: { _ in true })
        await bridge.perform([.handOff(path: "/tmp/FileDropLive/Intro.halo", app: "halo")], host: nil)
        let sent = await handOffs.sent
        #expect(sent.count == 1)
        #expect(sent.first?.to == .halo)
        #expect(sent.first?.verb == .open)
        #expect(sent.first?.documents.first?.displayName == "Intro.halo")
    }

    @Test func openAndPlaceGoToTheAppsDocumentHost() async throws {
        let services = SuiteServices.fake()
        let handOffs = try #require(services.sending as? FakeHandOffs)
        let host = FakeDocumentHost(app: .design, verbs: [.open, .place])
        let bridge = SuiteDocumentsBridge(app: .design, services: services, exists: { _ in true })
        await bridge.perform([.open(path: "/tmp/FileDropLive/Poster.design"), .place(path: "/tmp/FileDropLive/Beach.png"),
                              .refuse(path: "/tmp/FileDropLive/notes.xyz", reason: "Design can't open .xyz files.")],
                             host: host)
        let accepted = await host.accepted
        #expect(accepted.map(\.verb) == [.open, .place])
        #expect(accepted.map(\.to) == [.design, .design])
        #expect(accepted.compactMap(\.documents.first?.displayName) == ["Poster.design", "Beach.png"])
        #expect(await handOffs.sent.isEmpty, "an open in the app itself went out as a hand-off")
    }

    @Test func aDraggedThumbnailOffersEnvelopePNGAndFileURL() throws {
        let path = "/tmp/FileDropLive/Beach.png"
        let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .library,
                                   type: .png, displayName: "Beach.png")
        let items: [SuiteClipItem] = [.envelope(AssetEnvelope(name: "Beach", kind: .image, from: .library)),
                                      .image(png: Data([0x89, 0x50]), pixelWidth: 1, pixelHeight: 1), .files([ref])]
        let types = SuiteDragSource.provider(for: items, coding: FakePasteboard()).registeredTypeIdentifiers
        #expect(types.contains(SuiteTypeID.assetEnvelope.rawValue), "the drag offers no suite envelope")
        #expect(types.contains(SuiteTypeID.png.rawValue), "the drag offers no PNG")
        #expect(types.contains(SuiteTypeID.fileURL.rawValue), "the drag offers no file URL")
    }

    @Test(arguments: ["/tmp/FileDropLive/Draft #2.design", "/tmp/FileDropLive/100% Logo.design",
                      "/tmp/FileDropLive/Logo animated.flare"])
    func aDraggedFileKeepsItsPath(_ path: String) async throws {
        let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                                   type: .designDocument, displayName: URL(fileURLWithPath: path).lastPathComponent)
        let provider = SuiteDragSource.provider(for: [.files([ref])], coding: FakePasteboard())
        let url: URL? = await withCheckedContinuation { done in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in done.resume(returning: url) }
        }
        #expect(url?.isFileURL == true, "the drag offers no file URL for \(path)")
        #expect(url?.path(percentEncoded: false) == path, "the drag points at another file")
    }

    @Test func anEmptyDragOffersNothing() {
        #expect(SuiteDragSource.provider(for: [], coding: FakePasteboard()).registeredTypeIdentifiers.isEmpty)
    }
}
#endif
