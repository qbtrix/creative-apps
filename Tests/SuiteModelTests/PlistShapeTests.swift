// PlistShapeTests.swift: Bundle/Info/AfterGlow.plist declares every suite
// document type (Editor; Owner for the suite's formats, Alternate for images),
// exports the suite's types and needs macOS 26. The plist is read by path and
// decoded with Foundation's PropertyListSerialization, so this runs on Linux.
// The expected values are a literal table (docs/blueprints/suite.md 2.6), not
// the registry, so a registry edit can't silently move the plist with it.
// Type names are the exception: they must equal SuiteTypeRegistry's (#2050).
import Foundation
import SuiteModel
import Testing

@Suite struct PlistShapeTests {
    struct DocType: Hashable {
        var uti: String
        var rank: String
        var extensions: [String]
    }

    static let documentTypes: Set<DocType> = [
        DocType(uti: "org.creativesuite.flare.animation", rank: "Owner", extensions: ["flare"]),
        DocType(uti: "org.creativesuite.design.document", rank: "Owner", extensions: ["design"]),
        DocType(uti: "org.creativesuite.halo.project", rank: "Owner", extensions: ["halo"]),
        DocType(uti: "org.creativesuite.photo.openraster", rank: "Owner", extensions: ["ora"]),
        DocType(uti: "public.png", rank: "Alternate", extensions: ["png"]),
        DocType(uti: "public.jpeg", rank: "Alternate", extensions: ["jpg", "jpeg"]),
        DocType(uti: "public.heic", rank: "Alternate", extensions: ["heic"]),
    ]

    /// Exported id to its file extensions; pasteboard-only ids have none.
    static let exportedTypes: [String: [String]] = [
        "org.creativesuite.flare.animation": ["flare"],
        "org.creativesuite.design.document": ["design"],
        "org.creativesuite.halo.project": ["halo"],
        "org.creativesuite.photo.openraster": ["ora"],
        "org.creativesuite.suite.handoff": ["aghandoff"],
        "org.creativesuite.suite.asset": [],
        "org.creativesuite.design.layers": [],
        "org.creativesuite.flare.layers": [],
    ]

    static func plist() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // SuiteModelTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Bundle/Info/AfterGlow.plist")
        let data = try Data(contentsOf: url)
        let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try #require(value as? [String: Any])
    }

    @Test func bundleIdentifierAndIcon() throws {
        let p = try Self.plist()
        #expect(p["CFBundleIdentifier"] as? String == "org.creativesuite.afterglow")
        #expect(p["CFBundleIconFile"] as? String == "AfterGlow")
        #expect(p["CFBundlePackageType"] as? String == "APPL")
    }

    @Test func minimumSystemVersion() throws {
        #expect(try Self.plist()["LSMinimumSystemVersion"] as? String == "26.0")
    }

    @Test func documentTypesAreExactlyTheSeven() throws {
        let raw = try #require(try Self.plist()["CFBundleDocumentTypes"] as? [[String: Any]])
        #expect(raw.count == 7)
        var found: Set<DocType> = []
        for entry in raw {
            #expect(entry["CFBundleTypeRole"] as? String == "Editor")
            let utis = entry["LSItemContentTypes"] as? [String] ?? []
            #expect(utis.count == 1)
            found.insert(DocType(uti: utis.first ?? "",
                                 rank: entry["LSHandlerRank"] as? String ?? "",
                                 extensions: entry["CFBundleTypeExtensions"] as? [String] ?? []))
        }
        #expect(found == Self.documentTypes)
    }

    @Test func imagesAreNeverOwner() throws {
        let raw = try #require(try Self.plist()["CFBundleDocumentTypes"] as? [[String: Any]])
        let images: Set<String> = ["public.png", "public.jpeg", "public.heic"]
        let imageRanks = raw.compactMap { entry -> String? in
            let utis = entry["LSItemContentTypes"] as? [String] ?? []
            return utis.contains(where: images.contains) ? entry["LSHandlerRank"] as? String : nil
        }
        #expect(imageRanks == ["Alternate", "Alternate", "Alternate"])
    }

    @Test func exportedTypesAreExactlyTheSuiteSet() throws {
        let raw = try #require(try Self.plist()["UTExportedTypeDeclarations"] as? [[String: Any]])
        var found: [String: [String]] = [:]
        for entry in raw {
            let id = try #require(entry["UTTypeIdentifier"] as? String)
            #expect(found[id] == nil, "\(id) declared twice")
            let tags = entry["UTTypeTagSpecification"] as? [String: Any]
            found[id] = tags?["public.filename-extension"] as? [String] ?? []
            #expect((entry["UTTypeConformsTo"] as? [String])?.isEmpty == false, "\(id) conforms to nothing")
        }
        #expect(found == Self.exportedTypes)
        #expect(try Self.plist()["UTImportedTypeDeclarations"] == nil)
    }

    /// Every (UTI, type name) pair in a plist: exported and imported
    /// UTTypeDescription and each document type's CFBundleTypeName.
    static func typeNames(_ plist: [String: Any]) -> [(uti: String, name: String)] {
        var pairs: [(uti: String, name: String)] = []
        for key in ["UTExportedTypeDeclarations", "UTImportedTypeDeclarations"] {
            for entry in plist[key] as? [[String: Any]] ?? [] {
                pairs.append((entry["UTTypeIdentifier"] as? String ?? "", entry["UTTypeDescription"] as? String ?? ""))
            }
        }
        for entry in plist["CFBundleDocumentTypes"] as? [[String: Any]] ?? [] {
            let name = entry["CFBundleTypeName"] as? String ?? ""
            for uti in entry["LSItemContentTypes"] as? [String] ?? [] { pairs.append((uti, name)) }
        }
        return pairs
    }

    static func plist(named name: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Bundle/Info/\(name).plist")
        let value = try PropertyListSerialization.propertyList(from: try Data(contentsOf: url), format: nil)
        return try #require(value as? [String: Any])
    }

    /// #2050: a UTI has one name across all six plists, and it is the
    /// registry's name wherever SuiteTypeRegistry lists that UTI.
    @Test func typeNamesMatchTheRegistryInEveryPlist() throws {
        var seen: [String: String] = [:]
        for file in ["AfterGlow"] + BundleLayout.apps {
            for pair in Self.typeNames(try Self.plist(named: file)) {
                #expect(!pair.name.isEmpty, "\(file): \(pair.uti) has no name")
                if let registered = SuiteTypeRegistry.standard.type(SuiteTypeID(rawValue: pair.uti)) {
                    #expect(pair.name == registered.name, "\(file): \(pair.uti) is \(pair.name)")
                }
                if let first = seen[pair.uti] {
                    #expect(pair.name == first, "\(file): \(pair.uti) is \(pair.name), elsewhere \(first)")
                } else {
                    seen[pair.uti] = pair.name
                }
            }
        }
        #expect(seen.count == 11)   // seven document types plus the four declared-only ids
    }
}
