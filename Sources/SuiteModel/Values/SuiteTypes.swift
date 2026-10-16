// SuiteTypes.swift: the suite's type ids and the one registry of document
// types: who owns each and who else opens it. Foundation free, Linux-safe,
// Sendable.

/// A uniform type identifier, as a string so the Model stays Linux-safe.
public struct SuiteTypeID: RawRepresentable, Hashable, Codable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let flareAnimation = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".flare.animation")
    public static let designDocument = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".design.document")
    public static let haloProject = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".halo.project")
    public static let photoOpenRaster = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".photo.openraster")
    public static let handOff = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".suite.handoff")
    public static let assetEnvelope = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".suite.asset")
    public static let designLayers = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".design.layers")
    public static let flareLayers = SuiteTypeID(rawValue: SuiteIdentity.prefix + ".flare.layers")
    public static let png = SuiteTypeID(rawValue: "public.png")
    public static let jpeg = SuiteTypeID(rawValue: "public.jpeg")
    public static let heic = SuiteTypeID(rawValue: "public.heic")
    public static let svg = SuiteTypeID(rawValue: "public.svg-image")
    public static let plainText = SuiteTypeID(rawValue: "public.utf8-plain-text")
    public static let fileURL = SuiteTypeID(rawValue: "public.file-url")
}

/// One file type the suite reads: who owns it and who else can open it.
public struct SuiteDocumentType: Hashable, Sendable {
    public var id: SuiteTypeID
    public var name: String              // "Flare Animation"; used in messages
    public var extensions: [String]      // lowercased, no dot
    public var owner: SuiteApp?          // Editor, rank Owner; nil for public types
    public var readers: [SuiteApp]       // Open In targets, default app first
    public init(id: SuiteTypeID, name: String, extensions: [String], owner: SuiteApp?, readers: [SuiteApp]) {
        self.id = id; self.name = name; self.extensions = extensions; self.owner = owner; self.readers = readers
    }
}

/// Every document type in the suite. `Bundle/Info/*.plist` mirror it: their
/// document types equal `standard`, and the exported types that are not
/// document types equal `declaredOnly`.
public struct SuiteTypeRegistry: Sendable {
    public var types: [SuiteDocumentType]
    public init(types: [SuiteDocumentType]) { self.types = types }

    public static let standard = SuiteTypeRegistry(types: [
        SuiteDocumentType(id: .flareAnimation, name: "Flare Animation", extensions: ["flare"],
                          owner: .flare, readers: [.flare]),   // flare-in-halo (FH-1) adds .halo
        SuiteDocumentType(id: .designDocument, name: "Design Document", extensions: ["design"],
                          owner: .design, readers: [.design]),
        SuiteDocumentType(id: .haloProject, name: "Halo Project", extensions: ["halo"],
                          owner: .halo, readers: [.halo]),
        SuiteDocumentType(id: .photoOpenRaster, name: "Photo Document", extensions: ["ora"],
                          owner: .photo, readers: [.photo]),
        SuiteDocumentType(id: .png, name: "PNG image", extensions: ["png"], owner: nil, readers: [.photo, .library]),
        SuiteDocumentType(id: .jpeg, name: "JPEG image", extensions: ["jpg", "jpeg"], owner: nil, readers: [.photo, .library]),
        SuiteDocumentType(id: .heic, name: "HEIC image", extensions: ["heic"], owner: nil, readers: [.photo, .library]),
    ])

    /// Types the plists export that no app opens as a document.
    public static let declaredOnly: [SuiteTypeID] = [.handOff, .assetEnvelope, .designLayers, .flareLayers]

    public func type(forExtension ext: String) -> SuiteDocumentType? {
        let e = ext.lowercased()
        return types.first { $0.extensions.contains(e) }
    }

    public func type(_ id: SuiteTypeID) -> SuiteDocumentType? { types.first { $0.id == id } }

    /// The app a routed open goes to: the owner, else the first reader.
    public func defaultApp(for id: SuiteTypeID) -> SuiteApp? {
        guard let t = type(id) else { return nil }
        return t.owner ?? t.readers.first
    }
}
