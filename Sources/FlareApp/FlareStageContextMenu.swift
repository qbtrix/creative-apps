// FlareStageContextMenu.swift: the stage's context menu (stage-edit SE-3): Cut, Copy, Duplicate, Delete, then
// Bring Forward and Send Backward. The menu acts on what was right-clicked: FlareStage keeps the item under the
// pointer (`pointed`), each item is enabled as the Model's `contextClick` there would leave the selection, and
// choosing it sends that `.stage(.contextClick)` first, then the Edit or Object intent through `perform`. An item
// that can't act is disabled with `FlareWindow.editHelp`'s reason as its help. It also starts FlarePasteboardWatch,
// so the Edit menu's Paste follows the system pasteboard.
import FlareCore
import FlareModel
import SwiftUI

/// The stage item under the pointer and a scene point on it, kept by FlareStage for the context menu.
struct FlareStagePointer: Equatable {
    let point: Point
    let hit: StageAddress
}

struct FlareStageContextMenu: ViewModifier {
    let model: FlareWorkspace
    let zoom: Double
    /// The item under the pointer, which a right click selects before an item acts; nil over empty stage.
    let pointed: FlareStagePointer?
    let perform: @MainActor (FlareIntent) -> Void

    func body(content: Content) -> some View {
        let target = target
        content
            .contextMenu {
                item(.cut, target)
                item(.copy, target)
                item(.duplicate, target)
                item(.delete, target)
                Divider()
                item(.bringForward, target)
                item(.sendBackward, target)
            }
            .modifier(FlarePasteboardWatch())
    }

    /// The workspace as the right click leaves it, for each item's reason.
    private var target: FlareWorkspace {
        guard let pointed else { return model }
        var target = model
        target.contextClick(at: pointed.point, stageScale: zoom)
        return target
    }

    private func item(_ intent: FlareIntent.Edit, _ target: FlareWorkspace) -> some View {
        let title = FlareIntent.edit(intent).title
        let reason = FlareWindow.editHelp(intent, in: target, pasteboard: nil)
        let click = pointed.map { FlareIntent.stage(.contextClick(at: $0.point, stageScale: zoom)) }
        return Button(title) {
            if let click { perform(click) }
            perform(.edit(intent))
        }
        .disabled(reason != nil).help(reason ?? title)
    }
}
