// LibraryCatalogFilesJobTests.swift (catalog-files LC-7): the jobs' steps on real files, on Linux. RJ-L50 and RJ-L52
// stay pending #3741, since the CLI keeps file commands window-only and its .library input has no files on disk;
// RJ-L51 runs in the CLI too, and here its remove is checked against a 10-photo folder that must keep every file.
// Each job's relative paths are resolved under a fresh temp folder.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryCatalogFilesJobTests {
    static let jobs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/library")
    static let oct21 = Date(timeIntervalSince1970: 1_792_584_000)

    struct Script<Expect: Decodable>: Decodable { var steps: [CommandEnvelope]; var expect: Expect }

    static func script<E: Decodable>(_ job: String, _: E.Type) throws -> Script<E> {
        try JSONDecoder().decode(Script<E>.self, from: Data(contentsOf: jobs.appendingPathComponent("\(job)/\(job).jobs.json")))
    }

    static func temp() throws -> String {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CatalogFilesJob-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        return root
    }

    static func write(_ text: String, to path: String) throws {
        let folder = String(path[..<(path.lastIndex(of: "/") ?? path.endIndex)])
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
    }

    /// `params` with each string under `keys` put under `root`.
    static func rooted(_ params: JSONValue, _ root: String, _ keys: Set<String>) -> JSONValue {
        guard case .object(var fields) = params else { return params }
        for (key, value) in fields where keys.contains(key) {
            if case .string(let path) = value { fields[key] = .string(root + "/" + path) }
        }
        return .object(fields)
    }

    /// Scans the files under a folder as photos captured on 2026-10-21.
    struct CardDecoder: PhotoDecoding {
        func scan(folder: String) async throws -> FolderScan {
            let names = FileManager.default.subpaths(atPath: folder) ?? []
            let candidates = names.sorted().filter { $0.hasSuffix(".jpg") }.map {
                ImportCandidate(path: folder + "/" + $0, captureDate: LibraryCatalogFilesJobTests.oct21,
                                pixelSize: PixelSize(width: 4, height: 3), kind: .jpeg)
            }
            return FolderScan(candidates: candidates, failures: [])
        }
        func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage { throw LibraryError.missingFile(path) }
    }

    struct CopyExpect: Decodable {
        struct Dated: Decodable { var files: [String], photos: Int, onCard: Int }
        var dated: [String: Dated]
        init(from decoder: any Decoder) throws { dated = try [String: Dated](from: decoder) }
    }

    @Test func copyOnImportJob() async throws {
        let script = try Self.script("copy-on-import", CopyExpect.self)
        let step = try #require(script.steps.first), root = try Self.temp()
        let card = root + "/input/card"
        for (path, bytes) in ["100/IMG_0001.jpg": "first", "100/IMG_0002.jpg": "second",
                              "101/IMG_0001.jpg": "third, longer", "101/IMG_0003.jpg": "fourth"] {
            try Self.write(bytes, to: card + "/" + path)
        }
        var catalog = LibraryCatalog(services: .live(decoder: CardDecoder(), writer: FakeJPEGWriter(), store: FakeCatalogStore()))
        let params = Self.rooted(step.params, root, ["folder", "copyTo"])
        _ = try LibraryCatalog.catalog.run(step.id, params: params, on: &catalog)
        let importer = catalog.services.importer.copying(catalog.importCopy)
        let result = try await importer.importFolder(card, known: [], progress: { _ in }, added: { _ in })
        catalog.finishImport(result, folder: "card")
        try FileManager.default.removeItem(atPath: card)

        let (folder, want) = try #require(script.expect.dated.first)
        let dated = root + "/" + folder
        #expect(try FileManager.default.contentsOfDirectory(atPath: dated).sorted() == want.files)
        #expect(catalog.items.count == want.photos)
        #expect(catalog.items.filter { $0.path?.hasPrefix(card) == true }.count == want.onCard)
        #expect(catalog.items.allSatisfy { FileManager.default.fileExists(atPath: $0.path ?? "") })
        let twins = [dated + "/IMG_0001.jpg", dated + "/IMG_0001 2.jpg"].map { FileManager.default.contents(atPath: $0) }
        #expect(Set(twins.compactMap { $0 }).count == 2, "a duplicate name overwrote the first copy")
    }

    @Test func removeKeepsTheFilesJob() throws {
        let script = try Self.script("remove-keep-files", JSONValue.self)
        let root = try Self.temp()
        let photos = try ["beach", "dock", "fog", "pier", "reef", "sand", "surf", "tide", "wave", "wind"].map { name in
            let path = root + "/" + name + ".jpg"
            try Self.write(name, to: path)
            return PhotoItem(id: name, name: name, captureDate: Self.oct21, color: Color3(0.5, 0.5, 0.5), path: path)
        }
        var catalog = LibraryCatalog()
        catalog.restore(photos)
        for step in script.steps {
            _ = try LibraryCatalog.catalog.run(step.id, params: step.params, on: &catalog)
            if step.id == "photo.remove-from-catalog" { #expect(catalog.items.count == 7) }
            #expect(photos.allSatisfy { FileManager.default.fileExists(atPath: $0.path ?? "") }, "\(step.id) deleted a file")
        }
        #expect(catalog.items.map(\.id) == photos.map(\.id))
        #expect(catalog.items.filter { $0.rating == 3 }.map(\.id) == ["beach", "dock", "fog"])
    }

    struct RelinkExpect: Decodable {
        struct Catalog: Decodable { var relinkedUnder: String, relinked: Int, stillMissing: [String] }
        var catalog: Catalog
        enum CodingKeys: String, CodingKey { case catalog = "out/shoot-catalog.json" }
    }

    @Test func relinkFolderJob() throws {
        let script = try Self.script("relink-folder", RelinkExpect.self)
        let step = try #require(script.steps.first), root = try Self.temp(), want = script.expect.catalog
        let shoot = RelinkTests.missing(40, in: root + "/shoot")
        let decoy = PhotoItem(id: root + "/other/IMG_0001.jpg", name: "IMG_0001", captureDate: Self.oct21,
                              color: Color3(0.5, 0.5, 0.5), path: root + "/other/IMG_0001.jpg", availability: .missing)
        for photo in shoot { try Self.write(photo.name, to: root + "/moved/shoot/" + photo.name + ".jpg") }
        try Self.write("decoy", to: root + "/moved/other/IMG_0001.jpg")
        var catalog = LibraryCatalog()
        catalog.restore(shoot + [decoy])
        _ = try LibraryCatalog.catalog.run(step.id, params: Self.rooted(step.params, root, ["id", "file"]), on: &catalog)
        #expect(catalog.items.filter { $0.path?.hasPrefix(root + "/" + want.relinkedUnder) == true }.count == want.relinked)
        #expect(catalog.items.filter { $0.availability == .missing }.compactMap(\.path) == want.stillMissing.map { root + "/" + $0 })
    }
}
