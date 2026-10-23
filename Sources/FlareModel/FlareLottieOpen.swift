// FlareLottieOpen: opens a Lottie JSON file as an untitled Flare document,
// plus one sentence for each part the reader had to leave out (feature
// lottie-open LO-3, docs/blueprints/flare/features/lottie-open.md). The reader is
// FlareCore's `LottieImport`; nothing here parses Lottie. Over-limit bytes are
// refused before the reader sees them, and the reader's errors become named
// refusals. The document never carries the JSON's name, so Save asks for a
// .flare (`saveName`) and the JSON is never written.

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// The document a Flare window edits.
public typealias FlareDocument = FlareCore.Document

/// Why a file could not be opened, each with the sentence the app shows.
public enum FlareOpenError: Error, Equatable, Sendable {
    /// The bytes are not a Lottie file at all.
    case notLottie
    /// The bytes look like Lottie but are broken; the string says where.
    case damaged(String)
    /// The file is over a reader limit; the string names the limit.
    case tooLarge(String)
    /// Opening this kind of file has not been built yet (the LO-a stub's refusal; no open throws it now).
    case notYet

    public var message: String {
        switch self {
        case .notLottie: "This file isn't a Lottie file."
        case .damaged(let detail):
            FlareWorkspace.sentence("This file isn't a Lottie file Flare can read", detail)
        case .tooLarge(let detail):
            FlareWorkspace.sentence("This Lottie file is larger than Flare can open", detail)
        case .notYet: "Opening Lottie arrives with LO-3."
        }
    }
}

/// Opens Lottie JSON. Save never writes back to the JSON: the document opens
/// untitled, so the first Save asks for a .flare file.
public enum FlareLottieOpen {
    /// The file extensions the Open panel offers for Lottie.
    public static let fileExtensions = ["json"]

    /// The document and one sentence per skipped part, in the reader's order. `name` is the file's name or path;
    /// the document's title is its stem.
    public static func open(
        data: Data, name: String
    ) throws(FlareOpenError) -> (FlareDocument, [String]) {
        if let refusal = sizeRefusal(byteCount: data.count) { throw refusal }
        let read: (FlareDocument, ImportReport)
        do {
            read = try LottieImport.document(from: data)
        } catch let error as ImportError {
            throw refusal(error)
        } catch {
            throw .damaged("\(error)")
        }
        var document = read.0
        document.metadata.title = stem(name)
        return (document, read.1.skipped.map(sentence))
    }

    /// The refusal for a file of `byteCount` bytes, nil when the reader takes it; the app checks a file's size
    /// with this before reading it all.
    public static func sizeRefusal(byteCount: Int) -> FlareOpenError? {
        byteCount > LottieImport.maxBytes ? .tooLarge("the limit is \(LottieImport.maxBytes >> 20) MB") : nil
    }

    /// The name Save offers for a Lottie opened from `name`: its stem as a .flare file.
    public static func saveName(for name: String) -> String { "\(stem(name) ?? "Untitled").flare" }

    /// One report entry ("precomp (1)", "expression (3)") as a sentence.
    static func sentence(_ entry: String) -> String {
        var kind = Substring(entry), count = 1
        if entry.hasSuffix(")"), let open = entry.lastIndex(of: "("),
           let n = Int(entry[entry.index(after: open)..<entry.index(before: entry.endIndex)]) {
            kind = entry[..<open]
            count = n
            while kind.last == " " { kind.removeLast() }
        }
        return count == 1 ? "The \(kind) isn't supported yet and was left out."
            : "\(count) parts of the kind \"\(kind)\" aren't supported yet and were left out."
    }

    /// The reader's error as the refusal the app shows.
    static func refusal(_ error: ImportError) -> FlareOpenError {
        switch error {
        case .notThisFormat: .notLottie
        case .damaged(let detail), .unsupported(let detail): .damaged(detail)
        case .tooLarge(let detail): .tooLarge(detail)
        }
    }

    /// The last path component without its extension; nil when nothing is left.
    static func stem(_ name: String) -> String? {
        let file = name.split(separator: "/").last.map(String.init) ?? ""
        let stem = file.lastIndex(of: ".").map { String(file[..<$0]) } ?? file
        return stem.isEmpty ? nil : stem
    }
}
