// PhotoDocumentHostTests.swift: finding #4260. Photo's suite document host:
// an `.open` hand-off (File > Open Recent ▸, Open In from another app, a
// file the home routes here) asks the app to open each of its images, an
// open with nothing in it is refused, `.new` and `.place` are accepted as
// before and open nothing, and every other verb is refused with a reason
// and delivers nothing. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import PhotoModel
import SuiteModel
import Testing

/// The requests a host delivered, in order.
private actor Delivered {
    private(set) var requests: [PhotoFileRequest] = []
    func record(_ requests: [PhotoFileRequest]) { self.requests += requests }
}

private func handOff(_ verb: HandOffVerb, _ documents: [SuiteDocumentRef] = []) -> HandOff {
    HandOff(id: HandOff.newID(), from: .photo, to: .photo, verb: verb, documents: documents, createdAt: Date())
}

private func ref(_ path: String, _ type: SuiteTypeID = .png) -> SuiteDocumentRef {
    SuiteDocumentRef(
        path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .photo, type: type,
        displayName: path.split(separator: "/").last.map(String.init) ?? path)
}

private func host(_ delivered: Delivered) -> PhotoDocumentHost {
    PhotoDocumentHost { await delivered.record($0) }
}

struct PhotoDocumentHostTests {
    @Test func openRecentOpensTheImage() async throws {
        let delivered = Delivered()
        let open = handOff(.open, [ref("/t/beach.png")])
        #expect(await host(delivered).refusal(for: open) == nil)
        let state = try await host(delivered).accept(open)
        #expect(state == .accepted)
        #expect(await delivered.requests == [.open(path: "/t/beach.png")])
    }

    @Test func openOfSeveralOpensEachInOrder() async throws {
        let delivered = Delivered()
        _ = try await host(delivered).accept(handOff(.open, [ref("/t/a.png"), ref("/t/b.ora", .photoOpenRaster)]))
        #expect(await delivered.requests == [.open(path: "/t/a.png"), .open(path: "/t/b.ora")])
    }

    @Test func openWithNothingIsRefused() async {
        let delivered = Delivered()
        #expect(await host(delivered).refusal(for: handOff(.open)) == PhotoDocumentHost.openNeedsImage)
        await #expect(throws: PhotoDocumentHost.openNeedsImage) { try await host(delivered).accept(handOff(.open)) }
        #expect(await delivered.requests.isEmpty)
    }

    @Test func newAndPlaceAreAcceptedAndOpenNothing() async throws {
        let delivered = Delivered()
        #expect(try await host(delivered).accept(handOff(.new)) == .accepted)
        #expect(try await host(delivered).accept(handOff(.place, [ref("/t/logo.png")])) == .accepted)
        #expect(await delivered.requests.isEmpty)
    }

    @Test func otherVerbsAreRefused() async {
        let delivered = Delivered()
        for verb in [HandOffVerb.edit, .importAnimation, .returnEdit, .openSettings] {
            #expect(await host(delivered).refusal(for: handOff(verb, [ref("/t/a.png")])) == PhotoDocumentHost.verbRefusal)
            await #expect(throws: PhotoDocumentHost.verbRefusal) { try await host(delivered).accept(handOff(verb, [ref("/t/a.png")])) }
        }
        #expect(await delivered.requests.isEmpty)
    }
}
