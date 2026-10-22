// ToneCommandsTests.swift (tone-controls TC-1 written disabled, TC-6 turns it on):
// the four tone.* commands on a test target with a History. Each edit records
// one step named its title, a drag is one step, and every why-not is said.
// Mutations (TC-6): SuiteImaging.ToneCommands (`.dragIsOneStep`,
// `.vibranceUnavailable`, `.autoIsOneStep`).
import CoreRaster
import Testing
import SuiteImaging
import SuiteKernel

/// One picture's tone, why it can't be adjusted, Auto's suggestion and its undo history.
struct ToneTestTarget: ToneTarget {
    var tone: ToneSettings? = .neutral
    var help: String?
    var suggestion = AutoTone(inBlack: 0, inWhite: 1, gamma: 1, temperature: 12, tint: -4)
    var history = History<ToneSettings?>()

    var toneSettings: ToneSettings? { tone }
    var toneHelp: String? { help }

    mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws {
        history.record(name, tone, key: drag.map { "tone:\($0)" })
        tone = s
    }

    func autoToneSuggestion() throws -> AutoTone { suggestion }

    mutating func undo() -> Bool {
        var current = tone
        let undid = history.undo { old in defer { current = old }; return current }
        tone = current
        return undid
    }

    static func catalog() throws -> CommandCatalog<ToneTestTarget> {
        try CommandCatalog(app: "test", ToneCommands.specs(ToneTestTarget.self)) { $0.history }
    }
}

@Suite(.disabled("waits on TC-6")) struct ToneCommandsTests {
    /// The four ids and kinds; `toneHelp` blocks every one.
    @Test func contractShape() throws {
        let catalog = try ToneTestTarget.catalog()
        #expect(catalog.ids == ["tone.auto", "tone.read", "tone.reset", "tone.set"])
        let kinds = Dictionary(uniqueKeysWithValues: catalog.describeAll().map { ($0.id, $0.kind) })
        #expect(kinds == ["tone.read": .query, "tone.set": .edit, "tone.reset": .edit, "tone.auto": .edit])
        var blocked = ToneTestTarget()
        blocked.help = "Open a photo first."
        for id in catalog.ids { #expect(catalog.availability(id, on: blocked).why == "Open a photo first.", "\(id)") }
    }

    /// Each edit records one step named its title; read records none and omits neutral sliders.
    @Test func eachEditIsOneNamedStep() throws {
        let catalog = try ToneTestTarget.catalog()
        var doc = ToneTestTarget()
        let set = try catalog.run("tone.set", params: .object(["slider": .string("temperature"), "value": .number(30)]), on: &doc)
        #expect(set.undoStep == "Temperature" && doc.history.steps.count == 1)
        let read = try catalog.run("tone.read", params: .object([:]), on: &doc)
        #expect(read.undoStep == nil && read.result == .object(["temperature": .number(30)]))
        #expect(try catalog.run("tone.reset", params: .object(["group": .string("whiteBalance")]), on: &doc).undoStep == "Reset White Balance")
        #expect(doc.tone == .neutral && doc.history.steps.count == 2)
    }

    /// 120 `tone.set` samples under one drag token are one undo step.
    @Test func dragIsOneStep() throws {
        let catalog = try ToneTestTarget.catalog()
        var doc = ToneTestTarget()
        for n in 1...120 {
            let params = JSONValue.object(["slider": .string("temperature"), "value": .number(Double(n) * 35 / 120), "drag": .string("d1")])
            _ = try catalog.run("tone.set", params: params, on: &doc)
        }
        _ = try catalog.run("tone.set", params: .object(["slider": .string("shadows"), "value": .number(40)]), on: &doc)
        #expect(doc.history.steps == ["Temperature", "Shadows"])
        #expect(doc.undo() && doc.tone?.value(.shadows) == 0 && doc.tone?.value(.temperature) == 35)
    }

    /// Vibrance is unavailable with ToneRules' reason; Radius and Threshold are off at Amount 0.
    @Test func vibranceUnavailable() throws {
        let catalog = try ToneTestTarget.catalog()
        var doc = ToneTestTarget()
        let vibrance = JSONValue.object(["slider": .string("vibrance"), "value": .number(20)])
        #expect(throws: CatalogError.self) { try catalog.run("tone.set", params: vibrance, on: &doc) }
        #expect(doc.history.steps.isEmpty && ToneRules.waiting[.vibrance] != nil)
        let radius = JSONValue.object(["slider": .string("sharpenRadius"), "value": .number(2)])
        #expect(throws: CatalogError.self) { try catalog.run("tone.set", params: radius, on: &doc) }
    }

    /// Reset on neutral settings is unavailable.
    @Test func resetOnNeutralUnavailable() throws {
        let catalog = try ToneTestTarget.catalog()
        #expect(catalog.availability("tone.reset", on: ToneTestTarget()).why != nil)
    }

    /// Auto records one "Auto Tone" step with the suggestion's white balance.
    @Test func autoIsOneStep() throws {
        let catalog = try ToneTestTarget.catalog()
        var doc = ToneTestTarget()
        #expect(try catalog.run("tone.auto", params: .object([:]), on: &doc).undoStep == "Auto Tone")
        #expect(doc.history.steps == ["Auto Tone"] && doc.tone?.value(.temperature) == 12)
    }

    /// Each intent's command runs on the catalog and records its step.
    @Test func intentsRoundTrip() throws {
        let catalog = try ToneTestTarget.catalog()
        var doc = ToneTestTarget()
        let intents: [ToneIntent] = [.set(.contrast, 20, drag: nil), .set(.shadows, 10, drag: "k"), .reset(.tone), .auto, .reset(nil)]
        for intent in intents {
            let (id, params) = intent.command
            _ = try catalog.run(id, params: params, on: &doc)
        }
        #expect(doc.history.steps == ["Contrast", "Shadows", "Reset Tone", "Auto Tone", "Reset Tone"])
        #expect(ToneIntent.set(.contrast, 20, drag: nil).command.id == "tone.set")
        #expect(ToneIntent.auto.command.id == "tone.auto" && ToneIntent.reset(nil).command.id == "tone.reset")
    }
}
