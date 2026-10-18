// ToolbarPickingTests.swift: ToolbarGroup's `.floating` palette asks its
// picking rule (SuiteToolPicking by default) for each tool's tooltip and for
// the tool a key picks, and a registered tool's reason is that tooltip;
// `.rail` keeps the action's own help and entry and picks nothing by key
// (EC-8). No rendering. macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

/// A rule that answers in its own words, so a result that came from it is plain.
private struct EchoToolPicking: ToolPicking {
    func tool(forKey key: Character, in tools: [ToolFace]) -> String? { tools.last?.id }
    func help(for tool: ToolFace) -> String { "rule: \(tool.id)" }
    func violations(in tools: [ToolFace]) -> [String] { [] }
}

/// Computed, since a ToolbarAction (it holds its handler) is not Sendable.
private var pickingTools: [ToolbarAction] {
    [
        ToolbarAction("Eraser", systemImage: "eraser", unavailableHelp: "Open a layer to erase.", shortcut: "b",
                      identifier: "t.eraser"),
        ToolbarAction("Brush", systemImage: "paintbrush", shortcut: "b", identifier: "t.brush"),
        ToolbarAction("Hand", systemImage: "hand.raised"),
    ]
}

@Test func aFloatingToolsHelpComesFromThePickingRule() {
    let live = SuiteToolPicking()
    for action in pickingTools {
        #expect(ToolbarGroup.tooltip(action, style: .floating) == live.help(for: ToolbarGroup.face(action)))
        #expect(ToolbarGroup.tooltip(action, style: .floating, picking: EchoToolPicking()) == "rule: \(action.title)")
    }
    #expect(ToolbarGroup.tooltip(pickingTools[1], style: .floating) == "Brush (B)")
    #expect(ToolbarGroup.tooltip(pickingTools[0], style: .floating) == "Open a layer to erase.")
}

@Test func aFloatingKeyPickComesFromThePickingRule() {
    #expect(ToolbarGroup.pick("b", modifiers: [], in: pickingTools, style: .floating)?.id == "Brush")
    #expect(ToolbarGroup.pick("B", modifiers: .shift, in: pickingTools, style: .floating)?.id == "Brush")
    #expect(ToolbarGroup.pick("h", modifiers: [], in: pickingTools, style: .floating) == nil)
    let echoed = ToolbarGroup.pick("z", modifiers: [], in: pickingTools, style: .floating, picking: EchoToolPicking())
    #expect(echoed?.id == "Hand")
}

@Test func aFloatingKeyPickSkipsCommandKeysAndLongerText() {
    for held: EventModifiers in [.command, .control, .option] {
        #expect(ToolbarGroup.pick("b", modifiers: held, in: pickingTools, style: .floating) == nil)
    }
    #expect(ToolbarGroup.pick("bb", modifiers: [], in: pickingTools, style: .floating) == nil)
    #expect(ToolbarGroup.pick("", modifiers: [], in: pickingTools, style: .floating) == nil)
}

@Test func aRegisteredFloatingToolsReasonIsItsHelp() {
    for action in pickingTools {
        let entry = ToolbarGroup.entry(action, style: .floating, picking: EchoToolPicking())
        #expect(entry?.reason == (action.isEnabled ? nil : "rule: \(action.title)"))
        let live = ToolbarGroup.entry(action, style: .floating)
        #expect(live?.reason == (action.isEnabled ? nil : ToolbarGroup.tooltip(action, style: .floating)))
        #expect(live?.id == action.identifier)
        #expect(live?.enabled == (action.identifier == nil ? nil : action.isEnabled))
    }
    #expect(ToolbarGroup.entry(pickingTools[0], style: .floating)?.reason == "Open a layer to erase.")
}

@Test func theRailKeepsTheActionsOwnHelpEntryAndNoKeys() {
    for action in pickingTools {
        #expect(ToolbarGroup.tooltip(action, style: .rail, picking: EchoToolPicking()) == action.help)
        #expect(ToolbarGroup.entry(action, style: .rail, picking: EchoToolPicking()) == action.controlEntry())
    }
    #expect(ToolbarGroup.pick("b", modifiers: [], in: pickingTools, style: .rail) == nil)
    #expect(ToolbarGroup.pick("z", modifiers: [], in: pickingTools, style: .rail, picking: EchoToolPicking()) == nil)
}

@Test func toolFadesReportOnTheToolSeries() {
    #expect(ToolFade.series == "tool")
}
