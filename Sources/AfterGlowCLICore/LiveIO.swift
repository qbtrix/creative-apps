// LiveIO.swift (afterglow-cli CL-5): CLIIO on the real file system. Reads
// refuse anything that is not a regular file and stop at a 2 GiB cap. Writes
// make missing folders, then go to a temp file beside the target, then land by rename (replace) or by
// hard link (no replace, which the kernel refuses when the target exists), so
// the target is absent, as it was, or whole. Globs walk the folders with
// FileManager and FakeIO's segment matcher; no shell ever sees a pattern.
// FileManager needs the whole Foundation on Linux, so this file imports it.
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// Why a LiveIO read or write refused, beyond the protocol's `CLIIOError`.
public enum LiveIOError: Error, Hashable, Sendable {
    /// The path names a directory or another item that is not a regular file.
    case notAFile(String)
    /// The file is bigger than the read cap (its size in bytes).
    case tooLarge(String, Int64)
    /// A system call on the path failed with this `errno`.
    case system(String, String, Int32)
}

/// The real file system, stdout and stderr.
public struct LiveIO: CLIIO {
    /// The most bytes `read` returns: 2 GiB.
    public static let defaultReadLimit: Int64 = 2 << 30
    /// The read cap this instance applies.
    public let readLimit: Int64

    /// The real file system, reading at most `readLimit` bytes per file.
    public init(readLimit: Int64 = LiveIO.defaultReadLimit) { self.readLimit = readLimit }

    public func read(_ path: String) throws -> Data {
        guard let (type, size) = Self.follow(path) else { throw CLIIOError.missing(path) }
        guard type == .typeRegular else { throw LiveIOError.notAFile(path) }
        if size > readLimit { throw LiveIOError.tooLarge(path, size) }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        if Int64(data.count) > readLimit { throw LiveIOError.tooLarge(path, Int64(data.count)) }
        return data
    }

    public func write(_ data: Data, to path: String, replace: Bool) throws {
        let target = URL(fileURLWithPath: path)
        if Self.isDirectory(path) { throw LiveIOError.notAFile(path) }
        if !replace, exists(path) { throw CLIIOError.exists(path) }
        // A batch's output folder may not exist yet; a file standing where a folder goes still refuses.
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temp = target.deletingLastPathComponent()
            .appendingPathComponent(".\(target.lastPathComponent).afterglow-\(UUID().uuidString)").path
        // The temp is gone once renamed; after a link or a failed write this removes it. Its result is moot.
        defer { _ = unlink(temp) }
        try data.write(to: URL(fileURLWithPath: temp))
        try Self.land(temp, at: path, replace: replace)
    }

    /// Puts the written temp file at `path`: rename replaces in one step; link refuses an existing target.
    static func land(_ temp: String, at path: String, replace: Bool) throws {
        if replace {
            guard rename(temp, path) == 0 else { throw LiveIOError.system("rename", path, errno) }
            return
        }
        guard link(temp, path) == 0 else {
            let code = errno
            if code == EEXIST { throw CLIIOError.exists(path) }
            throw LiveIOError.system("link", path, code)
        }
    }

    /// Whether anything (a file, a folder or a link) is at `path`.
    public func exists(_ path: String) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: path)) != nil
    }

    public func glob(_ pattern: String, relativeTo dir: String) throws -> [String] {
        let absolute = pattern.hasPrefix("/")
        let folder = dir.count > 1 && dir.hasSuffix("/") ? String(dir.dropLast()) : dir
        let base = absolute ? "" : (folder.isEmpty || folder == "." ? "" : folder)
        let segments = pattern.split(separator: "/").map(String.init)
        guard let last = segments.last else { return [] }
        var folders = [base]
        for segment in segments.dropLast() {
            folders = folders.flatMap { Self.children($0, matching: segment, absolute: absolute) }
                .filter { Self.isDirectory(Self.resolve($0, absolute: absolute)) }
        }
        return folders.flatMap { Self.children($0, matching: last, absolute: absolute) }
            .filter { Self.isRegular(Self.resolve($0, absolute: absolute)) }
            .sorted()
    }

    /// Writes unbuffered, so a client on a pipe gets each `afterglow mcp` reply as it is written.
    public func out(_ line: String) { FileHandle.standardOutput.write(Data((line + "\n").utf8)) }
    public func err(_ line: String) { FileHandle.standardError.write(Data((line + "\n").utf8)) }
    /// Swift's `readLine`, which repairs invalid UTF-8 rather than passing it on.
    public func readLine() -> Data? { Swift.readLine(strippingNewline: true).map { Data($0.utf8) } }

    /// The paths under `folder` whose name matches `segment` (`*`, `?`); a literal segment is taken as is.
    /// A name starting with "." matches only a segment that does.
    static func children(_ folder: String, matching segment: String, absolute: Bool) -> [String] {
        let join = { (name: String) in 
            folder.isEmpty ? (absolute ? "/" + name : name) : folder.hasSuffix("/") ? folder + name : folder + "/" + name
        }
        guard segment.contains("*") || segment.contains("?") else { return [join(segment)] }
        let listed = (try? FileManager.default.contentsOfDirectory(atPath: resolve(folder, absolute: absolute))) ?? []
        return listed.filter { name in
            (!name.hasPrefix(".") || segment.hasPrefix(".")) && FakeIO.matches(Array(segment), Array(name))
        }.map(join)
    }

    /// The path FileManager takes for a glob path: "" is the current or root folder.
    static func resolve(_ path: String, absolute: Bool) -> String { path.isEmpty ? (absolute ? "/" : ".") : path }

    /// The type and size of what `path` names, following every symlink on the way (stat, not lstat),
    /// or nil when nothing is there. Resolving the path first is not enough on macOS:
    /// `resolvingSymlinksInPath` maps `/var` back to `/var`, which lstat calls a link.
    static func follow(_ path: String) -> (type: FileAttributeType, size: Int64)? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        switch info.st_mode & S_IFMT {
        case S_IFDIR: return (.typeDirectory, Int64(info.st_size))
        case S_IFREG: return (.typeRegular, Int64(info.st_size))
        default: return (.typeUnknown, Int64(info.st_size))
        }
    }
    static func type(_ path: String) -> FileAttributeType? { follow(path)?.type }
    static func isDirectory(_ path: String) -> Bool { type(path) == .typeDirectory }
    static func isRegular(_ path: String) -> Bool { type(path) == .typeRegular }
}

extension HeadlessApp {
    /// Opens the file at `path` through `io` as this app's document, named by its last path component.
    /// Throws what `io.read` throws (missing, not a file, too large), then what the app's `open` throws.
    public func session(reading path: String, io: any CLIIO) throws -> HeadlessSession {
        try session(open: io.read(path), name: URL(fileURLWithPath: path).lastPathComponent)
    }
}
