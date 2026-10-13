// DesignTextEditor.swift: the inline text editor over the canvas. It is laid out
// at the artboard's size (the document at `zoom`) as the last child of the
// canvas overlay, so a text field can sit over the node being edited. Nothing
// to show until the text slice builds it.
import DesignModel
import SwiftUI

struct DesignTextOverlay: View {
    let model: DesignWorkspace
    let zoom: Double
    var perform: DesignPerform = { _ in }

    var body: some View {
        EmptyView()
    }
}
