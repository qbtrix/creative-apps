// SelectOptions.swift: the area tools' options in the inspector (area-selection AR-11): SuiteUI's AreaToolOptions on
// the workspace's area options. A shape chip picks its tool (the Marquee is the rectangle); every other change goes
// to the workspace as the new options. Values in, intents out.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct SelectOptions: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        AreaToolOptions(options: Self.options(model)) { control, next in
            if control == .tool { return perform(.tool(Self.tool(next.tool))) }
            perform(.select(.options(PhotoAreaOptions(
                mode: next.mode, feather: next.feather, tolerance: next.tolerance, contiguous: next.contiguous, allLayers: next.allLayers))))
        }
    }

    /// The workspace's area options with its tool as an area shape.
    nonisolated static func options(_ model: PhotoWorkspace) -> AreaOptions {
        let o = model.areaOptions
        return AreaOptions(tool: AreaTool(rawValue: model.tool.rawValue) ?? .rect, mode: o.mode, feather: o.feather,
                           tolerance: o.tolerance, contiguous: o.contiguous, allLayers: o.allLayers)
    }

    /// The palette tool for an area shape: the Marquee draws the rectangle.
    nonisolated static func tool(_ shape: AreaTool) -> PhotoTool { PhotoTool(rawValue: shape.rawValue) ?? .marquee }
}
