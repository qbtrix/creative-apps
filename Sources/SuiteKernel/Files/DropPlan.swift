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
    public static func plan(_ paths: [String], into app: String, hasDocument: Bool, places: Set<String>,
                            readers: (String) -> [String]) -> [DropAction] {
        paths.map { .refuse(path: $0, reason: "Not built yet (SF-5).") }
    }
}
