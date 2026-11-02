// PhotoFileFlowTests.swift: MPF, Photo's file-flow Model walk (file-flow
// PF-1 written, PF-3 turns it on). Photo as a FileFlowTarget and a
// SuiteDocumentHost: it names itself "photo", places images into an open
// document as one "Place" step, opens one with no document, hands another
// app's file to that app, accepts open, new and place hand-offs, imports its
// old saved list once into a temp recents store, and runs RJ-P42
// (Tests/RealJobs/photo/drop-layer) on the catalog. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteModel
import Testing

/// A 4 x 3 white PNG through RawCodec, opened as `name`.
private func openedImage(_ name: String = "Sunset.png") throws -> PhotoWorkspace {
    let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
    var workspace = PhotoWorkspace(services: .fake)
    try workspace.openImage(try RawCodec().encode(white, as: .png, quality: 1), name: name, codec: RawCodec())
    return workspace
}

/// A hand-off from Library to Photo for `path`.
private func handOff(_ verb: HandOffVerb, path: String = "/w/Logo.png") -> HandOff {
    let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .library,
                               type: .png, displayName: "Logo.png")
    return HandOff(id: HandOff.newID(), from: .library, to: .photo, verb: verb, documents: [ref],
                   createdAt: Date(timeIntervalSince1970: 0))
}

/// A temp folder for one test, never the user's support folder.
private func tempFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoFileFlow-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

/// A `width` x `height` opaque red PNG at `name` in `folder`; its path.
private func redPNG(_ name: String, in folder: URL, width: Int = 2, height: Int = 2) throws -> String {
    let red = DecodedImage(rgba8: Array([[UInt8]](repeating: [255, 0, 0, 255], count: width * height).joined()),
                           width: width, height: height)
    let url = folder.appendingPathComponent(name)
    try CoreRasterImageCodec().encode(red, as: .png, quality: 1).write(to: url)
    return url.path
}

/// MPF, the behaviour PF-3 turns on.
@Suite struct PhotoFileFlowTests {

    @Test func photoNamesItselfAndPlacesImages() {
        let workspace = PhotoWorkspace(services: .fake)
        #expect(workspace.appID == "photo")
        #expect(workspace.placesExtensions.isSubset(of: CoreRasterImageCodec().readExtensions))
        #expect(workspace.placesExtensions.isSuperset(of: ["png", "jpg", "jpeg"]))
        #expect(!workspace.hasDocument)
    }

    @Test func everyTypePhotoPlacesIsPlacedByTheDropRule() throws {
        var workspace = try openedImage()
        workspace.readImages(with: AllReadingCodec())
        let actions = DropPlan.plan(workspace.placesExtensions.sorted().map { "/in/f.\($0)" }, into: "photo", hasDocument: true,
                                    places: workspace.placesExtensions, readers: { workspace.readers(ofExtension: $0) })
        for action in actions { if case .place = action {} else { Issue.record("advertised but not placed: \(action)") } }
    }

    @Test func aDropOnlyTakesWhatTheCodecReads() {
        var workspace = PhotoWorkspace(services: .fake)
        workspace.readImages(with: RawCodec())
        #expect(workspace.placesExtensions == ["png", "jpg", "jpeg"], "a drop took a type the codec can't read")
    }

    @Test func aPhotoLargerThanTheCanvasIsFittedAndCentred() throws {
        let big = try redPNG("Big.png", in: tempFolder(), width: 40, height: 20)
        var workspace = try openedImage()
        try workspace.perform([.place(path: big)])
        let layer = try #require(workspace.selectedLayer)
        #expect(layer.name == "Big")
        #expect(workspace.pixels[layer.id]?.width == 4 && workspace.pixels[layer.id]?.height == 2, "placed at \(String(describing: workspace.pixels[layer.id]?.width)), not fitted to 4 x 3")
        #expect(layer.offsetX == 0 && layer.offsetY == 0, "not centred: \(layer.offsetX), \(layer.offsetY)")
        #expect(workspace.statusMessage == "Placed at 10%.")
        workspace.undo()
        #expect(workspace.layers.count == 1)
    }

    @Test func aSmallPhotoIsNeverUpscaled() throws {
        let small = try redPNG("Small.png", in: tempFolder(), width: 2, height: 2)
        var workspace = try openedImage()
        try workspace.perform([.place(path: small)])
        #expect(workspace.selectedLayerID.flatMap { workspace.pixels[$0]?.width } == 2)
        #expect(workspace.statusMessage != "Placed at 100%.")
    }

    @Test func aHandedOverDropReadsOnlyItsBytes() throws {
        let folder = try tempFolder()
        let onDisk = try redPNG("Disk.png", in: folder)
        let bytes = try Data(contentsOf: URL(fileURLWithPath: try redPNG("Given.png", in: folder)))
        var workspace = try openedImage()
        workspace.receiveDropped(["/elsewhere/Given.png": bytes])
        try workspace.perform([.place(path: "/elsewhere/Given.png")])
        #expect(workspace.selectedLayer?.name == "Given")
        #expect(throws: CatalogError.self, "a handed-over drop read the disk") { try workspace.perform([.place(path: onDisk)]) }
    }

    @Test func aPNGOnAnOpenImagePlacesOneLayerInOneStep() throws {
        let logo = try redPNG("Logo.png", in: tempFolder())
        var workspace = try openedImage()
        let before = workspace.layers.count
        try workspace.perform([.place(path: logo)])
        #expect(workspace.layers.count == before + 1)
        #expect(workspace.selectedLayer?.name == "Logo")
        #expect(workspace.selectedLayer?.offsetX == 1 && workspace.selectedLayer?.offsetY == 0, "not centred on the 4 x 3 image")
        #expect(workspace.undoActionName == "Undo Place")
        #expect(workspace.takeFileRequests().isEmpty, "a placed image was also opened")
        workspace.undo()
        #expect(workspace.layers.count == before)
    }

    @Test func twoImagesInOneDropAreOneStep() throws {
        let folder = try tempFolder()
        var workspace = try openedImage()
        try workspace.perform([.place(path: redPNG("A.png", in: folder)), .place(path: redPNG("B.png", in: folder))])
        #expect(workspace.layers.count == 3)
        workspace.undo()
        #expect(workspace.layers.count == 1, "the drop took more than one Undo")
    }

    @Test func anUnreadableImageChangesNothing() throws {
        var workspace = try openedImage()
        #expect(throws: CatalogError.self) { try workspace.perform([.place(path: "/nowhere/Logo.png")]) }
        #expect(workspace.layers.count == 1)
        #expect(workspace.undoActionName != "Undo Place")
    }

    @Test func dropPlansFollowTheSuiteRule() throws {
        let open = try openedImage()
        let empty = PhotoWorkspace(services: .fake)
        let plan = { (target: PhotoWorkspace, path: String) in
            DropPlan.plan([path], into: target.appID, hasDocument: target.hasDocument,
                          places: target.placesExtensions, readers: { target.readers(ofExtension: $0) })
        }
        #expect(plan(open, "/w/Logo.png") == [.place(path: "/w/Logo.png")])
        #expect(plan(empty, "/w/Logo.png") == [.open(path: "/w/Logo.png")])
        #expect(plan(open, "/w/Intro.halo") == [.handOff(path: "/w/Intro.halo", app: "halo")])
        #expect(plan(open, "/w/Art.ora") == [.open(path: "/w/Art.ora")])
    }

    @Test func opensAndHandOffsAreRequestsForTheWindow() throws {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.perform([.open(path: "/w/Logo.png"), .handOff(path: "/w/Intro.halo", app: "halo"),
                               .refuse(path: "/w/a.zip", reason: "AfterGlow can't open .zip files.")])
        #expect(workspace.takeFileRequests() == [.open(path: "/w/Logo.png"), .handOff(path: "/w/Intro.halo", app: "halo")])
        #expect(workspace.takeFileRequests().isEmpty)
        #expect(workspace.statusMessage == "AfterGlow can't open .zip files.")
    }

    @Test func openInOffersLibraryForAnImage() throws {
        var workspace = try openedImage()
        #expect(workspace.openInApps.contains("library"))
        #expect(!workspace.openInApps.contains("photo"))
        #expect(workspace.openInHelp == "Save Sunset.png first.")
        workspace.updateFileFlow(recents: [], documentPath: "/w/Sunset.png")
        #expect(workspace.openInHelp == nil)
        try workspace.openIn("library")
        #expect(workspace.takeFileRequests() == [.handOff(path: "/w/Sunset.png", app: "library")])
        #expect(PhotoWorkspace(services: .fake).openInHelp == "Open an image first.")
    }

    @Test func openInGetsTheOpenImageOnceItHasAPath() throws {
        var workspace = try openedImage()
        #expect(workspace.suiteDocument == nil, "an unsaved image went to Open In")
        workspace.updateFileFlow(recents: [], documentPath: "/w/Sunset.png")
        let ref = try #require(workspace.suiteDocument)
        #expect(ref == SuiteDocumentRef(path: "/w/Sunset.png", fileID: SuiteDocumentRef.fileID(forPath: "/w/Sunset.png"),
                                        app: .photo, type: .png, displayName: "Sunset.png"))
        workspace.updateFileFlow(recents: [], documentPath: "/w/notes.txt")
        #expect(workspace.suiteDocument == nil, "a type the suite doesn't know went to Open In")
        var closed = PhotoWorkspace(services: .fake)
        closed.updateFileFlow(recents: [], documentPath: "/w/Sunset.png")
        #expect(closed.suiteDocument == nil, "Open In got a document with no image open")
    }

    @Test func hostAcceptsOpenNewAndPlace() async throws {
        let workspace = try openedImage()
        for verb in [HandOffVerb.open, .new, .place] {
            #expect(await workspace.refusal(for: handOff(verb)) == nil)
            #expect(try await workspace.accept(handOff(verb)) == .accepted)
        }
        #expect(await workspace.refusal(for: handOff(.importAnimation)) != nil)
        await #expect(throws: SuiteError.self) { _ = try await workspace.accept(handOff(.edit)) }
    }

    @Test func recentsListAndClear() throws {
        let folder = try tempFolder()
        let here = try redPNG("Here.png", in: folder)
        let entry = { (path: String) in
            RecentFileEntry(fileID: SuiteDocumentRef.fileID(forPath: path), name: "x.png", path: path, app: "photo",
                            lastUsed: Date(timeIntervalSince1970: 0))
        }
        var workspace = PhotoWorkspace(services: .fake)
        workspace.updateFileFlow(recents: [entry(here), entry("/nowhere/Gone.png")], documentPath: nil)
        #expect(workspace.recentFiles.map(\.path) == [here, "/nowhere/Gone.png"])
        try workspace.openRecent(entry(here).fileID)
        #expect(throws: CatalogError.self) { try workspace.openRecent(entry("/nowhere/Gone.png").fileID) }
        #expect(workspace.recentFiles.map(\.path) == [here], "a missing file stayed in the list")
        #expect(workspace.takeFileRequests() == [.open(path: here), .forget(fileID: entry("/nowhere/Gone.png").fileID)])
    }

    @Test func clearRecentEmptiesTheList() throws {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.clearRecent()
        #expect(workspace.recentFiles.isEmpty)
        #expect(workspace.takeFileRequests() == [.clearRecent])
    }

    @Test func theOldSavedListIsImportedOnceIntoATempStore() async throws {
        let recents = StoreRecents(store: FileStore(folder: try tempFolder().path))
        var stored: [String]? = ["/w/b.png", "/w/a.png", "/w/notes.txt"]
        for round in 0..<2 {
            let refs = PhotoWorkspace.takeOldRecents(&stored)
            if round == 1 { #expect(refs.isEmpty, "the old list was imported twice") }
            for (i, ref) in refs.enumerated() {
                try await recents.note(ref, event: .opened, at: Date(timeIntervalSince1970: Double(i)), thumbnail: nil)
            }
        }
        #expect(stored == nil)
        let items = try await recents.list().items
        #expect(items.map(\.ref.path) == ["/w/b.png", "/w/a.png"])
        #expect(items.allSatisfy { $0.ref.app == .photo && $0.ref.type == .png })
    }

    /// RJ-P42 on Linux: the job's steps on a headless workspace, each drop's bytes handed over first.
    @Test func dropLayerRealJobPasses() throws {
        let folder = PhotoJob.root.appendingPathComponent("drop-layer")
        let script = try JSONDecoder().decode(DropJob.self, from: Data(contentsOf: folder.appendingPathComponent("drop-layer.jobs.json")))
        var workspace = try PhotoHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/sunset.png")), name: "sunset.png").workspace
        var counts: [Int] = []
        for step in script.steps {
            var params = step.params
            if case .object(var fields) = params, case .array(let paths)? = fields["paths"] {
                let full = paths.compactMap { if case .string(let p) = $0 { folder.appendingPathComponent(p).path } else { nil } }
                fields["paths"] = .array(full.map(JSONValue.string))
                params = .object(fields)
                // A headless workspace places only what its host handed over, as the CLI's DropFiles does.
                workspace.receiveDropped(try Dictionary(uniqueKeysWithValues: full.map { ($0, try Data(contentsOf: URL(fileURLWithPath: $0))) }))
            }
            _ = try PhotoWorkspace.catalog.run(step.id, params: params, on: &workspace)
            counts.append(workspace.layers.count)
        }
        #expect(counts == [2, 1, 2])
        #expect(workspace.selectedLayer?.name == "logo")
        let data = try #require(try PhotoHeadless(workspace: workspace).export("png", options: .object([:])).first?.data)
        let got = try CoreRasterImageCodec().decode(data, longestSide: nil)
        let want = try CoreRasterImageCodec().decode(Data(contentsOf: folder.appendingPathComponent("expected/drop-layer.png")), longestSide: nil)
        #expect(got.width == want.width && got.height == want.height)
        let worst = zip(got.rgba8, want.rgba8).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= 2, "a channel is off by \(worst)")
    }
}

/// The parts of drop-layer.jobs.json the walk runs.
private struct DropJob: Decodable { var steps: [CommandEnvelope] }

/// A codec that claims every image extension, so the drop rule decides what Photo can place.
private struct AllReadingCodec: PhotoImageCodec {
    var readExtensions: Set<String> { ["png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "psd"] }
    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage { try CoreRasterImageCodec().decode(data, longestSide: longestSide) }
    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        try CoreRasterImageCodec().encode(image, as: format, quality: quality)
    }
}
