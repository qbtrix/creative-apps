// HaloTextInspector.swift: the TEXT slot of Halo's layer inspector. A stub
// that shows nothing until text (#430) replaces this body with a text layer's
// string, size and color; the call site stays `init(model:perform:)`.
import HaloModel
import SwiftUI

struct HaloTextInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        EmptyView()
    }
}
