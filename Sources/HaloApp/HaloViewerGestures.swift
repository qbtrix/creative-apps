// HaloViewerGestures.swift: the viewer's pointer input over the artboard. A
// stub that takes no hits until layer-keys (#38) replaces this body with the
// drag that sends beginViewerDrag, moveViewerDrag and endViewerDrag; the call
// site stays `init(model:perform:)`.
import HaloModel
import SwiftUI

struct HaloViewerGestures: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        Color.clear.allowsHitTesting(false)
    }
}
