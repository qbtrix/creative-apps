// DropPlan.swift (file-flow SF-1 stub, SF-5 body): what an app does with each file dropped on it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One dropped file's fate in the app it was dropped on.
public enum DropAction: Hashable, Codable, Sendable {
    /// This app's own document: a window for it.
    case open(path: String)
    /// Content this app takes into the open document (one "Place" step).
    case place(path: String)
    /// Another app's document: that app opens it.
    case handOff(path: String, app: String)
    /// Nothing opens it, and why in words.
    case refuse(path: String, reason: String)

    /// The file the action is for.
    public var path: String {
        switch self {
        case .open(let path), .place(let path), .handOff(let path, _), .refuse(let path, _): path
        }
    }
}

/// The drop rule every app and the CLI share.
public enum DropPlan {
    /// One action per path, in order. `readers(ext)` is the apps that read an extension, default first
    /// (DocumentRouting's answer); `places` the extensions this app takes into an open document.
    /// A folder stands for the files directly in it, in name order; its subfolders are skipped.
    public static func plan(_ paths: [String], into app: String, hasDocument: Bool, places: Set<String>,
                            readers: (String) -> [String]) -> [DropAction] {
        expanded(paths).map { action(for: $0, into: app, hasDocument: hasDocument, places: places, readers: readers) }
    }

    /// The rule for one file. A type only this app reads is its own document and opens, even into an open
    /// document; content this app places goes into an open document; a type this app reads opens; another
    /// app's goes to its default app; a type no app reads is refused, unless this app places it into an open document.
    static func action(for path: String, into app: String, hasDocument: Bool, places: Set<String>,
                       readers: (String) -> [String]) -> DropAction {
        let ext = fileExtension(path)
        let apps = readers(ext)
        guard let first = apps.first else {
            // A type no suite row lists but this app's codec reads (.psd in Photo) still goes into an open document.
            if places.contains(ext) && hasDocument { return .place(path: path) }
            return .refuse(path: path, reason: "AfterGlow can't open .\(ext) files.")
        }
        if apps == [app] { return .open(path: path) }
        if hasDocument && places.contains(ext) { return .place(path: path) }
        if apps.contains(app) { return .open(path: path) }
        return .handOff(path: path, app: first)
    }

    /// The extension, lowercased; "" for none.
    static func fileExtension(_ path: String) -> String {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return String(name[name.index(after: dot)...]).lowercased()
    }

    /// Lists a folder without asking fileExists(atPath:isDirectory:), so this reads the same on Linux and
    /// macOS: a path whose contents can be listed is a folder.
    private static func expanded(_ paths: [String]) -> [String] {
        let files = FileManager.default
        return paths.flatMap { path -> [String] in
            guard let names = try? files.contentsOfDirectory(atPath: path) else { return [path] }
            let base = path.hasSuffix("/") ? path : path + "/"
            return names.filter { !$0.hasPrefix(".") }.sorted().map { base + $0 }
                .filter { (try? files.contentsOfDirectory(atPath: $0)) == nil }
        }
    }
}
