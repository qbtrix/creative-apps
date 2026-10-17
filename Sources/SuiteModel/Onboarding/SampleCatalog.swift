// SampleCatalog.swift: the one sample per app the tour can open (onboarding
// packet, OB-1 stub, OB-10 body): where the bundle keeps them, why one can't
// open, where a copy lands and the ref of that copy. Linux-safe, Sendable.

/// One sample per app, shipped under the bundle's Resources/Samples.
public struct SampleCatalog: Sendable {
    /// One per app: Bounce.flare, Cards.design, beach.ora (Photo), Sunset.png (Library, imported), Intro.halo.
    public static let samples: [SampleFile] = [
        SampleFile(app: .flare, fileName: "Bounce.flare", type: .flareAnimation, title: "Bounce"),
        SampleFile(app: .design, fileName: "Cards.design", type: .designDocument, title: "Cards"),
        SampleFile(app: .photo, fileName: "beach.ora", type: .photoOpenRaster, title: "beach"),
        SampleFile(app: .library, fileName: "Sunset.png", type: .png, title: "Sunset"),
        SampleFile(app: .halo, fileName: "Intro.halo", type: .haloProject, title: "Intro"),
    ]
    public static func sample(for app: SuiteApp) -> SampleFile? { samples.first { $0.app == app } }
    /// The folder the bundle copies Bundle/Samples/ to: <resources>/Samples.
    public static func folder(resources: String) -> String { resources + "/Samples" }
    /// "The <App> sample isn't in this build." when `present` says the file isn't there; nil otherwise (OB-10).
    public static func reason(for s: SampleFile, folder: String, present: (String) -> Bool) -> String? { nil }
    /// Where the copy lands: <documents>/Samples/<fileName>; OB-10 adds "<stem> 2.<ext>" while taken.
    public static func destination(for s: SampleFile, documents: String, exists: (String) -> Bool) -> String {
        documents + "/Samples/" + s.fileName
    }
    /// The document ref of a copy at `path`.
    public static func ref(for s: SampleFile, path: String) -> SuiteDocumentRef {
        SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: s.app, type: s.type,
                         displayName: path.split(separator: "/").last.map(String.init) ?? s.fileName)
    }
}
