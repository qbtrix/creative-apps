// PlistShapeAppsTests.swift: the five app plists in Bundle/Info/ against a
// literal table (docs/blueprints/suite.md 2.6; bundle packet BU-5b). Each app
// has its own bundle id and icon, is Owner (Editor) of its own format only,
// Photo and Library read the three image types as Alternate, and every app
// opens the hand-off type as Viewer. Reads the XML with PropertyListSerialization.
import Foundation
import SuiteModel
import Testing

@Suite struct PlistShapeAppsTests {
    /// One app's expected plist: bundle id, icon, owned type and the types it reads.
    struct Row: Sendable, CustomTestStringConvertible {
        var name: String
        var bundleID: String
        var owns: String?
        var imageRole: String?          // the role it reads png, jpeg and heic with; nil for none
        var testDescription: String { name }
    }

    static let handOff = "org.creativesuite.suite.handoff"
    static let images = ["public.png", "public.jpeg", "public.heic"]
    static let owned = ["org.creativesuite.flare.animation", "org.creativesuite.design.document",
                        "org.creativesuite.photo.openraster", "org.creativesuite.halo.project"]

    static let rows: [Row] = [
        Row(name: "Flare", bundleID: "org.creativesuite.flare", owns: "org.creativesuite.flare.animation"),
        Row(name: "Design", bundleID: "org.creativesuite.design", owns: "org.creativesuite.design.document"),
        Row(name: "Photo", bundleID: "org.creativesuite.photo", owns: "org.creativesuite.photo.openraster",
            imageRole: "Editor"),
        Row(name: "Library", bundleID: "org.creativesuite.library", owns: nil, imageRole: "Viewer"),
        Row(name: "Halo", bundleID: "org.creativesuite.halo", owns: "org.creativesuite.halo.project"),
    ]

    static func plist(_ name: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Bundle/Info/\(name).plist")
        let data = try Data(contentsOf: url)
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(value as? [String: Any])
    }

    /// (content type, role, rank) for every document type entry.
    static func documentTypes(_ plist: [String: Any]) -> [(type: String, role: String, rank: String)] {
        let entries = plist["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        return entries.flatMap { entry in
            let types = entry["LSItemContentTypes"] as? [String] ?? []
            let role = entry["CFBundleTypeRole"] as? String ?? ""
            let rank = entry["LSHandlerRank"] as? String ?? ""
            return types.map { (type: $0, role: role, rank: rank) }
        }
    }

    @Test(arguments: rows) func identity(_ row: Row) throws {
        let p = try Self.plist(row.name)
        #expect(p["CFBundleIdentifier"] as? String == row.bundleID)
        #expect(p["CFBundleIconFile"] as? String == row.name)
        #expect(p["LSMinimumSystemVersion"] as? String == "26.0")
        #expect(p["CFBundlePackageType"] as? String == "APPL")
    }

    @Test(arguments: rows) func ownerOfItsOwnFormatOnly(_ row: Row) throws {
        let types = Self.documentTypes(try Self.plist(row.name))
        let owners = types.filter { $0.rank == "Owner" }
        #expect(owners.map(\.type) == (row.owns.map { [$0] } ?? []))
        #expect(owners.allSatisfy { $0.role == "Editor" })
        let othersFormats = Set(Self.owned).subtracting(row.owns.map { [$0] } ?? [])
        #expect(types.filter { othersFormats.contains($0.type) }.isEmpty, "\(row.name) claims another app's format")
    }

    @Test(arguments: rows) func readsImagesAsAlternateOnlyWhereListed(_ row: Row) throws {
        let types = Self.documentTypes(try Self.plist(row.name))
        let images = types.filter { Self.images.contains($0.type) }
        if let role = row.imageRole {
            #expect(images.map(\.type).sorted() == Self.images.sorted())
            #expect(images.allSatisfy { $0.rank == "Alternate" && $0.role == role })
        } else {
            #expect(images.isEmpty)
        }
    }

    @Test(arguments: rows) func opensTheHandOffAsViewer(_ row: Row) throws {
        let types = Self.documentTypes(try Self.plist(row.name))
        let handOff = types.filter { $0.type == Self.handOff }
        #expect(handOff.count == 1)
        #expect(handOff.allSatisfy { $0.role == "Viewer" && $0.rank != "Owner" })
    }

    @Test(arguments: rows) func declaresNoTypeBeyondTheTable(_ row: Row) throws {
        let types = Set(Self.documentTypes(try Self.plist(row.name)).map(\.type))
        var expected: Set<String> = [Self.handOff]
        if let own = row.owns { expected.insert(own) }
        if row.imageRole != nil { expected.formUnion(Self.images) }
        #expect(types == expected)
    }

    /// #2051: the plist names the executable BundleLayout puts in Contents/MacOS.
    @Test(arguments: BundleLayout.apps) func executableMatchesTheLayout(_ name: String) throws {
        let path = BundleLayout.executablePath(ofApp: name)
        let expected = try #require(path.split(separator: "/").last.map(String.init))
        #expect(try Self.plist(name)["CFBundleExecutable"] as? String == expected)
    }
}
