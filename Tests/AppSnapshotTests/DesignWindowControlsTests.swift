// DesignWindowControlsTests.swift: design-window D0-7a on the hosted editor.
// With `cards` open on `.fake` and A selected, the floating tool box lists one
// `design.tool.*` entry per tool (Pen disabled, saying why), the canvas lists
// `design.canvas.page`, and the status line lists its tool and selection count,
// every id from DesignControlID.all, with no id shown twice. The Stroke
// section is SuiteUI's StrokeEditor alone (#3864): one Add Stroke on an
// unstroked layer, one Width and one Remove Stroke on a stroked one. The window
// toolbar's items register through SuiteWindow and are not hosted here.
// SwiftUI builds a hosting view's accessibility tree only for an assistive
// client, so the inventory stands in for the identifiers. macOS only.
#if canImport(AppKit)
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import SuiteUI

@MainActor
@Suite struct DesignWindowControlsTests {
    @Test func theWindowsOwnControlsListTheirIDs() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-2")
        let store = SuiteControlStore()
        let editor = DesignEditor(model: model, zoom: 0.5).environment(\.suiteControlStore, store)
        _ = try #require(render(editor, scheme: .light))
        #expect(store.inventory.violations().isEmpty)
        let controls = store.inventory.document().controls
        let ids = Set(controls.map(\.id))
        for tool in DesignTool.allCases {
            let entry = controls.first { $0.id == DesignControlID.tool(tool) }
            #expect(entry?.enabled == tool.isEnabled, "\(tool) in the tool box: \(String(describing: entry))")
            if !tool.isEnabled { #expect(entry?.reason?.isEmpty == false, "\(tool) is disabled without saying why") }
        }
        #expect(ids.contains(DesignControlID.canvas))
        #expect(ids.contains(DesignControlID.statusTool))
        #expect(ids.contains(DesignControlID.statusSelection))
        #expect(ids.contains("suite.stroke.add"), "A has no stroke, so the editor's Add Stroke shows")
        #expect(!ids.contains(DesignControlID.inspectorStrokeAdd), "a second Add Stroke beside the editor's (#3864)")
        let known = Set(DesignControlID.all)
        for id in ids where id.hasPrefix("design.") {
            #expect(known.contains(id), "\(id) is not in DesignControlID.all")
        }
    }

    /// #3864: a stroked layer's Stroke section has one Width and one Remove Stroke, the editor's.
    @Test func aStrokedLayerShowsOneWidthAndOneRemove() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-2")
        try model.setStyle(.stroke(.default))
        let store = SuiteControlStore()
        let editor = DesignEditor(model: model, zoom: 0.5).environment(\.suiteControlStore, store)
        _ = try #require(render(editor, scheme: .light))
        let ids = Set(store.inventory.document().controls.map(\.id))
        #expect(ids.contains("suite.stroke.width") && ids.contains("suite.stroke.remove"), "\(ids.sorted())")
        let twins = [DesignControlID.inspectorStrokeWidth, DesignControlID.inspectorStrokeRemove, DesignControlID.inspectorStrokeAdd]
        for twin in twins {
            #expect(!ids.contains(twin), "\(twin) beside the editor's own row (#3864)")
        }
    }
}
#endif
