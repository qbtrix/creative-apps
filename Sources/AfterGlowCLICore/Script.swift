// Script.swift (afterglow-cli CL-7): the `*.jobs.json` format, its Codable
// shape and the checks a script passes before any input runs: version 1, a
// known app, every step id in that app's catalog and an output format it
// writes. Paths in a script are relative to the script's folder. The real-jobs
// suites (CL-9) read the same shape, with `expect`, `platforms` and `why`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One `*.jobs.json` script: which app, which inputs, which steps, where the outputs go.
public struct Script: Codable, Hashable, Sendable {
    /// Where and how each input's document is written: `name` is a template of `{stem}`, `{ext}`, `{index}`
    /// and `{app}`; `format` is the app's native extension (a save) or one of its export formats.
    public struct Output: Codable, Hashable, Sendable {
        public var dir: String?; public var name: String?; public var format: String?; public var options: JSONValue?
    }

    /// The format version; only 1 runs.
    public var version: Int
    /// The app whose documents the inputs are ("photo").
    public var app: String
    /// Glob patterns of the input files, relative to the script.
    public var inputs: [String]
    /// The steps run on every input, in order.
    public var steps: [CommandEnvelope]
    /// Whether one input's steps run all or none (the default) or stop at a refusal and write what they have.
    public var atomic: Bool?
    /// Where outputs go; without one, each document is saved natively under `out/`.
    public var output: Output?
    /// Real jobs only: per output path, what it must be.
    public var expect: JSONValue?
    /// Real jobs only: the platforms the job runs on ("linux", "macos"), and why when one is left out.
    public var platforms: [String]?; public var why: String?

    /// Why a script can't run: the exit code it answers with, its error kind and the message.
    public struct Problem: Error, Hashable, Sendable {
        public let code: Int32; public let kind: String; public let message: String
        static func usage(_ message: String) -> Problem { Problem(code: CLI.Exit.usage, kind: "usage", message: message) }
        static func data(_ message: String) -> Problem { Problem(code: CLI.Exit.data, kind: "data", message: message) }
    }

    /// The script in `data`, read from `path`. Throws a data problem (65) when it is not JSON, its version is
    /// not 1, or it lacks a field or has one of the wrong type.
    public static func parse(_ data: Data, path: String) throws(Problem) -> Script {
        guard let value = try? JSONValue(json: data), case .object(let fields) = value else {
            throw .data("\(path) is not a JSON object")
        }
        guard fields["version"] == .number(1) else {
            throw .data("\(path): version must be 1, not \(fields["version"].map(Self.words) ?? "missing")")
        }
        let script: Script
        do { script = try value.decode(Script.self) } catch { throw .data("\(path) is malformed: \(Self.reason(error))") }
        guard !script.inputs.isEmpty, !script.steps.isEmpty else { throw .data("\(path) needs at least one input and one step") }
        return script
    }

    /// The app among `apps` this script runs, once its steps and output format are all known to it.
    /// Throws a usage problem (64) naming the unknown app, step id or format.
    public func check(in apps: [HeadlessApp]) throws(Problem) -> HeadlessApp {
        guard let found = Apps.named(app, in: apps) else { throw .usage("unknown app \(app)") }
        let ids = Set(found.describeAll().map(\.id))
        if let bad = steps.first(where: { !ids.contains($0.id) }) { throw .usage("unknown command \(bad.id) in \(app)") }
        let format = self.format(of: found)
        guard format == found.openExtensions.first || found.exportFormats.contains(format) else {
            throw .usage("\(app) can't write \(format)")
        }
        return found
    }

    /// The format outputs are written in: `output.format`, else the app's native extension.
    func format(of app: HeadlessApp) -> String { output?.format ?? app.openExtensions.first ?? app.name }

    /// The output file name for `input` (a path), the `index`th (0-based) of `count`, without its folder.
    func fileName(for input: String, index: Int, count: Int, format: String) -> String {
        let file = input.split(separator: "/").last.map(String.init) ?? input
        let dot = file.lastIndex(of: ".").flatMap { $0 == file.startIndex ? nil : $0 }
        let stem = dot.map { String(file[..<$0]) } ?? file
        let ext = dot.map { String(file[file.index(after: $0)...]) } ?? ""
        let number = String(index + 1), width = String(count).count
        let padded = String(repeating: "0", count: max(0, width - number.count)) + number
        let name = (output?.name ?? "{stem}").replacing("{stem}", with: stem)
            .replacing("{ext}", with: ext).replacing("{index}", with: padded)
            .replacing("{app}", with: app)
        return name + "." + (Self.fileExtensions[format] ?? format)
    }

    /// The file extension of a format whose id isn't its extension: a Lottie export is JSON (.lottie is dotLottie's
    /// zip).
    static let fileExtensions = ["lottie": "json"]

    /// A JSON value in a message.
    static func words(_ value: JSONValue) -> String {
        (try? value.json()).flatMap { String(data: $0, encoding: .utf8) } ?? "?"
    }

    /// A decoding error in a few words: the field and what was wrong with it.
    static func reason(_ error: any Error) -> String {
        func path(_ keys: [any CodingKey]) -> String { keys.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".") }
        switch error as? DecodingError {
        case .keyNotFound(let key, let context)?: return "missing \(path(context.codingPath + [key]))"
        case .typeMismatch(_, let context)?, .valueNotFound(_, let context)?: return "\(path(context.codingPath)) has the wrong type"
        case .dataCorrupted(let context)?: return "\(path(context.codingPath)) is not valid"
        default: return String(describing: error)
        }
    }
}
