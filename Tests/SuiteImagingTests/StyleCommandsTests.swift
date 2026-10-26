// StyleCommandsTests.swift (layer-styles LS-1 written disabled, LS-6 turns it on and adds the
// drag, paste, panel and intent cases): the eleven style.* commands on a test target with a History.
import Testing
import SuiteImaging
import SuiteKernel

struct StyleTestTarget: LayerStyleTarget {
    var style = LayerStyle.none, selected = true, panel: StyleKind?
    var history = History<LayerStyle>()
    var styleSelection: LayerStyle? { selected ? style : nil }
    var styleHelp: String? { selected ? nil : StyleRules.noLayerHelp }
    var stylePanel: StyleKind? { panel }
    mutating func showStylePanel(_ kind: StyleKind?) { panel = kind }
    mutating func setStyle(_ new: LayerStyle, name: String, drag: String?) throws {
        history.record(name, style, key: drag.map { "style:\($0)" })
        style = new
    }
    /// Reverts the last step, as an app's edit.undo does.
    mutating func undo() {
        var (steps, now) = (history, style)
        _ = steps.undo { old in defer { now = old }; return now }
        (history, style) = (steps, now)
    }
}

struct StyleCommandsTests {
    let catalog: CommandCatalog<StyleTestTarget>
    init() throws { catalog = try CommandCatalog(app: "test", StyleCommands.specs(StyleTestTarget.self)) { $0.history } }

    func run(_ id: String, _ params: [String: JSONValue] = [:], on target: inout StyleTestTarget) throws -> CommandOutcome {
        try catalog.run(id, params: .object(params), on: &target)
    }
    static let shadow: [String: JSONValue] = ["kind": .string("dropShadow")]

    /// The eleven ids and kinds; no selection blocks every one; copy needs a style.
    @Test func contractShape() throws {
        #expect(catalog.ids == ["style.add", "style.clear", "style.copy", "style.enable", "style.fill-opacity", "style.panel",
                                "style.paste", "style.preset", "style.read", "style.remove", "style.set"])
        #expect(catalog.describeAll().filter { $0.kind == .edit }.count == 8)
        for id in catalog.ids { #expect(catalog.availability(id, on: StyleTestTarget(selected: false)).why == StyleRules.noLayerHelp) }
        #expect(catalog.availability("style.copy", on: StyleTestTarget()).why == "This layer has no style to copy.")
        #expect(catalog.availability("style.clear", on: StyleTestTarget()).why == "This layer has no style to clear.")
    }

    /// Every edit records exactly one step, named its title, and returns the new style.
    @Test func eachEditIsOneStepNamedItsTitle() throws {
        var target = StyleTestTarget()
        let neon = StyleRules.json(try #require(StyleRules.presets.first { $0.name == "Neon" }).style)
        let runs: [(String, [String: JSONValue])] = [
            ("style.add", Self.shadow), ("style.enable", ["kind": .string("dropShadow"), "on": .bool(false)]),
            ("style.set", ["kind": .string("dropShadow"), "distance": .number(20)]), ("style.fill-opacity", ["value": .number(0.5)]),
            ("style.remove", Self.shadow), ("style.preset", ["name": .string("Lifted")]), ("style.paste", ["style": neon]),
            ("style.clear", [:]),
        ]
        for (count, (id, params)) in runs.enumerated() {
            let outcome = try run(id, params, on: &target)
            let title = try #require(catalog.describe(id)?.title)
            #expect(target.history.steps.count == count + 1, "\(id)")
            #expect(target.history.undoName == title && outcome.undoStep == title, "\(id)")
            #expect(outcome.result == StyleRules.json(target.style), "\(id)")
        }
        #expect(target.style == .none)
    }

    /// 120 `style.set` samples under one drag token are one undo step; undo puts the style back as it was before the drag.
    @Test func dragIsOneStep() throws {
        var target = StyleTestTarget()
        _ = try run("style.add", Self.shadow, on: &target)
        let before = target.style
        for i in 0..<120 { _ = try run("style.set", ["kind": .string("dropShadow"), "distance": .number(Double(i)), "drag": .string("d1")], on: &target) }
        #expect(target.history.steps == ["Add Layer Style", "Change Layer Style"])
        guard case .shadow(let s)? = target.style.effect(.dropShadow)?.parameters else { Issue.record("no shadow"); return }
        #expect(s.distance == 119)
        target.undo()
        #expect(target.style == before)
        _ = try run("style.fill-opacity", ["value": .number(0.4), "drag": .string("d2")], on: &target)
        _ = try run("style.fill-opacity", ["value": .number(0.3), "drag": .string("d2")], on: &target)
        #expect(target.history.steps == ["Add Layer Style", "Fill Opacity"] && target.style.fillOpacity == 0.3)
    }

    /// A kind that is present but turned off still refuses `style.add`; its settings stay.
    @Test func addRefusesAKindTurnedOff() throws {
        var target = StyleTestTarget()
        _ = try run("style.add", Self.shadow, on: &target)
        _ = try run("style.enable", Self.shadow.merging(["on": .bool(false)]) { a, _ in a }, on: &target)
        let before = target.style
        #expect(throws: CatalogError.unavailable(id: "style.add", why: "This layer already has a dropShadow; use style.enable to turn it on or off.")) {
            try run("style.add", Self.shadow, on: &target)
        }
        #expect(target.style == before)
    }

    /// A kind already on, a kind absent, an unknown preset: each refused with its reason, the target unchanged.
    @Test func everyWhyNot() throws {
        var target = StyleTestTarget()
        _ = try run("style.add", Self.shadow, on: &target)
        let before = target
        #expect(throws: CatalogError.unavailable(id: "style.add", why: "This layer already has a dropShadow; use style.enable to turn it on or off.")) {
            try run("style.add", Self.shadow, on: &target)
        }
        let glow: [String: JSONValue] = ["kind": .string("outerGlow")]
        for (id, params) in [("style.remove", glow), ("style.enable", glow.merging(["on": .bool(true)]) { a, _ in a }),
                             ("style.set", glow.merging(["size": .number(4)]) { a, _ in a })] {
            #expect(throws: CatalogError.unavailable(id: id, why: "This layer has no outerGlow.")) { try run(id, params, on: &target) }
        }
        #expect(throws: CatalogError.unavailable(id: "style.preset", why: "There is no style preset named Sparkle.")) {
            try run("style.preset", ["name": .string("Sparkle")], on: &target)
        }
        #expect(target.style == before.style && target.history.steps == before.history.steps)
    }

    /// Copy on one layer, paste on another: the same style; a pasted style with two shadows is refused with `check`'s reason.
    @Test func copyThenPasteGivesAnEqualStyle() throws {
        var a = StyleTestTarget(), b = StyleTestTarget()
        _ = try run("style.preset", ["name": .string("Neon")], on: &a)
        _ = try run("style.set", ["kind": .string("stroke"), "position": .string("inside"), "size": .number(7)], on: &a)
        _ = try run("style.fill-opacity", ["value": .number(0.6)], on: &a)
        let copied = try run("style.copy", on: &a)
        #expect(copied.undoStep == nil && a.history.steps.count == 3)
        _ = try run("style.paste", ["style": copied.result], on: &b)
        #expect(b.style == a.style && b.history.steps == ["Paste Layer Style"])
        #expect(try run("style.read", on: &b).result == copied.result)
    }

    @Test func pasteRefusesMalformed() throws {
        var target = StyleTestTarget()
        let two = JSONValue.object(["effects": .array([.object(Self.shadow), .object(Self.shadow)]), "fillOpacity": .number(1)])
        #expect(throws: CatalogError.unavailable(id: "style.paste", why: "A second dropShadow is ignored; a style holds one of each kind.")) {
            try run("style.paste", ["style": two], on: &target)
        }
        #expect(target.style == .none && target.history.steps.isEmpty)
    }

    /// `style.panel` shows a section and records no step; with no kind it closes an open panel, and opens a closed one
    /// at the first enabled effect, else the drop shadow.
    @Test func panelIsNotAnEdit() throws {
        var target = StyleTestTarget()
        #expect(try run("style.panel", on: &target).undoStep == nil && target.panel == .dropShadow)
        _ = try run("style.panel", on: &target)
        #expect(target.panel == nil)
        _ = try run("style.add", ["kind": .string("bevel")], on: &target)
        _ = try run("style.panel", on: &target)
        #expect(target.panel == .bevel)
        _ = try run("style.panel", ["kind": .string("stroke")], on: &target)
        #expect(target.panel == .stroke && target.history.steps == ["Add Layer Style"])
    }

    /// Each intent's command reads back as the same intent and runs on a styled layer.
    @Test func intentCommandRoundTrips() throws {
        let intents: [StyleIntent] = [
            .toggle(.dropShadow, false), .toggle(.dropShadow, true), .set(.dropShadow, .object(["distance": .number(9)]), drag: nil),
            .set(.dropShadow, .object(["opacity": .number(0.5), "blend": .string("screen")]), drag: "t"), .preset("Outline"),
            .fillOpacity(0.25, drag: nil), .fillOpacity(0.5, drag: "f"), .show(.stroke), .show(nil),
        ]
        var target = StyleTestTarget()
        _ = try run("style.add", Self.shadow, on: &target)
        for intent in intents {
            #expect(Self.intent(intent.command) == intent)
            if case .preset = intent { continue }  // replaces the shadow the later intents edit
            _ = try catalog.run(intent.command.id, params: intent.command.params, on: &target)
        }
        #expect(target.style.fillOpacity == 0.5 && target.style.effect(.dropShadow)?.blendMode == .screen)
    }

    /// The intent a command id and params stand for, nil when they stand for none.
    static func intent(_ command: (id: String, params: JSONValue)) -> StyleIntent? {
        guard case .object(var fields) = command.params else { return nil }
        let drag: String? = if case .string(let token)? = fields["drag"] { token } else { nil }
        let kind: StyleKind? = if case .string(let raw)? = fields["kind"] { StyleKind(rawValue: raw) } else { nil }
        switch (command.id, fields["on"], fields["name"], fields["value"]) {
        case ("style.enable", .bool(let on)?, _, _): return kind.map { .toggle($0, on) }
        case ("style.preset", _, .string(let name)?, _): return .preset(name)
        case ("style.fill-opacity", _, _, .number(let value)?): return .fillOpacity(value, drag: drag)
        case ("style.panel", _, _, _): return .show(kind)
        case ("style.set", _, _, _):
            (fields["kind"], fields["drag"]) = (nil, nil)
            return kind.map { .set($0, .object(fields), drag: drag) }
        default: return nil
        }
    }
}
