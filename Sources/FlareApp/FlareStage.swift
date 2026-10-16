// FlareStage.swift: the stage, the top of Flare's content. Today it shows the
// scene's artboard (CanvasSurface) with the floating glass tool palette, each
// tool enabled or disabled with `help`'s reason; a click chooses the tool
// through `perform`. DK-8 fills it: the draw list on CanvasViewport, the
// marks overlay and drags as `.stage` intents. It only reads `model`.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareStage: View {
    let model: FlareWorkspace
    let zoom: Double?
    let showsRulers: Bool
    let showsGuides: Bool
    let perform: @MainActor (FlareIntent) -> Void
    let help: @MainActor (FlareIntent) -> String?

    var body: some View {
        if let scene = model.selectedScene {
            CanvasSurface(artboard: CGSize(width: scene.width, height: scene.height)) {
                ToolbarGroup(palette, axis: .vertical, style: .floating)
            }
        }
    }

    /// The palette: V A R E P, each with its reason when it can't act.
    private var palette: [ToolbarAction] {
        FlareTool.allCases.map { tool in
            let intent = FlareIntent.tools(.choose(tool))
            return ToolbarAction(
                tool.title, systemImage: tool.systemImage, isSelected: tool == model.tool,
                unavailableHelp: help(intent), shortcut: tool.shortcut
            ) { perform(intent) }
        }
    }
}
