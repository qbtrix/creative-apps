// FileFlowCommands.swift (file-flow SF-1 specs, SF-6 bodies): Open Recent, Clear Menu, Open In and drop as commands.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One file in an app's recent list.
public struct RecentFileEntry: Hashable, Codable, Sendable {
    /// The file's stable id, its display name, its path and the app that used it.
    public let fileID, name, path, app: String
    /// When the app last opened or saved it.
    public let lastUsed: Date
    public init(fileID: String, name: String, path: String, app: String, lastUsed: Date) {
        (self.fileID, self.name, self.path, self.app, self.lastUsed) = (fileID, name, path, app, lastUsed)
    }
}

/// An app that takes the file-flow commands.
public protocol FileFlowTarget: Sendable {
    /// The app's id ("photo").
    var appID: String { get }
    /// This app's recent files, newest first.
    var recentFiles: [RecentFileEntry] { get }
    /// Whether a document is open to place content into.
    var hasDocument: Bool { get }
    /// The extensions this app takes into an open document.
    var placesExtensions: Set<String> { get }
    /// The open document's readers, never this app.
    var openInApps: [String] { get }
    /// Why Open In can't run (DocumentRouting.openInRefusal's sentence, or "Save <name> first."), nil when it can.
    var openInHelp: String? { get }
    /// The apps that read an extension, default first.
    func readers(ofExtension ext: String) -> [String]
    /// Opens a recent file; a missing file is removed from the list, and the error says so.
    mutating func openRecent(_ fileID: String) throws
    /// Empties this app's recent list.
    mutating func clearRecent() throws
    /// Hands the open document to another app.
    mutating func openIn(_ app: String) throws
    /// Performs a drop's actions as one step.
    mutating func perform(_ actions: [DropAction]) throws
}

/// The five file-flow specs every adopting app registers.
public enum FileFlowCommands {
    /// `file.open-recent`'s params: the recent file to open.
    public struct OpenRecent: Codable, Sendable, CommandSchemaProviding {
        public var fileID: String
        public init(fileID: String) { self.fileID = fileID }
        public static let paramSchema = ParamSchema.object(["fileID": .string("A recent file's id, from file.recent.")],
                                                           required: ["fileID"])
    }
    /// `file.open-in`'s params: the app to hand the document to.
    public struct OpenIn: Codable, Sendable, CommandSchemaProviding {
        public var app: String
        public init(app: String) { self.app = app }
        public static let paramSchema = ParamSchema.object(["app": .string("The app that opens the document (\"halo\").")],
                                                           required: ["app"])
    }
    /// `file.drop`'s params: the dropped files, in order.
    public struct Drop: Codable, Sendable, CommandSchemaProviding {
        public var paths: [String]
        public init(paths: [String]) { self.paths = paths }
        public static let paramSchema = ParamSchema.object(
            ["paths": .array(of: .string("A file or folder path."), minItems: 1)], required: ["paths"])
    }
    /// No params.
    public struct NoParams: Codable, Sendable, CommandSchemaProviding { public static let paramSchema = ParamSchema.none }

    static let entrySchema = ParamSchema.object(
        ["fileID": .string("The file's id."), "name": .string("Its display name."), "path": .string("Its path."),
         "lastUsed": .string("When it was last opened or saved.")],
        required: ["fileID", "name", "path", "lastUsed"])
    static let actionSchema = ParamSchema.object([:], required: [], description: "One action: open, place, handOff or refuse.")

    /// The specs, in menu order.
    public static func specs<T: FileFlowTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("file.recent", title: "Recent Files", summary: "This app's recent files, newest first.", kind: .query,
                   params: NoParams.self, result: .array(of: entrySchema), example: .object([:])) { target, _ -> [RecentFileEntry] in
                target.recentFiles
            },
            .typed("file.open-recent", title: "Open Recent", summary: "Opens a file from this app's recent list.", kind: .file,
                   params: OpenRecent.self, example: .object(["fileID": .string("path:/tmp/example")])) { target, params -> JSONValue in
                guard target.recentFiles.contains(where: { $0.fileID == params.fileID }) else {
                    throw CatalogError.failed(id: "file.open-recent", message: "\(params.fileID) is not in Recent Files.")
                }
                try target.openRecent(params.fileID)
                return .null
            },
            .typed("file.clear-recent", title: "Clear Menu", summary: "Empties this app's recent list.", kind: .view,
                   params: NoParams.self, example: .object([:]),
                   availability: { $0.recentFiles.isEmpty ? .unavailable("No Recent Files") : .available }) { target, _ -> JSONValue in
                try target.clearRecent()
                return .null
            },
            .typed("file.open-in", title: "Open In", summary: "Hands the open document to another app that reads it.",
                   kind: .file, params: OpenIn.self, example: .object(["app": .string("halo")]),
                   availability: { $0.openInHelp.map { .unavailable($0) } ?? .available }) { target, params -> JSONValue in
                guard target.openInApps.contains(params.app) else {
                    throw CatalogError.failed(id: "file.open-in", message: "\(params.app) doesn't open this document.")
                }
                try target.openIn(params.app)
                return .null
            },
            .typed("file.drop", title: "Drop Files",
                   summary: "Opens, places or hands off each file as if dropped on the window; returns the actions taken.",
                   kind: .file, params: Drop.self, result: .array(of: actionSchema),
                   example: .object(["paths": .array([.string("/tmp/example.png")])])) { target, params -> [DropAction] in
                let probe = target
                let actions = DropPlan.plan(params.paths, into: target.appID, hasDocument: target.hasDocument,
                                            places: target.placesExtensions, readers: { probe.readers(ofExtension: $0) })
                try target.perform(actions)
                return actions
            },
        ]
    }
}
