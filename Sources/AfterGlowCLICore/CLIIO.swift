// CLIIO.swift (afterglow-cli CL-2): everything the CLI touches outside
// itself, behind one protocol, so every route runs in process on FakeIO in
// the tests. CL-5 adds LiveIO, the real file system, in its own file; this
// file keeps the protocol, the in-memory FakeIO and the stubs' `CLI.notBuilt`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

/// The CLI's whole outside world: files, globs, stdout and stderr.
public protocol CLIIO: Sendable {
    /// The bytes of the file at `path`. Throws when there is none, or it is a directory.
    func read(_ path: String) throws -> Data
    /// Writes `data` to `path` atomically: the target ends up absent, as it was, or whole.
    /// Throws `CLIIOError.exists` when the file is there and `replace` is false.
    func write(_ data: Data, to path: String, replace: Bool) throws
    /// Whether a file is at `path`.
    func exists(_ path: String) -> Bool
    /// The files matching `pattern` (`*` and `?` within one path segment), resolved against `dir`,
    /// as `read` takes them, sorted.
    func glob(_ pattern: String, relativeTo dir: String) throws -> [String]
    /// Prints one line on stdout.
    func out(_ line: String)
    /// Prints one line on stderr.
    func err(_ line: String)
    /// The next line of stdin without its newline, nil once stdin ends (`afterglow mcp` reads its requests here).
    func readLine() -> Data?
}

extension CLIIO {
    /// No stdin: it has already ended.
    public func readLine() -> Data? { nil }
}

/// Why a file operation refused.
public enum CLIIOError: Error, Hashable, Sendable {
    /// There is no file at the path.
    case missing(String)
    /// A file is already at the path and the write may not replace it.
    case exists(String)
}

/// An in-memory file system with captured stdout and stderr: the tests' world.
public final class FakeIO: CLIIO {
    /// The files by path, and the lines printed so far.
    private struct State { var files: [String: Data]; var stdin: [Data] = []; var stdout: [String] = []; var stderr: [String] = [] }
    private let state: Mutex<State>

    /// A file system holding `files`, keyed by path, whose stdin is the lines `stdin`.
    public init(files: [String: Data] = [:], stdin: [Data] = []) { state = Mutex(State(files: files, stdin: stdin)) }

    /// Every file, keyed by path.
    public var files: [String: Data] { state.withLock { $0.files } }
    /// The lines printed on stdout, in order.
    public var stdout: [String] { state.withLock { $0.stdout } }
    /// The lines printed on stderr, in order.
    public var stderr: [String] { state.withLock { $0.stderr } }

    public func read(_ path: String) throws -> Data {
        guard let data = state.withLock({ $0.files[path] }) else { throw CLIIOError.missing(path) }
        return data
    }

    public func write(_ data: Data, to path: String, replace: Bool) throws {
        let written = state.withLock { state -> Bool in
            if !replace, state.files[path] != nil { return false }
            state.files[path] = data
            return true
        }
        if !written { throw CLIIOError.exists(path) }
    }

    public func exists(_ path: String) -> Bool { state.withLock { $0.files[path] != nil } }

    public func glob(_ pattern: String, relativeTo dir: String) throws -> [String] {
        let full = dir.isEmpty || dir == "." || pattern.hasPrefix("/") ? pattern : dir + "/" + pattern
        let want = full.split(separator: "/", omittingEmptySubsequences: false)
        return state.withLock { state in
            state.files.keys.filter { path in
                let have = path.split(separator: "/", omittingEmptySubsequences: false)
                return have.count == want.count && zip(want, have).allSatisfy { Self.matches(Array($0), Array($1)) }
            }.sorted()
        }
    }

    public func out(_ line: String) { state.withLock { $0.stdout.append(line) } }
    public func err(_ line: String) { state.withLock { $0.stderr.append(line) } }
    public func readLine() -> Data? { state.withLock { $0.stdin.isEmpty ? nil : $0.stdin.removeFirst() } }

    /// Whether one path segment `name` matches `pattern`, where `*` is any run and `?` any one character.
    static func matches(_ pattern: [Character], _ name: [Character]) -> Bool {
        guard let head = pattern.first else { return name.isEmpty }
        let rest = Array(pattern.dropFirst())
        switch head {
        case "*": return matches(rest, name) || (!name.isEmpty && matches(pattern, Array(name.dropFirst())))
        case "?": return !name.isEmpty && matches(rest, Array(name.dropFirst()))
        default: return name.first == head && matches(rest, Array(name.dropFirst()))
        }
    }
}

extension CLI {
    /// Prints the `notBuilt` failure for a stub entry point and returns 69.
    static func notBuilt(_ message: String, io: any CLIIO) -> Int32 {
        io.out(encode(Failure(error: .init(kind: "notBuilt", message: message))))
        io.err(message)
        return Exit.unavailable
    }
}
