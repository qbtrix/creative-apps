// ToneCommandsTests.swift (tone-controls TC-1 written, TC-6 turns it on):
// the four tone.* commands on a test target with a History. Mutations (TC-6):
// SuiteImaging.ToneCommands (`.dragIsOneStep`, `.vibranceUnavailable`, `.autoIsOneStep`).
import CoreRaster
import Testing
import SuiteImaging
import SuiteKernel

/// One picture's tone, why it can't be adjusted, Auto's suggestion and its undo history.
struct ToneTestTarget: ToneTarget {
    var tone: ToneSettings? = .neutral
    var help: String?
    var history = History<ToneSettings?>()
    var toneSettings: ToneSettings? { tone }
    var toneHelp: String? { help }

    mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws {
        history.record(name, tone, key: drag.map { "tone:\($0)" })
        tone = s
    }

    func autoToneSuggestion() throws -> AutoTone { AutoTone(inBlack: 0, inWhite: 1, gamma: 1, temperature: 12, tint: -4) }

    mutating func undo() -> Bool {
        var current = tone
        defer { tone = current }
        return history.undo { old in defer { current = old }; return current }
    }
}

func toneCatalog() throws -> CommandCatalog<ToneTestTarget> {
    try CommandCatalog(app: "test", ToneCommands.specs(ToneTestTarget.self)) { $0.history }
}

@Suite struct ToneCommandsTests {
    /// The four ids and kinds; `toneHelp` blocks every one; reset on neutral is unavailable.
    @Test func contractShape() throws {
        let catalog = try toneCatalog()
        #expect(catalog.ids == ["tone.auto", "tone.read", "tone.reset", "tone.set"])
        let kinds = Dictionary(uniqueKeysWithValues: catalog.describeAll().map { ($0.id, $0.kind) })
        #expect(kinds == ["tone.read": .query, "tone.set": .edit, "tone.reset": .edit, "tone.auto": .edit])
        let blocked = ToneTestTarget(help: "Open a photo first.")
        for id in catalog.ids { #expect(catalog.availability(id, on: blocked).why == "Open a photo first.", "\(id)") }
        #expect(catalog.availability("tone.reset", on: ToneTestTarget()).why != nil)
    }

    /// Each edit records one step named its title; read records none and omits neutral sliders.
    @Test func eachEditIsOneNamedStep() throws {
        let catalog = try toneCatalog()
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
        let catalog = try toneCatalog()
        var doc = ToneTestTarget()
        for n in 1...120 {
            let params = JSONValue.object(["slider": .string("temperature"), "value": .number(Double(n) * 35 / 120), "drag": .string("d1")])
            _ = try catalog.run("tone.set", params: params, on: &doc)
        }
        _ = try catalog.run("tone.set", params: .object(["slider": .string("shadows"), "value": .number(40)]), on: &doc)
        #expect(doc.history.steps == ["Temperature", "Shadows"])
        #expect(doc.undo() && doc.tone?.value(.shadows) == 0 && doc.tone?.value(.temperature) == 35)
    }

    /// Vibrance is refused with `waiting`'s reason; Radius and Threshold are off at Amount 0. None records a step.
    @Test func vibranceUnavailable() throws {
        let catalog = try toneCatalog()
        var doc = ToneTestTarget()
        let reasons = ["vibrance": ToneRules.waiting[.vibrance] ?? "", "sharpenRadius": "Sharpen is off at Amount 0.",
                       "sharpenThreshold": "Sharpen is off at Amount 0."]
        for (slider, why) in reasons {
            let params = JSONValue.object(["slider": .string(slider), "value": .number(2)])
            #expect(throws: CatalogError.unavailable(id: "tone.set", why: why)) { try catalog.run("tone.set", params: params, on: &doc) }
        }
        #expect(doc.history.steps.isEmpty && ToneRules.waiting[.vibrance] != nil)
        _ = try catalog.run("tone.set", params: .object(["slider": .string("sharpenAmount"), "value": .number(50)]), on: &doc)
        _ = try catalog.run("tone.set", params: .object(["slider": .string("sharpenRadius"), "value": .number(2)]), on: &doc)
        #expect(doc.history.steps == ["Amount", "Radius"] && doc.tone?.value(.sharpenRadius) == 2)
    }

    /// Each intent's command is the id and params its spec reads; a nil drag and a nil group are omitted.
    @Test func intentCommands() {
        let set = ToneIntent.set(.shadows, 10, drag: "k").command
        #expect(set.id == "tone.set" && set.params == .object(["slider": .string("shadows"), "value": .number(10), "drag": .string("k")]))
        let typed = ToneIntent.set(.contrast, 20, drag: nil).command
        #expect(typed.params == .object(["slider": .string("contrast"), "value": .number(20)]))
        let reset = ToneIntent.reset(.whiteBalance).command
        #expect(reset.id == "tone.reset" && reset.params == .object(["group": .string("whiteBalance")]))
        #expect(ToneIntent.reset(nil).command.params == .object([:]))
        #expect(ToneIntent.auto.command.id == "tone.auto" && ToneIntent.auto.command.params == .object([:]))
    }

    /// Auto records one "Auto Tone" step; each intent's command runs and records its step.
    @Test func autoIsOneStep() throws {
        let catalog = try toneCatalog()
        var doc = ToneTestTarget()
        #expect(try catalog.run("tone.auto", params: .object([:]), on: &doc).undoStep == "Auto Tone")
        #expect(doc.history.steps == ["Auto Tone"] && doc.tone?.value(.temperature) == 12)
        for intent in [ToneIntent.set(.contrast, 20, drag: nil), .set(.shadows, 10, drag: "k"), .reset(.tone), .reset(nil)] {
            _ = try catalog.run(intent.command.id, params: intent.command.params, on: &doc)
        }
        #expect(doc.history.steps == ["Auto Tone", "Contrast", "Shadows", "Reset Tone", "Reset Tone"] && doc.tone == .neutral)
    }
}
