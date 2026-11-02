// FlareLottieOpen: opens a Lottie JSON file as an untitled Flare document,
// plus one sentence for each part the reader had to leave out (feature
// lottie-open LO-3, docs/blueprints/flare/features/lottie-open.md). The reader is
// FlareCore's `LottieImport`. Its report counts skipped parts by kind; a
// precomp, image or text layer is named from the file's top-level layer `nm`
// ("The precomp "Logo" ..."), one sentence each, until core#808 names them in
// the report itself. Nothing else here reads the JSON. Over-limit bytes are
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

    public var message: String {
        switch self {
        case .notLottie: "This file isn't a Lottie file."
        case .damaged(let detail):
            FlareWorkspace.sentence("This file isn't a Lottie file Flare can read", detail)
        case .tooLarge(let detail):
            FlareWorkspace.sentence("This Lottie file is larger than Flare can open", detail)
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
        let entries = read.1.skipped
        let named = entries.contains { skippedLayerKinds.values.contains(String(parse($0).kind)) }
        return (document, sentences(entries, layers: named ? layerKinds(data) : []))
    }

    /// The Lottie layer types (`ty`) the reader always leaves out, and the kind its report counts each as.
    static let skippedLayerKinds: [Double: String] = [0: "precomp", 2: "image", 5: "text"]

    /// The report's entries as sentences: a skipped layer kind whose count matches the file's layers of that type
    /// gets one sentence per layer, named when the layer has a name; every other entry gets `sentence`.
    static func sentences(_ entries: [String], layers: [(Double, String?)]) -> [String] {
        // ponytail: names come from the JSON here until core#808 puts them in ImportReport; then drop `layers`.
        entries.flatMap { entry -> [String] in
            let (kind, count) = parse(entry)
            guard let type = skippedLayerKinds.first(where: { $0.value == kind })?.key else { return [sentence(entry)] }
            let names = layers.filter { $0.0 == type }.map { $0.1 }
            guard names.count == count else { return [sentence(entry)] }
            return names.map { name in
                name.map { "The \(kind) \"\($0)\" isn't supported yet and was left out." } ?? sentence(String(kind))
            }
        }
    }

    /// Each top-level layer's type and name (nil when it has none); empty when the JSON doesn't decode so.
    static func layerKinds(_ data: Data) -> [(Double, String?)] {
        struct File: Decodable { struct Layer: Decodable { var ty: Double?; var nm: String? }; var layers: [Layer] }
        let layers = (try? JSONDecoder().decode(File.self, from: data))?.layers ?? []
        return layers.compactMap { layer in layer.ty.map { ($0, layer.nm.flatMap { $0.isEmpty ? nil : $0 }) } }
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
        let (kind, count) = parse(entry)
        return count == 1 ? "The \(kind) isn't supported yet and was left out."
            : "\(count) parts of the kind \"\(kind)\" aren't supported yet and were left out."
    }

    /// One report entry's kind and count: "precomp (2)" is ("precomp", 2), "dash" is ("dash", 1).
    static func parse(_ entry: String) -> (kind: Substring, count: Int) {
        var kind = Substring(entry), count = 1
        if entry.hasSuffix(")"), let open = entry.lastIndex(of: "("),
           let n = Int(entry[entry.index(after: open)..<entry.index(before: entry.endIndex)]) {
            kind = entry[..<open]
            count = n
            while kind.last == " " { kind.removeLast() }
        }
        return (kind, count)
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

extension FlareWorkspace {
    /// Reads a Lottie JSON's bytes through FlareLottieOpen; pure, so the app runs it off the main thread like
    /// `decodeFile`.
    public static func decodeLottie(_ data: Data, named name: String) -> Result<(FlareDocument, [String]), FlareOpenError> {
        Result { () throws(FlareOpenError) in try FlareLottieOpen.open(data: data, name: name) }
    }

    /// Opens a Lottie JSON's bytes at once as unsaved, untitled work, so Save asks for a .flare and never writes
    /// the JSON; returns the skipped sentences. A refusal keeps the open document, says why in `loadState` and
    /// throws.
    public mutating func openLottie(_ data: Data, named name: String) throws(FlareOpenError) -> [String] {
        switch Self.decodeLottie(data, named: name) {
        case .success(let (document, skipped)):
            defer { importReport = skipped }  // after restoreRecovery's load, which clears it
            restoreRecovery(document)
            return skipped
        case .failure(let error):
            loadState = .failed(error.message)
            throw error
        }
    }
}
