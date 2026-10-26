// PhotoWindow+Styling.swift: the layer-style area of a Photo window (layer
// styles PY-2): Layer > Layer Style… and the Layers bar's fx open SuiteUI's
// LayerStylePanel as a sheet while the workspace's `stylePanel` is set; its
// intents run through the catalog (PhotoMenuState's PhotoWorkspace extension), Copy and Paste Layer
// Style go through LayerStylePasteboard, and Done, Escape or a dismiss close
// it with `showStylePanel(nil)`. A refused command says why in the window's
// problem alert. PhotoStyleArea attaches the sheet, PhotoStyleSheet
// (PhotoStyleSheet+Suite). Values in, intents out.
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI

/// What the layer-style area can be asked to do.
enum PhotoStyleIntent {
    /// One LayerStylePanel intent; `.show` opens or closes the panel.
    case panel(StyleIntent)
    /// Copy, Paste and Clear Layer Style on the selected layer.
    case copy, paste, clear
}

extension PhotoWindow {
    func performStyle(_ intent: PhotoStyleIntent) {
        do {
            switch intent {
            case .panel(let intent): try model.runStyleIntent(intent)
            case .copy: LayerStylePasteboard.write(try model.copyLayerStyle())
            case .paste: if let style = LayerStylePasteboard.read() { try model.pasteLayerStyle(style) }
            case .clear: try model.clearLayerStyle()
            }
        } catch {
            problem = PhotoProblem("The layer style can't be changed.", "\(error)")
        }
    }
}

/// Shows PhotoStyleSheet while the workspace's style panel is open; a dismiss closes it.
struct PhotoStyleArea: ViewModifier {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { model.stylePanel != nil },
                                           set: { if !$0 { perform(.style(.panel(.show(nil)))) } })) {
            PhotoStyleSheet(model: model, perform: perform)
        }
    }
}
