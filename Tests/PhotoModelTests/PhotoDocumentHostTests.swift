// PhotoDocumentHostTests.swift: finding #4260. Photo's suite document host:
// an `.open` hand-off (File > Open Recent ▸, Open In from another app, a
// file the home routes here) asks the app to open each of its images, an
// open with nothing in it is refused, `.new` (the home's New Photo, #3648)
// asks for one new image at the preset's size or 1920 x 1080, `.place` is
// accepted and opens nothing, and every other verb is refused with a reason
// and delivers nothing; the window adopts a live command's copy of its
// workspace, and ignores a copy older than its own edits (EM-3). Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import PhotoModel
import SuiteKernel
import SuiteModel
import Testing

/// The requests a host delivered, in order.
private actor Delivered {
    private(set) var requests: [PhotoFileRequest] = []
    func record(_ requests: [PhotoFileRequest]) { self.requests += requests }
}

private func handOff(_ verb: HandOffVerb, _ documents: [SuiteDocumentRef] = [], preset: NewDocumentPreset? = nil) -> HandOff {
    HandOff(id: HandOff.newID(), from: .photo, to: .photo, verb: verb, documents: documents, preset: preset, createdAt: Date())
}

private func sheet(_ parameters: [String: String] = [:]) -> NewDocumentPreset {
    NewDocumentPreset(id: "photo.sheet", app: .photo, title: "Photo", detail: "", parameters: parameters)
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

    @Test func homesNewPhotoAsksForA1920By1080Image() async throws {
        let delivered = Delivered()
        #expect(try await host(delivered).accept(handOff(.new, preset: sheet())) == .accepted)
        #expect(try await host(delivered).accept(handOff(.new)) == .accepted)
        #expect(await delivered.requests == [.newImage(width: 1920, height: 1080), .newImage(width: 1920, height: 1080)])
    }

    @Test func newTakesThePresetsSizeAndIgnoresABadOne() {
        #expect(PhotoDocumentHost.newImage(for: sheet(["width": "800", "height": "600"])) == .newImage(width: 800, height: 600))
        #expect(PhotoDocumentHost.newImage(for: sheet(["width": "0", "height": "tall"])) == .newImage(width: 1920, height: 1080))
        #expect(PhotoDocumentHost.newImage(for: sheet(["height": "600"])) == .newImage(width: 1920, height: 600))
    }

    @Test func placeIsAcceptedAndOpensNothing() async throws {
        let delivered = Delivered()
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

struct PhotoLiveCommandTests {
    static let paste: JSONValue = .object(["width": .number(1), "height": .number(1), "rgba8": .array([255, 0, 0, 255].map { .number($0) })])

    @Test func aLiveCommandsResultIsAdopted() throws {
        var window = try PhotoHeadless.new(.object(["width": .number(4), "height": .number(4)])).workspace
        var copy = PhotoHeadless(workspace: window)
        _ = try PhotoHeadless.catalog.run("edit.paste", params: Self.paste, on: &copy)
        window.adoptLiveCommand(copy.workspace)
        #expect(window.layers.count == 2)
        #expect(window.revision == copy.workspace.revision)
    }

    @Test func aCopyOlderThanTheWindowsEditsIsIgnored() throws {
        var window = try PhotoHeadless.new(.object(["width": .number(4), "height": .number(4)]))
        var copy = window
        _ = try PhotoHeadless.catalog.run("edit.paste", params: Self.paste, on: &copy)
        for _ in 0..<2 { _ = try PhotoHeadless.catalog.run("edit.paste", params: Self.paste, on: &window) }
        var workspace = window.workspace
        workspace.adoptLiveCommand(copy.workspace)
        #expect(workspace.layers.count == 3)
        #expect(workspace.revision == window.workspace.revision)
    }
}
