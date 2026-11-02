// DesignDocumentHostTests.swift (#5200, #3333): Design's suite document host.
// An `.open` hand-off delivers each file's path in order and is accepted, an
// open with nothing in it is refused, a `.new` (the home's New Design, the
// welcome's Blank) delivers one new file, and every other verb is refused with
// Design's reason; a refusal delivers nothing. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import SuiteModel
import Testing

/// What the host delivered to the app, in order.
private actor DesignDelivered {
    private(set) var requests: [DesignDocumentHost.Request] = []
    func record(_ requests: [DesignDocumentHost.Request]) { self.requests += requests }
}

struct DesignDocumentHostTests {
    private func handOff(_ verb: HandOffVerb, _ paths: [String] = []) -> HandOff {
        let documents = paths.map { path in
            SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                             type: .designDocument, displayName: path.split(separator: "/").last.map(String.init) ?? path)
        }
        return HandOff(id: HandOff.newID(), from: .launcher, to: .design, verb: verb, documents: documents, createdAt: Date())
    }

    @Test func anOpenDeliversEachFileInOrder() async throws {
        let delivered = DesignDelivered()
        let host = DesignDocumentHost { await delivered.record($0) }
        let open = handOff(.open, ["/t/Logo.design", "/t/Card.design"])
        #expect(await host.refusal(for: open) == nil)
        #expect(try await host.accept(open) == .accepted)
        #expect(await delivered.requests == [.open(path: "/t/Logo.design"), .open(path: "/t/Card.design")])
    }

    @Test func anEmptyOpenIsRefused() async {
        let delivered = DesignDelivered()
        let host = DesignDocumentHost { await delivered.record($0) }
        await #expect(throws: DesignDocumentHost.openNeedsDocument) { try await host.accept(handOff(.open)) }
        #expect(await delivered.requests.isEmpty)
    }

    /// #3333: the welcome's Blank and the home's New Design send `.new`; Design starts one new file.
    @Test func aNewDeliversOneNewFile() async throws {
        let delivered = DesignDelivered()
        let host = DesignDocumentHost { await delivered.record($0) }
        #expect(await host.refusal(for: handOff(.new)) == nil)
        #expect(try await host.accept(handOff(.new)) == .accepted)
        #expect(await delivered.requests == [.newFile])
    }

    @Test func everyOtherVerbIsRefused() async {
        let delivered = DesignDelivered()
        let host = DesignDocumentHost { await delivered.record($0) }
        for verb in [HandOffVerb.place, .edit, .importAnimation, .returnEdit, .openSettings] {
            #expect(await host.refusal(for: handOff(verb, ["/t/Logo.design"])) == DesignDocumentHost.verbRefusal)
        }
        #expect(await delivered.requests.isEmpty)
    }
}
