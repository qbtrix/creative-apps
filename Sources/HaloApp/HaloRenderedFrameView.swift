// HaloRenderedFrameView.swift: the frame Render Frame made, shown over the
// artboard. A stub that draws nothing until render-out (#451) replaces this
// body to show `renderedFrame` and whether it is stale; the call site stays
// `init(model:perform:)`.
import HaloModel
import SwiftUI

struct HaloRenderedFrameView: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        EmptyView()
    }
}
