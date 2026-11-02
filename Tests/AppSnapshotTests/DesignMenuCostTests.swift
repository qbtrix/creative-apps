// DesignMenuCostTests.swift: the window's DesignMenu is rebuilt on every window
// body (the focused scene value), and a press or release on the canvas runs that
// body. Each Object > Arrange help is a whole arrange trial on the page's layer
// tree, about 10 ms on `crowd`, so the menu asks the ordering service once per
// step: Object > Arrange's own help comes from those four, not four more trials.
// A counting wrapper around LiveOrdering proves it. macOS only.
#if canImport(AppKit)
import DesignModel
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignMenuCostTests {
    @Test func arrangeTrialsOncePerStep() {
        let calls = Calls()
        var model = DesignWorkspace()
        var services = DesignServices.live
        services.ordering = CountingOrdering(calls: calls)
        model.useServices(services)
        model.newFile()
        model.selectTool(.rectangle)
        model.drag(from: DesignPoint(x: 100, y: 100), to: DesignPoint(x: 300, y: 240))
        model.endDrag()
        #expect(model.selectedNodeID != nil)
        let menu = DesignMenu(model: model, perform: { _ in })
        #expect(calls.arrangeHelps == DesignArrangeStep.allCases.count)
        // The submenu's help still follows the help law: one step can run, so Arrange is on.
        #expect(menu.arrangeMenuHelp == model.arrangeMenuHelp)
    }
}

private final class Calls: @unchecked Sendable {
    var arrangeHelps = 0
}

/// LiveOrdering, counting its arrange helps.
private struct CountingOrdering: LayerOrdering {
    let calls: Calls
    let live = LiveOrdering()

    func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String? {
        live.moveHelp(id, into: parentID, at: index, on: page)
    }

    func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try live.move(id, into: parentID, at: index, on: page)
    }

    func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String? {
        calls.arrangeHelps += 1
        return live.arrangeHelp(step, ids, on: page)
    }

    func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try live.arrange(step, ids, on: page)
    }
}
#endif
