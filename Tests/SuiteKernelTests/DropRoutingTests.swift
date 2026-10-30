// DropRoutingTests.swift (file-flow SF-1, on at SF-5, KJ-files): the drop rule opens, places, hands off or refuses
// each file the way the suite's types route, whichever app it lands on.
import Foundation
import Testing
import SuiteKernel

@Suite struct DropRoutingTests {
    /// The readers of each extension, default first, as the suite's type registry lists them.
    static func readers(_ ext: String) -> [String] {
        switch ext {
        case "halo": ["halo"]
        case "design": ["design"]
        case "photo": ["photo"]
        case "png", "jpg": ["photo", "library"]
        default: []
        }
    }
    static let imagePlaces: Set<String> = ["png", "jpg"]

    func plan(_ paths: [String], into app: String, hasDocument: Bool = false, places: Set<String> = imagePlaces) -> [DropAction] {
        DropPlan.plan(paths, into: app, hasDocument: hasDocument, places: places, readers: Self.readers)
    }

    @Test func anotherAppsDocumentIsHandedOff() {
        #expect(plan(["/w/Intro.halo"], into: "design", hasDocument: true) == [.handOff(path: "/w/Intro.halo", app: "halo")])
    }

    @Test func anImageIsPlacedIntoAnOpenDocumentAndOpenedWithoutOne() {
        #expect(plan(["/w/Sky.png"], into: "photo", hasDocument: true) == [.place(path: "/w/Sky.png")])
        #expect(plan(["/w/Sky.png"], into: "photo", hasDocument: false) == [.open(path: "/w/Sky.png")])
        #expect(plan(["/w/Sky.png"], into: "library", hasDocument: true) == [.place(path: "/w/Sky.png")])
    }

    @Test func ownTypeOpensEvenWithADocumentOpen() {
        #expect(plan(["/w/Edit.photo"], into: "photo", hasDocument: true, places: ["png", "jpg", "photo"])
                == [.open(path: "/w/Edit.photo")])
    }

    /// A type the suite lists nowhere but the app's codec reads (.psd in Photo) is placed into an open
    /// document; with none open it is still refused.
    @Test func anUnlistedTypeTheAppPlacesIsPlacedIntoAnOpenDocument() {
        #expect(plan(["/w/Art.psd"], into: "photo", hasDocument: true, places: ["png", "psd"]) == [.place(path: "/w/Art.psd")])
        #expect(plan(["/w/Art.psd"], into: "photo", hasDocument: false, places: ["png", "psd"])
                    == [.refuse(path: "/w/Art.psd", reason: "AfterGlow can't open .psd files.")])
    }

    @Test func anUnknownTypeIsRefusedInWords() {
        #expect(plan(["/w/notes.xyz"], into: "design") == [.refuse(path: "/w/notes.xyz", reason: "AfterGlow can't open .xyz files.")])
    }

    @Test func extensionsRouteWhateverTheirCase() {
        #expect(plan(["/w/Intro.HALO"], into: "design") == [.handOff(path: "/w/Intro.HALO", app: "halo")])
        #expect(plan(["/w/Sky.PNG"], into: "photo", hasDocument: true) == [.place(path: "/w/Sky.PNG")])
    }

    @Test func aFolderExpandsOneLevelInNameOrder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("drop-\(UUID().uuidString)")
        let inner = folder.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["b.png", "a.halo"] { try Data().write(to: folder.appendingPathComponent(name)) }
        try Data().write(to: inner.appendingPathComponent("c.png"))
        #expect(plan([folder.path], into: "photo") == [.handOff(path: folder.appendingPathComponent("a.halo").path, app: "halo"),
                                                       .open(path: folder.appendingPathComponent("b.png").path)])
    }

    @Test func eachPathGetsOneActionInOrder() {
        let actions = plan(["/w/Sky.png", "/w/notes.xyz", "/w/Intro.halo"], into: "photo", hasDocument: true)
        #expect(actions.map(\.path) == ["/w/Sky.png", "/w/notes.xyz", "/w/Intro.halo"])
    }
}
