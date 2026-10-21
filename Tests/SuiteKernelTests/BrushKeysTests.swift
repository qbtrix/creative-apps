// BrushKeysTests.swift (brush-keys BK-2 written, BK-3 turned on): the bracket keys step the brush size in bands
// that grow with it and stay in BrushSettings' range, Shift-brackets move hardness by a quarter, digits set
// opacity in tens or, two within the window, an exact percent, and with no brush the digits go to the layers.
import Testing
import SuiteKernel

/// A brush tool and a layer selection: the brush keys' commands on a kernel `History` of layer opacity.
struct BrushKeysDoc: BrushKeyTarget {
    var activeBrush: BrushSettings? = BrushSettings()
    var opacity = 100.0, history = History<Double>()
    mutating func setActiveBrush(_ s: BrushSettings) throws { activeBrush = s }
    mutating func setSelectedOpacity(_ percent: Double) throws { history.record("Layer Opacity", opacity); opacity = percent }
}

@Suite struct BrushKeysTests {
    static let catalog = try? CommandCatalog(app: "test", BrushKeyCommands.specs(BrushKeysDoc.self), history: { $0.history })

    /// The action for `key` on a brush of `settings`, with a fresh digit buffer.
    static func action(_ key: Character, shift: Bool = false, settings: BrushSettings = BrushSettings(), brushActive: Bool = true) -> BrushKeyAction? {
        var digits = OpacityDigits()
        return BrushKeys.action(for: key, shift: shift, settings: settings, brushActive: brushActive, digits: &digits, now: 0)
    }

    @Test func sizeUpStepsByBand() {
        #expect(BrushKeys.step(size: 9, up: true) == 10)
        #expect(BrushKeys.step(size: 10, up: true) == 15)
        #expect(BrushKeys.step(size: 23, up: true) == 25)
        #expect(BrushKeys.step(size: 100, up: true) == 125)
        #expect(BrushKeys.step(size: 299, up: true) == 300)
        #expect(BrushKeys.step(size: 300, up: true) == 350)
        #expect(BrushKeys.step(size: 500, up: true) == 500)
    }
    @Test func sizeDownUsesTheBandBelow() {
        #expect(BrushKeys.step(size: 1, up: false) == 1)
        #expect(BrushKeys.step(size: 10, up: false) == 9)
        #expect(BrushKeys.step(size: 23, up: false) == 20)
        #expect(BrushKeys.step(size: 100, up: false) == 95)
        #expect(BrushKeys.step(size: 300, up: false) == 275)
        #expect(BrushKeys.step(size: 500, up: false) == 450)
    }
    @Test func hardnessMovesAQuarter() {
        #expect(BrushKeys.hardnessStep(60, up: true) == 85)
        #expect(BrushKeys.hardnessStep(85, up: true) == 100)
        #expect(BrushKeys.hardnessStep(60, up: false) == 35)
        #expect(BrushKeys.hardnessStep(10, up: false) == 0)
    }
    @Test func bracketsActOnTheBrush() {
        #expect(Self.action("]", settings: BrushSettings(size: 9)) == .brush(.size(10)))
        #expect(Self.action("[", settings: BrushSettings(size: 1)) == .brush(.size(1)))
        #expect(Self.action("]", shift: true, settings: BrushSettings(hardness: 60)) == .brush(.hardness(85)))
        #expect(Self.action("[", shift: true, settings: BrushSettings(hardness: 60)) == .brush(.hardness(35)))
        #expect(Self.action("]", brushActive: false) == nil && Self.action("a") == nil)
    }
    @Test func digitsSetTensAndQuickPairs() {
        var digits = OpacityDigits()
        #expect(OpacityDigits.window == 0.6)
        #expect(digits.type(1, at: 0) == 10)
        #expect(digits.type(4, at: 10) == 40 && digits.type(5, at: 10.5) == 45)
        #expect(digits.type(4, at: 20) == 40 && digits.type(5, at: 20.7) == 50)
        var edge = OpacityDigits()  // 0.6 - 0 is exactly the window: the pair has closed
        #expect(edge.type(4, at: 0) == 40 && edge.type(5, at: OpacityDigits.window) == 50)
        #expect(digits.type(0, at: 40) == 100)
        #expect(digits.type(0, at: 50) == 100 && digits.type(5, at: 50.2) == 5)
        #expect(digits.type(7, at: 60) == 70 && digits.type(2, at: 60.1) == 72 && digits.type(3, at: 60.2) == 30)
    }
    @Test func digitsGoToTheBrushOrTheLayers() {
        var digits = OpacityDigits()
        let brush = BrushSettings()
        #expect(BrushKeys.action(for: "4", shift: false, settings: brush, brushActive: true, digits: &digits, now: 0) == .brush(.opacity(40)))
        #expect(BrushKeys.action(for: "5", shift: false, settings: brush, brushActive: true, digits: &digits, now: 0.3) == .brush(.opacity(45)))
        #expect(BrushKeys.action(for: "0", shift: false, settings: brush, brushActive: false, digits: &digits, now: 5) == .layerOpacity(100))
        #expect(BrushKeys.action(for: "5", shift: true, settings: brush, brushActive: true, digits: &digits, now: 9) == nil)
    }
    @Test func commandsEditTheBrushAndTheLayers() throws {
        let catalog = try #require(Self.catalog)
        var doc = BrushKeysDoc()
        _ = try catalog.run("brush.size-up", params: .object([:]), on: &doc)
        _ = try catalog.run("brush.hardness-down", params: .object([:]), on: &doc)
        _ = try catalog.run("brush.set-opacity", params: .object(["percent": .number(45)]), on: &doc)
        #expect(doc.activeBrush == BrushSettings(size: 25, hardness: 75, opacity: 45))
        let outcome = try catalog.run("layer.set-opacity", params: .object(["percent": .number(30)]), on: &doc)
        #expect(doc.opacity == 30 && outcome.undoStep == "Layer Opacity" && doc.history.steps == ["Layer Opacity"])
        doc.activeBrush = nil
        #expect(catalog.availability("brush.size-down", on: doc) == .unavailable(BrushKeyCommands.noBrushHelp))
    }
}
