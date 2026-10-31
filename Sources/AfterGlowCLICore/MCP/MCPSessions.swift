// MCPSessions.swift (afterglow-mcp MC-1 contract, MC-8 body): the documents
// an MCP client has open, by expiring handle, read and written only under
// the roots. `<app>.open` and `<app>.new` give a handle (a UUID) and the
// summary; `<app>.<id>` runs one command through the app's catalog and
// returns `{result, undoStep?}`; `afterglow.save` and `afterglow.export`
// write `{path}` and never replace a file without `force` (a file opened as an
// import opens untitled, so a save names its path, and a save lands only on
// the app's native extension); `afterglow.close`
// drops a handle. Every refusal is a tool error the model can act on: a
// why-not, each schema issue as "/path: message", a path outside the roots,
// the open cap, a dead handle. A path is placed against the first root,
// `.` and `..` folded, then checked by its real location (every symlink
// resolved, the roots' own included, so /tmp and /private/tmp agree).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// What one `tools/call` returns: `structuredContent`, the text content, and whether it is a tool error.
public struct MCPToolResult: Hashable, Sendable {
    public var structured: JSONValue; public var text: String; public var isError: Bool
    public init(structured: JSONValue, text: String, isError: Bool) { (self.structured, self.text, self.isError) = (structured, text, isError) }

    /// A tool error the model can act on: `text` says why and what to do.
    public static func error(_ text: String) -> MCPToolResult { MCPToolResult(structured: .object(["error": .string(text)]), text: text, isError: true) }

    /// A success: `fields` as the structured content, and as JSON text for clients that read only text.
    static func ok(_ fields: [String: JSONValue]) -> MCPToolResult {
        let structured = JSONValue.object(fields)
        let text = (try? structured.json()).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return MCPToolResult(structured: structured, text: text, isError: false)
    }
}

/// The open documents, by opaque handle.
public struct MCPSessions: Sendable {
    /// What a dead (closed, expired or unknown) handle answers.
    public static let expired = "this document handle expired; open it again"

    /// The server's apps, roots and limits.
    public let options: MCPOptions
    let io: any CLIIO

    /// One open document: its session, the file it was opened from or last saved to, and when a call last used it.
    struct Open: Sendable { var session: HeadlessSession; var path: String?; var used: Double }
    private var handles: [String: Open] = [:]

    /// Why a call refused, in the words its tool error carries.
    struct Refused: Error { let text: String; init(_ text: String) { self.text = text } }

    public init(_ options: MCPOptions, io: any CLIIO) { (self.options, self.io) = (options, io) }

    /// Runs `route` with the call's `arguments` at `now` (seconds), expiring idle handles first.
    public mutating func call(_ route: MCPRoute, _ arguments: JSONValue, now: Double) -> MCPToolResult {
        handles = handles.filter { now - $0.value.used < options.idleSeconds }
        guard case .object(let args) = arguments else { return .error("the arguments must be an object") }
        do throws(Refused) {
            switch route {
            case .open(let name): return try open(name, args, now: now)
            case .new(let name): return try make(name, args, now: now)
            case .save: return try save(args, now: now)
            case .export: return try export(args, now: now)
            case .close:
                handles[try entry(args).handle] = nil
                return .ok([:])
            case .command(let name, let id): return try run(name, id, args, now: now)
            }
        } catch { return .error(error.text) }
    }

    mutating func open(_ name: String, _ args: [String: JSONValue], now: Double) throws(Refused) -> MCPToolResult {
        let app = try app(name), path = try place(try string(args, "path"))
        try roomForOne()
        // An imported file opens untitled, so a save with no path never writes the native format over it.
        do { return keep(try app.session(reading: path, io: io), path: app.savesNatively(to: path) ? path : nil, now: now) }
        catch CLIIOError.missing(_) { throw Refused("there is no file at \(path)") }
        catch { throw Refused("\(path) could not be opened as a \(name) document: \(error)") }
    }

    mutating func make(_ name: String, _ args: [String: JSONValue], now: Double) throws(Refused) -> MCPToolResult {
        let app = try app(name)
        try roomForOne()
        do { return keep(try app.session(new: args["options"] ?? .object([:])), path: nil, now: now) }
        catch { throw Refused("could not make a new \(name) document: \(error)") }
    }

    /// Holds `session` under a new handle: `{doc, summary}`.
    mutating func keep(_ session: HeadlessSession, path: String?, now: Double) -> MCPToolResult {
        let handle = UUID().uuidString
        handles[handle] = Open(session: session, path: path, used: now)
        return .ok(["doc": .string(handle), "summary": session.summary()])
    }

    mutating func run(_ name: String, _ id: String, _ args: [String: JSONValue], now: Double) throws(Refused) -> MCPToolResult {
        var (handle, open) = try entry(args)
        open.used = now
        defer { handles[handle] = open }
        guard open.session.app == name else { throw Refused("this handle is a \(open.session.app) document, not a \(name) one") }
        let outcome: CommandOutcome
        do throws(CatalogError) { outcome = try open.session.run(CommandEnvelope(id: id, params: args["params"] ?? .object([:]))) }
        catch { return Self.refusal(error) }
        var fields: [String: JSONValue] = ["result": outcome.result]
        if let step = outcome.undoStep { fields["undoStep"] = .string(step) }
        return .ok(fields)
    }

    /// A catalog refusal as a tool error: the why-not, each schema issue by its path, or the failure.
    static func refusal(_ error: CatalogError) -> MCPToolResult {
        switch error {
        case .unavailable(_, let why): return .error(why)
        case .malformedParams(let id, let issues):
            return .error("\(id) params: " + issues.map { "\($0.path.isEmpty ? "/" : $0.path): \($0.message)" }.joined(separator: "; "))
        case .failed(_, let message): return .error(message)
        case .unknownCommand, .notBuilt: return .error(error.description)
        }
    }

    mutating func save(_ args: [String: JSONValue], now: Double) throws(Refused) -> MCPToolResult {
        var (handle, open) = try entry(args)
        open.used = now
        defer { handles[handle] = open }
        let given: String? = if case .string(let path)? = args["path"] { path } else { open.path }
        guard let given else { throw Refused("this document has no file yet; give a path inside the allowed roots") }
        let target = try place(given)
        let saving = try app(open.session.app)
        if !saving.savesNatively(to: target), let native = saving.openExtensions.first {
            throw Refused("\(target) would get a .\(native) document; save to <file>.\(native), or export another format")
        }
        let data: Data
        do { data = try open.session.save() } catch { throw Refused("could not save the document: \(error)") }
        try write([(data, target)], force: Self.force(args))
        open.path = target
        return .ok(["path": .string(target)])
    }

    mutating func export(_ args: [String: JSONValue], now: Double) throws(Refused) -> MCPToolResult {
        var (handle, open) = try entry(args)
        open.used = now
        defer { handles[handle] = open }
        let format = try string(args, "format"), out = try place(try string(args, "path"))
        let formats = try app(open.session.app).exportFormats
        guard formats.contains(format) else { throw Refused("\(open.session.app) exports \(formats.joined(separator: ", ")), not \(format)") }
        let files: [ExportedFile]
        do { files = try open.session.export(format, options: args["options"] ?? .object([:])) }
        catch { throw Refused("could not export as \(format): \(error)") }
        guard files.count != 1 else { return try written(files.map { ($0.data, out) }, out, force: Self.force(args)) }
        var targets: [(Data, String)] = []
        for file in files { targets.append((file.data, try place(out + "/" + file.suggestedName))) }
        guard !targets.isEmpty else { throw Refused("the document exported no files as \(format)") }
        return try written(targets, out, force: Self.force(args), listed: true)
    }

    func written(_ files: [(Data, String)], _ out: String, force: Bool, listed: Bool = false) throws(Refused) -> MCPToolResult {
        try write(files, force: force)
        return .ok(listed ? ["path": .string(out), "files": .array(files.map { .string($0.1) })] : ["path": .string(out)])
    }

    /// Writes every file, refusing before any is written when one exists and `force` is false.
    func write(_ files: [(Data, String)], force: Bool) throws(Refused) {
        let exists = { (path: String) in Refused("\(path) already exists; pass force: true to replace it") }
        if !force, let taken = files.first(where: { io.exists($0.1) }) { throw exists(taken.1) }
        for (data, path) in files {
            do { try io.write(data, to: path, replace: force) }
            catch CLIIOError.exists(_) { throw exists(path) }
            catch { throw Refused("could not write \(path): \(error)") }
        }
    }

    static func force(_ args: [String: JSONValue]) -> Bool { args["force"] == .bool(true) }

    func roomForOne() throws(Refused) {
        guard handles.count < options.maxOpen else { throw Refused("at most \(options.maxOpen) documents may be open; close one first") }
    }

    func app(_ name: String) throws(Refused) -> HeadlessApp {
        guard let app = Apps.named(name, in: options.apps) else { throw Refused("there is no app \(name) in this server") }
        return app
    }

    func entry(_ args: [String: JSONValue]) throws(Refused) -> (handle: String, open: Open) {
        guard case .string(let handle)? = args["doc"] else { throw Refused("give doc, the document handle from open or new") }
        guard let open = handles[handle] else { throw Refused(Self.expired) }
        return (handle, open)
    }

    func string(_ args: [String: JSONValue], _ key: String) throws(Refused) -> String {
        guard case .string(let value)? = args[key], !value.isEmpty else { throw Refused("give \(key), a string") }
        return value
    }

    /// `path` made absolute against the first root with `.` and `..` folded, as the I/O takes it; refused when its
    /// real location (every symlink resolved) is not inside the real location of a root.
    func place(_ path: String) throws(Refused) -> String {
        let roots = options.roots.map { Self.fold($0.hasPrefix("/") ? $0 : Self.cwd() + "/" + $0) }
        guard let base = roots.first else { throw Refused("this server has no allowed roots; start afterglow mcp with --root <dir> to use files") }
        let lexical = Self.fold(path.hasPrefix("/") ? path : base + "/" + path)
        let real = Self.real(lexical)
        guard roots.map(Self.real).contains(where: { Self.inside(real, $0) }) else {
            throw Refused("\(path) is outside the allowed roots (\(options.roots.joined(separator: ", ")))")
        }
        return lexical
    }

    /// Whether `path` lies strictly under `root`.
    static func inside(_ path: String, _ root: String) -> Bool { path != root && path.hasPrefix(root.hasSuffix("/") ? root : root + "/") }

    /// An absolute path with empty and `.` parts dropped and each `..` taking off the part before it.
    static func fold(_ path: String) -> String {
        var parts: [Substring] = []
        for part in path.split(separator: "/") where part != "." {
            if part == ".." { _ = parts.popLast() } else { parts.append(part) }
        }
        return "/" + parts.joined(separator: "/")
    }

    /// The real location of the folded absolute `path`: its longest existing prefix resolved by `realpath`, then the rest.
    static func real(_ path: String) -> String {
        var head = path, rest: [String] = []
        while true {
            if let resolved = realpath(head, nil) {
                defer { free(resolved) }
                return fold(([String(cString: resolved)] + rest.reversed()).joined(separator: "/"))
            }
            guard head != "/", let slash = head.lastIndex(of: "/") else { return path }
            rest.append(String(head[head.index(after: slash)...]))
            head = slash == head.startIndex ? "/" : String(head[..<slash])
        }
    }

    static func cwd() -> String {
        guard let dir = getcwd(nil, 0) else { return "/" }
        defer { free(dir) }
        return String(cString: dir)
    }
}
