// FlareLottieNote.swift: the window's side of a Lottie open (feature lottie-open LO-4,
// docs/blueprints/flare/features/lottie-open.md). A .json path, picked in the open panel or dropped on the stage
// (planned as Flare's own open, so the drop mark says "Open in Flare"), opens through FlareLottieOpen
// (`opensAsLottie`, `lottieDrops`). The app
// reads and opens the file off the main actor and lands the result through `finishLottieOpen`: the document opens
// untitled, so Save asks for a .flare and never writes the JSON, and `importNote` keeps one sentence per part the
// reader left out, which the note above the stage lists (`importNoteRows`, "Nothing was skipped." for none, the first
// few and a count past `importNoteMaxRows`) until Dismiss (`dismissImportNote`) or the next load. `importReport` keeps
// the same sentences past Dismiss, for the `import.report` query (lottie-open LO-5), until the next load. A refusal
// keeps the open document and says why in `loadState`.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension FlareWorkspace {
    /// The note's one row when the reader left nothing out.
    public static let nothingSkipped = "Nothing was skipped."
    /// Why `import.report` can't run: the open document didn't come from a Lottie.
    public static let noLottieOpened = "Nothing was opened from a Lottie file."

    /// `import.report`: the open document's Lottie open's skipped sentences, `{skipped: [sentence]}`.
    static let importReportCommand: CommandSpec<FlareWorkspace> = .typed(
        "import.report", title: "Import Report",
        summary: "Lists what the Lottie open left out, one sentence per skipped part.", kind: .query,
        params: NoParams.self, schema: ParamSchema.none,
        result: .object(["skipped": .array(of: .string("One sentence per skipped part."))], required: ["skipped"]),
        example: .object([:]),
        availability: { $0.importReport == nil ? .unavailable(noLottieOpened) : .available }
    ) { w, _ in ImportReport(skipped: w.importReport ?? []) }

    struct ImportReport: Encodable { let skipped: [String] }

    /// The most skipped parts the note names; past that its last row counts the rest, so the note stays a strip
    /// above the stage however many parts a file skips.
    public static let importNoteMaxRows = 3

    /// Whether `path` opens through the Lottie reader (its extension is one of `FlareLottieOpen.fileExtensions`).
    public static func opensAsLottie(_ path: String) -> Bool {
        FlareLottieOpen.fileExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }

    /// A drop's actions split: the Lottie files, planned as Flare's own open (the stage's `opens`) or refused by
    /// the suite's rule, which Flare opens itself, and the rest, in order, for the documents bridge (which has no
    /// suite type for a .json, so it would drop the open).
    public static func lottieDrops(_ actions: [DropAction]) -> (lottie: [String], rest: [DropAction]) {
        var lottie: [String] = [], rest: [DropAction] = []
        for action in actions {
            switch action {
            case .open(let path) where opensAsLottie(path), .refuse(let path, _) where opensAsLottie(path):
                lottie.append(path)
            default: rest.append(action)
            }
        }
        return (lottie, rest)
    }

    /// Lands a Lottie open: the document, untitled, with its note; a refusal keeps the open document.
    public mutating func finishLottieOpen(_ result: Result<(FlareDocument, [String]), FlareOpenError>) {
        switch result {
        case .success(let (document, skipped)):
            load(document)
            importNote = skipped
            importReport = skipped
        case .failure(let error):
            loadState = .failed(error.message)
        }
    }

    /// The note's rows: each skipped part's sentence, `nothingSkipped` for none; empty while no note shows. Past
    /// `importNoteMaxRows + 1` parts it names the first `importNoteMaxRows` and counts the rest in a last row.
    public var importNoteRows: [String] {
        guard let importNote else { return [] }
        if importNote.isEmpty { return [Self.nothingSkipped] }
        let max = Self.importNoteMaxRows
        guard importNote.count > max + 1 else { return importNote }
        return Array(importNote.prefix(max)) + ["\(importNote.count - max) more parts were left out."]
    }

    /// Dismiss: the note closes; the document stays.
    public mutating func dismissImportNote() { importNote = nil }
}
