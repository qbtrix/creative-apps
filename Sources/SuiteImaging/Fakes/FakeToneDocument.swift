// FakeToneDocument.swift (tone-controls TC-9): the CLI's `fake-tone` app, one picture's tone settings and one History.
// It is a ToneTarget, so its catalog is `ToneCommands`' four specs plus undo and redo, and RJ-X41 runs on the CLI on
// Linux with no pixels. It saves `{"tone": {...}}` with only the sliders off neutral, and a neutral picture writes `{}`.
// It sits beside the fake canvas app ("fake"), whose catalog and jobs it leaves alone. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

/// A headless picture with tone settings and their History: the tone commands' fake app ("fake-tone").
public struct FakeToneDocument: HeadlessDocument, ToneTarget {
    public static let app = "fake-tone", openExtensions = ["fake-tone"], exportFormats = ["json"]

    /// The picture's settings, and the History whose steps hold the settings to go back to.
    public private(set) var tone = ToneSettings.neutral, history = History<ToneSettings>()
    public init() {}

    public var toneSettings: ToneSettings? { tone }
    public var toneHelp: String? { nil }
    /// One named step; samples under one drag token fold into one.
    public mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws {
        history.record(name, tone, key: drag.map { "tone:\($0)" })
        tone = s
    }
    /// The fake has no pixels: its picture reads as already balanced, so Auto changes nothing it can measure.
    public func autoToneSuggestion() throws -> AutoTone { AutoTone(inBlack: 0, inWhite: 1, gamma: 1, temperature: 0, tint: 0) }

    /// Undoes (or, `redo`, redoes) the last step; false when there is none.
    public mutating func step(redo: Bool) -> Bool {
        var current = tone
        let swap: (ToneSettings) -> ToneSettings = { old in defer { current = old }; return current }
        let moved = redo ? history.redo(swap) : history.undo(swap)
        tone = current
        return moved
    }

    /// The file: the settings, omitted when every slider is neutral.
    struct Saved: Codable { var tone: ToneSettings? }
    /// The settings as JSON, keys sorted: the native format and the `json` export.
    public func save() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Saved(tone: tone.isNeutral(nil) ? nil : tone))
    }
    public static func open(_ data: Data, name: String) throws -> FakeToneDocument {
        var doc = FakeToneDocument()
        doc.tone = try JSONDecoder().decode(Saved.self, from: data).tone ?? .neutral
        return doc
    }
    public static func new(_ options: JSONValue) throws -> FakeToneDocument { FakeToneDocument() }
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] {
        guard format == "json" else { throw CatalogError.failed(id: "doc.export-json", message: "The fake-tone app exports json, not \(format).") }
        return [ExportedFile(suggestedName: "tone.json", format: "json", data: try save())]
    }
    public func summary() -> JSONValue { .object(["tone": ToneCommands.reading(tone), "steps": .number(Double(history.steps.count))]) }

    /// The four tone commands, `edit.undo` and `edit.redo`. Empty only if an id were refused.
    public static let catalog = (try? CommandCatalog<FakeToneDocument>(app: app, ToneCommands.specs(FakeToneDocument.self) + [
        .typed("edit.undo", title: "Undo", summary: "Undoes the last edit.", kind: .view, params: ToneCommands.NoParams.self,
               schema: ParamSchema.none, example: .object([:]),
               availability: { $0.history.canUndo ? .available : .unavailable("There is nothing to undo.") }) { doc, _ in doc.step(redo: false) },
        .typed("edit.redo", title: "Redo", summary: "Redoes the last undone edit.", kind: .view, params: ToneCommands.NoParams.self,
               schema: ParamSchema.none, example: .object([:]),
               availability: { $0.history.canRedo ? .available : .unavailable("There is nothing to redo.") }) { doc, _ in doc.step(redo: true) },
    ], history: { $0.history })) ?? .empty(app: app)
}
