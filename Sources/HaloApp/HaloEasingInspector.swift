// HaloEasingInspector.swift: the EASING slot of Halo's layer inspector. A
// stub that shows nothing until easing (#428) replaces this body with the
// selected keys' easing; the call site stays `init(model:perform:)`.
import HaloModel
import SwiftUI

struct HaloEasingInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        EmptyView()
    }
}
