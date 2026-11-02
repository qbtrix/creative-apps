// LookGridTests.swift (adjust-everywhere AJ-4): LookGridRows lists the six
// built-in looks first, in BuiltInLooks order, then the store's saved looks;
// a built-in has no Delete and a saved one has; a saved record that can't be
// read, or that reuses a built-in's id, is left out; Save Look… says why a
// name can't be saved. macOS only (SuiteUITests).
import Foundation
import SuiteImaging
import SuiteModel
import Testing

@testable import SuiteUI

@Suite struct LookGridTests {
    static func record(_ look: LookPreset) throws -> PresetRecord {
        PresetRecord(id: look.id, name: look.name, kind: LookPreset.recordKind, payload: try JSONEncoder().encode(look))
    }

    static func store() throws -> FakePresetStore {
        let mine = LookPreset(id: "mine", name: "Mine", builtIn: true, kinds: [.invert])
        let clash = LookPreset(id: "bw", name: "Not B&W")
        let broken = PresetRecord(id: "broken", name: "Broken", kind: LookPreset.recordKind, payload: Data([1, 2]))
        let brush = PresetRecord(id: "soft", name: "Soft", kind: "brush", payload: Data())
        return FakePresetStore([try record(mine), try record(clash), broken, brush])
    }

    @Test func builtInsFirstThenSaved() throws {
        let rows = LookGridRows(try Self.store())
        #expect(rows.looks.map(\.id) == BuiltInLooks.all.map(\.id) + ["mine"])
        #expect(rows.options.map(\.identifier) == rows.looks.map { "suite.looks.look.\($0.id)" })
        #expect(rows.looks.last?.kinds == [.invert] && rows.looks.last?.builtIn == false, "a saved look is never built in")
        #expect(LookGridRows(FakePresetStore()).looks == BuiltInLooks.all)
    }

    @Test func aBuiltInHasNoDelete() throws {
        let rows = LookGridRows(try Self.store())
        for look in BuiltInLooks.all { #expect(!rows.canDelete(look.id), "\(look.name) can be deleted") }
        #expect(rows.canDelete("mine"))
        #expect(!rows.canDelete("gone"))
    }

    @Test func saveSaysWhyANameCantBeSaved() throws {
        let rows = LookGridRows(try Self.store())
        #expect(rows.saveHelp("  ") == "Name the look.")
        #expect(rows.saveHelp("MINE") == "You already have a look named \u{201C}MINE\u{201D}.")
        #expect(rows.saveHelp("warm") == "You already have a look named \u{201C}warm\u{201D}.")
        #expect(rows.saveHelp(String(repeating: "a", count: 65)) == "A look's name is at most 64 characters.")
        #expect(rows.saveHelp("Evening") == nil)
    }
}
