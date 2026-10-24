// FlareDocumentHostTests.swift: finding #4636. Flare's suite document host:
// a dropped or reopened .flare (an `.open` hand-off) asks the app to open
// each animation in a window, an open with nothing in it is refused, `.new`
// is accepted and opens nothing, a placed SVG says Flare can't import it
// yet, and every other verb is refused; a refusal delivers nothing. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareModel
import SuiteModel
import Testing

/// What the host delivered to the app, in order.
private actor FlareDelivered {
    private(set) var requests: [FlareFileRequest] = []
    func record(_ requests: [FlareFileRequest]) { self.requests += requests }
}

struct FlareDocumentHostTests {
    private func handOff(_ verb: HandOffVerb, _ paths: [String] = []) -> HandOff {
        let documents = paths.map { path in
            SuiteDocumentRef(
                path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .flare,
                type: path.hasSuffix(".svg") ? .svg : .flareAnimation,
                displayName: path.split(separator: "/").last.map(String.init) ?? path)
        }
        return HandOff(id: HandOff.newID(), from: .flare, to: .flare, verb: verb, documents: documents, createdAt: Date())
    }

    @Test func aDroppedAnimationOpensInAWindow() async throws {
        let delivered = FlareDelivered()
        let host = FlareDocumentHost { await delivered.record($0) }
        let drop = handOff(.open, ["/t/Title.flare"])
        #expect(await host.refusal(for: drop) == nil)
        #expect(try await host.accept(drop) == .accepted)
        #expect(await delivered.requests == [.open(path: "/t/Title.flare")])
    }

    @Test func severalAnimationsOpenEachInOrder() async throws {
        let delivered = FlareDelivered()
        let host = FlareDocumentHost { await delivered.record($0) }
        _ = try await host.accept(handOff(.open, ["/t/Bounce.flare", "/t/Logo.flare"]))
        #expect(await delivered.requests == [.open(path: "/t/Bounce.flare"), .open(path: "/t/Logo.flare")])
    }

    @Test func anEmptyOpenIsRefused() async {
        let delivered = FlareDelivered()
        let host = FlareDocumentHost { await delivered.record($0) }
        #expect(await host.refusal(for: handOff(.open)) == FlareDocumentHost.openNeedsAnimation)
        await #expect(throws: FlareDocumentHost.openNeedsAnimation) { try await host.accept(handOff(.open)) }
        #expect(await delivered.requests.isEmpty)
    }

    @Test func newIsAcceptedAndOpensNothing() async throws {
        let delivered = FlareDelivered()
        let host = FlareDocumentHost { await delivered.record($0) }
        #expect(try await host.accept(handOff(.new)) == .accepted)
        #expect(await delivered.requests.isEmpty)
    }

    @Test func aPlacedSVGSaysFlareCantImportIt() async {
        let delivered = FlareDelivered()
        let host = FlareDocumentHost { await delivered.record($0) }
        let svg = handOff(.place, ["/t/logo.svg"])
        #expect(await host.refusal(for: svg) == .notAvailable(FlareWorkspace.svgRefusal))
        await #expect(throws: SuiteError.notAvailable(FlareWorkspace.svgRefusal)) { try await host.accept(svg) }
        #expect(await delivered.requests.isEmpty)
    }

    @Test func otherVerbsAreRefusedWithFlaresReason() async {
        let delivered = FlareDelivered()
        let host = FlareDocumentHost { await delivered.record($0) }
        let reason = SuiteError.notAvailable("Flare only opens and creates animations.")
        for verb in [HandOffVerb.edit, .importAnimation, .returnEdit, .openSettings] {
            #expect(await host.refusal(for: handOff(verb, ["/t/a.flare"])) == reason)
        }
        #expect(await host.refusal(for: handOff(.place, ["/t/a.flare"])) == reason)
        #expect(await delivered.requests.isEmpty)
    }
}
