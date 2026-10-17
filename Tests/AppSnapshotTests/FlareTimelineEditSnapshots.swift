// FlareTimelineEditSnapshots.swift: timeline key editing (IT-7) on `bounce`, macOS only. flare-timeline-edit.png:
// Ball's key dragged 24 to 28, selected. flare-timeline-label.png: label "hit" at 29 on the ruler.
// flare-timeline-refused.png: a drag of that key onto 36 refused, the key at 28 and the reason shown.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareTimelineEditSnapshots {
    @Test func edit() throws {
        let model = Self.dragged()
        #expect(model.selectedKeys == [KeyRef(layerID: "ball", property: nil, frame: 28)])
        #expect(model.undoActionName == "Undo Move Keyframe" && model.timelineError == nil)
        try snapshot(timeline(model), name: "flare-timeline-edit", scheme: .light)
    }

    @Test func label() throws {
        var model = Self.dragged()
        model.setCurrentFrame(29)
        model.setLabel("hit")
        #expect(model.timelineLabels[29] == "hit")
        try snapshot(timeline(model), name: "flare-timeline-label", scheme: .light)
    }

    @Test func refused() throws {
        var model = Self.dragged()
        let before = model.document
        model.moveSelectedKeys(by: 8, dragStart: 28)
        model.endKeyDrag()
        #expect(model.document == before && model.timelineError != nil)
        try snapshot(timeline(model), name: "flare-timeline-refused", scheme: .light)
    }

    /// The Model's menu Add Label has no name to set, so it is disabled and points at the context menu; delete
    /// and move need a selected key.
    @Test func helpSaysWhy() {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        #expect(FlareWindow.timelineHelp(.removeKeys, in: model) == FlareWorkspace.selectKeyFirst)
        #expect(FlareWindow.timelineHelp(.setLabel(nil), in: model) != nil)
        #expect(FlareWindow.timelineHelp(.insertFrames(1), in: model) == nil)
        model.selectKey(KeyRef(layerID: "ball", property: nil, frame: 12), extending: false)
        #expect(FlareWindow.timelineHelp(.removeKeys, in: model) == nil)
        #expect(FlareWindow.timelineHelp(.setLabel("hit"), in: model) == nil)
    }

    /// Ball's key 24 dragged four frames to 28 as one drag, the playhead at 12.
    private static func dragged() -> FlareWorkspace {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(12)
        model.selectKey(KeyRef(layerID: "ball", property: nil, frame: 24), extending: false)
        for _ in 0..<4 { model.moveSelectedKeys(by: 1, dragStart: 24) }
        model.endKeyDrag()
        return model
    }

    private func timeline(_ model: FlareWorkspace) -> some View {
        FlareTimeline(model: model, zoom: nil, perform: { _ in }, tick: { _, _ in false })
            .frame(width: SuiteSize.windowLaunch.width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
