// LibraryDocumentHostTests.swift: quality gate #5947. Library's suite document
// host hands an open or place hand-off's photo paths to the window, and the
// catalog imports them: at once when it is loaded, after the launch read when
// the hand-off came while it was still loading (the welcome's Open sample
// launches Library with Sunset.png), so the photo is in the catalog and
// selected, not lost under the restored photos. Other verbs are refused and
// deliver nothing. Runs on Linux and macOS.
import Foundation
@testable import LibraryModel
import SuiteKernel
import SuiteModel
import Testing

/// The paths a host delivered, in order.
private actor Delivered {
    private(set) var paths: [String] = []
    func record(_ paths: [String]) { self.paths += paths }
}

private func handOff(_ verb: HandOffVerb, _ paths: [String] = []) -> HandOff {
    let documents = paths.map {
        SuiteDocumentRef(path: $0, fileID: SuiteDocumentRef.fileID(forPath: $0), app: .library, type: .png,
                         displayName: LiveImporter.lastComponent($0))
    }
    return HandOff(id: HandOff.newID(), from: .launcher, to: .library, verb: verb, documents: documents, createdAt: Date())
}

@Suite struct LibraryDocumentHostTests {
    @Test func anOpenHandOffDeliversItsPhotos() async throws {
        let delivered = Delivered()
        let host = LibraryDocumentHost { await delivered.record($0) }
        #expect(try await host.accept(handOff(.open, ["/s/Sunset.png"])) == .accepted)
        #expect(try await host.accept(handOff(.place, ["/s/a.jpg", "/s/b.jpg"])) == .accepted)
        #expect(await delivered.paths == ["/s/Sunset.png", "/s/a.jpg", "/s/b.jpg"])
    }

    @Test func otherVerbsAreRefusedAndDeliverNothing() async {
        let delivered = Delivered()
        let host = LibraryDocumentHost { await delivered.record($0) }
        #expect(await host.refusal(for: handOff(.edit, ["/s/a.jpg"])) == LibraryCatalog.handOffRefusal)
        await #expect(throws: LibraryCatalog.handOffRefusal) { try await host.accept(handOff(.edit, ["/s/a.jpg"])) }
        #expect(await delivered.paths.isEmpty)
    }

    @Test func aHandOffDuringTheLaunchReadImportsAfterIt() throws {
        try LibraryFileFlowTests.withShoot { folder in
            let sunset = folder + "/IMG_0001.jpg"
            var library = LibraryCatalog(services: .fake())
            library.beginRestore()
            library.importHandedOff([sunset])
            #expect(library.items.isEmpty)
            library.restore([PhotoItem(id: "/old/kept.jpg", name: "kept", captureDate: Date(timeIntervalSince1970: 0),
                                       color: LiveImporter.neutralGrey, path: "/old/kept.jpg")])
            #expect(library.items.map(\.id).sorted() == ["/old/kept.jpg", sunset])
            #expect(library.selection == [sunset])
        }
    }

    @Test func aHandOffToALoadedCatalogImportsAtOnceAndOnlyOnce() throws {
        try LibraryFileFlowTests.withShoot { folder in
            let sunset = folder + "/IMG_0001.jpg"
            var library = LibraryCatalog(services: .fake())
            library.importHandedOff([sunset])
            library.importHandedOff([sunset])
            #expect(library.items.map(\.id) == [sunset])
            #expect(library.selection == [sunset])
        }
    }
}
