// SampleCatalog.swift: the one sample per app the tour can open (onboarding
// packet, OB-1 stub, OB-10 body): where the bundle keeps them, why one can't
// open, where a copy lands and the ref of that copy. Linux-safe, Sendable.

/// One sample per app, shipped under the bundle's Resources/Samples.
public struct SampleCatalog: Sendable {
    /// One per app: Bounce.flare, Cards.design, beach.ora (Photo), Sunset.png (Library, imported), Intro.halo.
    public static let samples: [SampleFile] = [
        SampleFile(app: .flare, fileName: "Bounce.flare", type: .flareAnimation, title: "Bounce"),
        SampleFile(app: .design, fileName: "Cards.design", type: .designDocument, title: "Cards"),
        SampleFile(app: .photo, fileName: "beach.ora", type: .photoOpenRaster, title: "Beach"),
        SampleFile(app: .library, fileName: "Sunset.png", type: .png, title: "Sunset"),
        SampleFile(app: .halo, fileName: "Intro.halo", type: .haloProject, title: "Intro"),
    ]
    public static func sample(for app: SuiteApp) -> SampleFile? { samples.first { $0.app == app } }
    /// The folder the bundle copies Bundle/Samples/ to: <resources>/Samples.
    public static func folder(resources: String) -> String { resources + "/Samples" }
    /// "The <App> sample isn't in this build." when `present` says the file isn't there; nil otherwise (OB-10).
    public static func reason(for s: SampleFile, folder: String, present: (String) -> Bool) -> String? {
        if present(folder + "/" + s.fileName) { return nil }
        return "The \(s.app.displayName) sample isn't in this build."
    }
    /// Where the copy lands: <documents>/Samples/<fileName>, or "<stem> 2.<ext>", "<stem> 3.<ext>" while
    /// taken. Never an existing path: a copy never overwrites. The names come from UniqueFileNames, the one
    /// suffix rule: each name `exists` reports joins the taken set, compared ignoring case, then the next is asked.
    /// Nil once `maxTries` names are all taken, so a folder that answers yes to every name can't hang the caller.
    public static func destination(for s: SampleFile, documents: String, exists: (String) -> Bool) -> String? {
        let folder = documents + "/Samples/"
        let (stem, ext) = split(s.fileName)
        var taken: Set<String> = []
        for _ in 0..<maxTries {
            let name = UniqueFileNames.name(stem, extension: ext, among: taken)
            guard exists(folder + name) else { return folder + name }
            taken.insert(name)
        }
        return nil
    }
    /// How many names `destination` asks about before it gives up.
    public static let maxTries = 1000
    /// "Bounce.flare" → ("Bounce", "flare"); a name with no dot (or only a leading one) has no extension.
    private static func split(_ name: String) -> (stem: String, ext: String) {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return (name, "") }
        return (String(name[..<dot]), String(name[name.index(after: dot)...]))
    }
    /// The document ref of a copy at `path`.
    public static func ref(for s: SampleFile, path: String) -> SuiteDocumentRef {
        SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: s.app, type: s.type,
                         displayName: path.split(separator: "/").last.map(String.init) ?? s.fileName)
    }
}
