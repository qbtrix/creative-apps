// DesignContractLawTests.swift: the help law (EditContracts.swift, blueprint 7.5)
// over every tier-1 conformance. For each use case that has a help, every command
// and every selection in {none, A, A+B, A+B+C, Locked, Hidden, Pair} on the
// `cards` fixture: help nil means the write throws nothing but `.unchanged`;
// help non-nil means it throws. Zoom to Selection's write is `rectToShow`: nil
// counts as a refusal. Marquee, copySubtree and the file codec have no help, so
// the law has nothing to check there. `DesignContractLaw` is the reusable
// checker: D0-2b reruns it on `.live` once the Live stubs are wired. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

/// Checks the help law over every tier-1 slot of a service set and collects each break.
struct DesignContractLaw {
    struct Violation: CustomStringConvertible {
        let slot, command, selection: String
        let help: String?
        let outcome: String
        var description: String { "\(slot).\(command) on \(selection): help \(help ?? "nil"), \(outcome)" }
    }

    /// The selections the law runs on, by name, as `cards` ids (primary last).
    static let selections: [(name: String, ids: [String])] = [
        ("none", []), ("A", ["node-2"]), ("A+B", ["node-2", "node-3"]), ("A+B+C", ["node-2", "node-3", "node-4"]),
        ("Locked", ["node-9"]), ("Hidden", ["node-10"]), ("Pair", ["node-6"]),
    ]

    private(set) var violations: [Violation] = []
    private(set) var slots: Set<String> = []
    private(set) var checks = 0

    /// One help and its write: nil help allows only success or `.unchanged`; a help requires a throw.
    mutating func check(_ slot: String, _ command: String, _ selection: String, help: String?,
                        _ write: () throws(DesignRefusal) -> Void) {
        let outcome: String
        let broken: Bool
        do {
            try write()
            (outcome, broken) = ("wrote", help != nil)
        } catch .unchanged {
            (outcome, broken) = ("threw .unchanged", false)
        } catch {
            (outcome, broken) = ("threw \(error)", help == nil)
        }
        checks += 1
        slots.insert(slot)
        if broken { violations.append(Violation(slot: slot, command: command, selection: selection, help: help, outcome: outcome)) }
    }

    /// Every tier-1 command of `services` on `page`, for every selection.
    static func check(_ services: DesignServices, on page: DesignPage) -> DesignContractLaw {
        var law = DesignContractLaw()
        for (sel, ids) in selections {
            law.checkSelect(services, ids, sel, page)
            law.checkArrange(services, ids, sel, page)
        }
        return law
    }

    private static func mint() -> DesignIDMint { DesignIDMint(taken: [], after: 100) }

    private mutating func checkSelect(_ s: DesignServices, _ ids: [String], _ sel: String, _ page: DesignPage) {
        let t = s.transforming
        let help = t.transformHelp(ids, on: page)
        check("transforming", "move", sel, help: help) { () throws(DesignRefusal) in _ = try t.move(ids, by: DesignPoint(x: 10, y: 10), on: page) }
        for handle in DesignHandle.allCases {
            check("transforming", "resize \(handle)", sel, help: help) { () throws(DesignRefusal) in
                _ = try t.resize(ids, handle: handle, by: DesignPoint(x: 15, y: 15), modifiers: [], on: page)
            }
        }
        for direction in DesignDirection.allCases {
            for large in [false, true] {
                check("transforming", "nudge \(direction) \(large)", sel, help: help) { () throws(DesignRefusal) in
                    _ = try t.nudge(ids, direction, large: large, on: page)
                }
            }
        }
        check("transforming", "delete", sel, help: help) { () throws(DesignRefusal) in _ = try t.delete(ids, on: page) }
        let a = s.aligning
        for edge in DesignAlignEdge.allCases {
            check("aligning", "align \(edge)", sel, help: a.alignHelp(edge, ids, on: page)) { () throws(DesignRefusal) in
                _ = try a.align(edge, ids, on: page)
            }
        }
        for axis in DesignDistributeAxis.allCases {
            check("aligning", "distribute \(axis)", sel, help: a.distributeHelp(axis, ids, on: page)) { () throws(DesignRefusal) in
                _ = try a.distribute(axis, ids, on: page)
            }
        }
        let f = s.framing
        check("framing", "rectToShow", sel, help: f.framingHelp(ids, on: page)) { () throws(DesignRefusal) in
            guard f.rectToShow(ids, on: page) != nil else { throw .nothingSelected }
        }
    }

    private mutating func checkArrange(_ s: DesignServices, _ ids: [String], _ sel: String, _ page: DesignPage) {
        let d = s.duplicating
        for offset in [DesignPoint(x: 10, y: 10), DesignPoint(x: 0, y: 0)] {
            check("duplicating", "duplicate \(offset)", sel, help: d.duplicateHelp(ids, on: page)) { () throws(DesignRefusal) in
                var m = Self.mint()
                _ = try d.duplicate(ids, offset: offset, on: page, mint: &m)
            }
        }
        let g = s.grouping
        check("grouping", "group", sel, help: g.groupHelp(ids, on: page)) { () throws(DesignRefusal) in
            var m = Self.mint()
            _ = try g.group(ids, on: page, mint: &m)
        }
        check("grouping", "ungroup", sel, help: g.ungroupHelp(ids, on: page)) { () throws(DesignRefusal) in _ = try g.ungroup(ids, on: page) }
        let c = s.clipboard
        check("clipboard", "copy", sel, help: c.copyHelp(ids, on: page)) { () throws(DesignRefusal) in _ = try c.encode(ids, on: page) }
        let copied = (try? c.encode(ids, on: page)) ?? Data()
        for (name, data) in [("copied", copied), ("junk", Data("not layers".utf8))] {
            for parent in [nil, "node-1"] as [String?] {
                check("clipboard", "paste \(name) into \(parent ?? "nil")", sel, help: c.pasteHelp(data)) { () throws(DesignRefusal) in
                    var m = Self.mint()
                    _ = try c.paste(data, into: parent, on: page, mint: &m)
                }
            }
        }
        let o = s.ordering
        let id = ids.last ?? "node-404"
        for parent in [nil, "node-1", "node-6", "node-2"] as [String?] {
            for index in [0, 3, 99] {
                check("ordering", "move into \(parent ?? "nil") at \(index)", sel,
                      help: o.moveHelp(id, into: parent, at: index, on: page)) { () throws(DesignRefusal) in
                    _ = try o.move(id, into: parent, at: index, on: page)
                }
            }
        }
        for step in DesignArrangeStep.allCases {
            check("ordering", "arrange \(step)", sel, help: o.arrangeHelp(step, ids, on: page)) { () throws(DesignRefusal) in
                _ = try o.arrange(step, ids, on: page)
            }
        }
        checkStyle(s.styling, ids, sel, page)
    }

    private mutating func checkStyle(_ st: any StyleEditing, _ ids: [String], _ sel: String, _ page: DesignPage) {
        func help(_ p: DesignStyleProperty) -> String? { st.styleHelp(p, ids, on: page) }
        for field in DesignFrameField.allCases {
            for value in [0.0, 120.0] {
                check("styling", "setFrame \(field) \(value)", sel, help: help(.frame)) { () throws(DesignRefusal) in
                    _ = try st.setFrame(field, to: value, ids, on: page)
                }
            }
        }
        check("styling", "setFill", sel, help: help(.fill)) { () throws(DesignRefusal) in _ = try st.setFill(.black, ids, on: page) }
        check("styling", "setCornerRadius", sel, help: help(.cornerRadius)) { () throws(DesignRefusal) in
            _ = try st.setCornerRadius(8, ids, on: page)
        }
        check("styling", "setOpacity", sel, help: help(.opacity)) { () throws(DesignRefusal) in _ = try st.setOpacity(0.5, ids, on: page) }
        for stroke in [DesignStroke.default, nil] as [DesignStroke?] {
            check("styling", "setStroke \(stroke == nil ? "nil" : "default")", sel, help: help(.stroke)) { () throws(DesignRefusal) in
                _ = try st.setStroke(stroke, ids, on: page)
            }
        }
        check("styling", "setTextStyle", sel, help: help(.textStyle)) { () throws(DesignRefusal) in
            _ = try st.setTextStyle(.default, ids, on: page)
        }
    }
}

/// Claims every transform works (help always nil), so a refused write on an empty selection breaks the law.
private struct BrokenTransforming: SelectionTransforming {
    let base = FakeTransforming()
    func transformHelp(_ ids: [String], on page: DesignPage) -> String? { nil }
    func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.move(ids, by: delta, on: page)
    }
    func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.resize(ids, handle: handle, by: delta, modifiers: modifiers, on: page)
    }
    func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.nudge(ids, direction, large: large, on: page)
    }
    func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { try base.delete(ids, on: page) }
}

/// Says Align is off yet aligns anyway, so a write that succeeds under a help breaks the law.
private struct BrokenAligning: LayerAligning {
    let base = FakeAligning()
    func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String? { "Aligning is off." }
    func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.align(edge, ids, on: page)
    }
    func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String? {
        base.distributeHelp(axis, ids, on: page)
    }
    func distribute(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.distribute(axis, ids, on: page)
    }
}

@Suite struct DesignContractLawTests {
    let page = DesignFixtures.cards.selectedPage
    let tier1: Set<String> = ["transforming", "aligning", "framing", "duplicating", "grouping", "clipboard", "ordering", "styling"]

    @Test(arguments: ["fake", "live"])
    func helpLawHoldsOnEveryTier1Conformance(_ name: String) throws {
        let page = try #require(page)
        let law = DesignContractLaw.check(name == "fake" ? .fake : .live, on: page)
        #expect(law.slots == tier1)
        #expect(law.checks == 66 * DesignContractLaw.selections.count)
        #expect(law.violations.isEmpty, "\(law.violations)")
    }

    @Test func checkerCatchesABrokenConformance() throws {
        let page = try #require(page)
        var services = DesignServices.fake
        services.transforming = BrokenTransforming()
        services.aligning = BrokenAligning()
        let law = DesignContractLaw.check(services, on: page)
        #expect(Set(law.violations.map(\.slot)) == ["transforming", "aligning"])
        // Help nil yet refused: moving nothing throws .nothingSelected.
        #expect(law.violations.contains { $0.command == "move" && $0.selection == "none" && $0.help == nil })
        // Help non-nil yet written: aligning A to the left of the page succeeds.
        #expect(law.violations.contains { $0.command == "align left" && $0.selection == "A" && $0.outcome == "wrote" })
        #expect(!law.violations.contains { $0.command.hasPrefix("distribute") })
    }
}
