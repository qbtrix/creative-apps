// HaloFileFlow+Kernel.swift: Halo's adapter onto the suite's file flow
// (file-flow HF-1 stubs, HF-3 bodies). HaloProject is the FileFlowTarget the
// shared Open Recent, Clear Menu, Open In and drop commands run on. The
// SuiteDocumentHost the shell hands every hand-off to stays HaloDocumentHost
// (A-HA-1, #865): HaloProject is a value the window owns, so the host hands
// its command to the window instead of a second conformance here.
// Until HF-3 it names itself "halo", places nothing into a composition (image
// layers are S20, so an image goes to the app that reads it), has no suite
// recent files and no Open In readers, and Open Recent, Clear Menu, Open In
// and drop throw "not built". `suiteDocument` is the saved project as the
// suite names it, for File > Open In ▸. Linux-safe.
import SuiteKernel
import SuiteModel

extension HaloProject: FileFlowTarget {
    /// What a dropped image reads until image layers (S20) land.
    public static let imageRefusal = "Halo can't place images yet."

    public var appID: String { SuiteApp.halo.rawValue }
    public var recentFiles: [RecentFileEntry] { [] }
    /// A composition to take content; the drop rule reads it.
    public var hasDocument: Bool { selectedComposition != nil }
    public var placesExtensions: Set<String> { [] }
    public var openInApps: [String] { [] }
    public var openInHelp: String? { "Open In isn't built yet." }

    public func readers(ofExtension ext: String) -> [String] { [] }

    public mutating func openRecent(_ fileID: String) throws { throw Self.notBuilt("file.open-recent") }

    public mutating func clearRecent() throws { throw Self.notBuilt("file.clear-recent") }

    public mutating func openIn(_ app: String) throws { throw Self.notBuilt("file.open-in") }

    public mutating func perform(_ actions: [DropAction]) throws { throw Self.notBuilt("file.drop") }

    /// The saved project as the suite names it; nil before it has a path on disk.
    public var suiteDocument: SuiteDocumentRef? {
        guard let path = file.path else { return nil }
        let name = file.name ?? path.split(separator: "/").last.map(String.init) ?? path
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .halo,
                                type: .haloProject, displayName: name)
    }

    /// Halo's old Open Recent list (newest first) as suite refs, oldest first, emptying `stored` so a second
    /// call imports nothing. Until HF-3 it imports nothing and leaves the list.
    public static func takeOldRecents(_ stored: inout [HaloRecentFile]?) -> [SuiteDocumentRef] { [] }

    static func notBuilt(_ id: String) -> CatalogError { .notBuilt(id: id, feature: "file-flow") }
}
