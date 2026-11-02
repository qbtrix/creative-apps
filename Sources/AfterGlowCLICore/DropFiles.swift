// DropFiles.swift: how the CLI hands `file.drop` its files. Each drop step's paths are resolved against the folder
// the step came from (a script's folder; the working folder for a single command) and read through CLIIO, and the
// step then names the resolved paths, so the session finds each file's bytes by the path it is dropped as. A
// document that takes drops (`HeadlessDropReceiver`) gets the bytes; it never reads the disk itself.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum DropFiles {
    /// `steps` with every `file.drop` path resolved against `dir`, and each of those files read through `io`.
    /// Throws what `io.read` throws for a missing or unreadable file.
    static func attach(_ steps: [CommandEnvelope], dir: String, io: any CLIIO) throws -> (steps: [CommandEnvelope], files: [String: Data]) {
        var files: [String: Data] = [:]
        let resolved = try steps.map { step -> CommandEnvelope in
            guard step.id == "file.drop", case .object(var params) = step.params, case .array(let paths)? = params["paths"]
            else { return step }
            let joined = paths.map { path -> JSONValue in
                if case .string(let relative) = path { .string(ScriptRunner.join(dir, relative)) } else { path }
            }
            for case .string(let path) in joined where files[path] == nil { files[path] = try io.read(path) }
            params["paths"] = .array(joined)
            return CommandEnvelope(id: step.id, params: .object(params))
        }
        return (resolved, files)
    }
}
