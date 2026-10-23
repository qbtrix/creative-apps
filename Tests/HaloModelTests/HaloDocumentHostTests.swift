// HaloDocumentHostTests.swift: A-HA-1 (#865). Halo's suite document host:
// a `.new` hand-off asks the window for New Composition, an `.open` of a
// .halo file opens it through the open path (`.openRecent(path)`), and
// every other verb, or an open with no Halo project in it, is refused with
// a reason and delivers nothing. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HaloModel
import SuiteModel
import Testing

/// The commands a host delivered, in order.
private actor Delivered {
    private(set) var commands: [HaloCommand] = []
    func record(_ command: HaloCommand) { commands.append(command) }
}

private func handOff(_ verb: HandOffVerb, _ documents: [SuiteDocumentRef] = []) -> HandOff {
    HandOff(id: HandOff.newID(), from: .launcher, to: .halo, verb: verb, documents: documents, createdAt: Date())
}

private func ref(_ path: String, _ type: SuiteTypeID) -> SuiteDocumentRef {
    SuiteDocumentRef(
        path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .halo, type: type,
        displayName: path.split(separator: "/").last.map(String.init) ?? path)
}

private func host(_ delivered: Delivered) -> HaloDocumentHost {
    HaloDocumentHost { await delivered.record($0) }
}

struct HaloDocumentHostTests {
    @Test func newPresentsNewComposition() async throws {
        let delivered = Delivered()
        let state = try await host(delivered).accept(handOff(.new))
        #expect(state == .accepted)
        #expect(await delivered.commands == [.newComposition])
    }

    @Test func openOfAHaloFileOpensIt() async throws {
        let delivered = Delivered()
        let open = handOff(.open, [ref("/t/Intro.halo", .haloProject)])
        #expect(await host(delivered).refusal(for: open) == nil)
        let state = try await host(delivered).accept(open)
        #expect(state == .accepted)
        #expect(await delivered.commands == [.openRecent("/t/Intro.halo")])
    }

    @Test func aHaloExtensionIsEnoughToOpen() async throws {
        let delivered = Delivered()
        let open = handOff(.open, [ref("/t/Spot.HALO", SuiteTypeID(rawValue: "public.json"))])
        _ = try await host(delivered).accept(open)
        #expect(await delivered.commands == [.openRecent("/t/Spot.HALO")])
    }

    @Test func anOpenWithNoHaloProjectIsRefused() async {
        let delivered = Delivered()
        let photo = handOff(.open, [ref("/t/Cat.png", .png)])
        #expect(await host(delivered).refusal(for: photo) == .unsupportedFile(name: "Cat.png"))
        await #expect(throws: SuiteError.unsupportedFile(name: "Cat.png")) {
            try await host(delivered).accept(photo)
        }
        #expect(await host(delivered).refusal(for: handOff(.open)) == HaloDocumentHost.openNeedsProject)
        #expect(await delivered.commands.isEmpty)
    }

    @Test(arguments: [HandOffVerb.edit, .place, .importAnimation, .returnEdit, .openSettings])
    func otherVerbsAreRefused(_ verb: HandOffVerb) async {
        let delivered = Delivered()
        let other = handOff(verb, [ref("/t/Intro.halo", .haloProject)])
        #expect(await host(delivered).refusal(for: other) == HaloDocumentHost.verbRefusal)
        await #expect(throws: HaloDocumentHost.verbRefusal) { try await host(delivered).accept(other) }
        #expect(await delivered.commands.isEmpty)
    }

    @Test func aRefusalSaysWhy() {
        #expect(HaloDocumentHost.verbRefusal == .notAvailable("Halo can't do that yet."))
        #expect(HaloDocumentHost.openNeedsProject == .notAvailable("Choose a Halo project to open."))
    }
}
