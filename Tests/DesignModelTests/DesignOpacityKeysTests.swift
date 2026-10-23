// DesignOpacityKeysTests.swift (brush-keys BK-9): Design's digit keys through the kernel's BrushKeys rule. Design has
// no brush, so a digit sets the opacity of every selected layer: 5 is 50%, 0 is 100%, and two digits typed within
// OpacityDigits.window are the exact percent, one undo step (DesignOpacityKeys+Kernel). The catalog's
// layer.set-opacity does the same as one "Layer Opacity" step. On `cards`: A, B and C are node-2, node-3, node-4.
// Linux and macOS.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignOpacityKeysTests {
    static let abc = ["node-2", "node-3", "node-4"]

    /// `cards` with A, B and C selected.
    static func three() -> DesignWorkspace {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        w.toggleSelection("node-3")
        w.toggleSelection("node-4")
        return w
    }

    static func opacity(_ w: DesignWorkspace, _ id: String) -> Double? { w.selectedPage?.nodes.node(id)?.opacity }

    /// Types `key` at `now` as the canvas does: the kernel's rule with no brush, then the workspace's opacity key.
    @discardableResult
    static func type(_ key: Character, on w: inout DesignWorkspace, _ digits: inout OpacityDigits, at now: Double) throws -> Bool {
        let action = BrushKeys.action(for: key, shift: false, settings: BrushSettings(), brushActive: false, digits: &digits, now: now)
        guard let opacityKey = DesignWorkspace.opacityKey(action, after: digits, at: now) else { return false }
        try w.applyOpacityKey(opacityKey)
        return true
    }

    @Test func fiveSetsEverySelectedLayerToHalfAsOneStep() throws {
        var w = Self.three(), digits = OpacityDigits()
        try Self.type("5", on: &w, &digits, at: 10)
        for id in Self.abc { #expect(Self.opacity(w, id) == 0.5, "\(id)") }
        #expect(w.history.undo.count == 1)
        w.undo()
        for id in Self.abc { #expect(Self.opacity(w, id) == 1, "\(id) after undo") }
    }

    @Test func zeroIsHundred() throws {
        var w = Self.three(), digits = OpacityDigits()
        try Self.type("3", on: &w, &digits, at: 10)
        try Self.type("0", on: &w, &digits, at: 20)
        for id in Self.abc { #expect(Self.opacity(w, id) == 1, "\(id)") }
        #expect(DesignWorkspace.keyOpacity(100) == 1)
    }

    @Test func twoDigitsTypedFastAreTheExactValueAsOneStep() throws {
        var w = Self.three(), digits = OpacityDigits()
        try Self.type("4", on: &w, &digits, at: 10)
        try Self.type("5", on: &w, &digits, at: 10.3)
        for id in Self.abc { #expect(abs((Self.opacity(w, id) ?? 0) - 0.45) < 1e-9, "\(id)") }
        #expect(w.history.undo.count == 1)
        w.undo()
        for id in Self.abc { #expect(Self.opacity(w, id) == 1, "\(id) after one undo") }
    }

    @Test func aDigitAfterTheWindowIsANewStep() throws {
        var w = Self.three(), digits = OpacityDigits()
        try Self.type("4", on: &w, &digits, at: 10)
        try Self.type("7", on: &w, &digits, at: 11)
        #expect(Self.opacity(w, "node-2") == 0.7)
        #expect(w.history.undo.count == 2)
        try Self.type("2", on: &w, &digits, at: 11.2)
        #expect(abs((Self.opacity(w, "node-2") ?? 0) - 0.72) < 1e-9, "7 then 2 fast is 72%")
        #expect(w.history.undo.count == 2, "the pair's second digit joins its step")
    }

    @Test func aKeyThatIsNotADigitIsNotAnOpacityKey() throws {
        var w = Self.three(), digits = OpacityDigits()
        #expect(try Self.type("v", on: &w, &digits, at: 10) == false)
        #expect(try Self.type("]", on: &w, &digits, at: 10) == false)
        #expect(DesignWorkspace.opacityKey(.brush(.size(4)), after: digits, at: 10) == nil)
        #expect(w.history.undo.isEmpty)
    }

    @Test func withNothingSelectedADigitRefusesAndChangesNothing() {
        var w = DesignFixtures.cards, digits = OpacityDigits()
        let before = w
        #expect(throws: DesignRefusal.nothingSelected) { try Self.type("5", on: &w, &digits, at: 10) }
        #expect(w == before)
    }

    @Test func theCatalogCommandSetsEverySelectedLayerAsOneNamedStep() throws {
        var w = Self.three()
        #expect(DesignWorkspace.catalog.availability("layer.set-opacity", on: w).why == nil)
        let outcome = try DesignWorkspace.catalog.run("layer.set-opacity", params: .object(["percent": .number(50)]), on: &w)
        for id in Self.abc { #expect(Self.opacity(w, id) == 0.5, "\(id)") }
        #expect(outcome.undoStep == "Layer Opacity")
        #expect(w.history.undo.count == 1)
        _ = try DesignWorkspace.catalog.run("layer.set-opacity", params: .object(["percent": .number(100)]), on: &w)
        for id in Self.abc { #expect(Self.opacity(w, id) == 1, "\(id) at 100") }
        #expect(w.history.undo.count == 2, "each run is its own step")
    }

    @Test func theCatalogCommandSaysWhyWithNothingSelected() {
        let w = DesignFixtures.cards
        #expect(DesignWorkspace.catalog.availability("layer.set-opacity", on: w).why == DesignRefusal.nothingSelected.help)
        #expect(DesignWorkspace.catalog.spec("brush.size-up") == nil, "Design has no brush, so it takes only the layer command")
    }
}
