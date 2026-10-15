// SelectionOverlay.swift: the selection over the canvas: SuiteUI's
// SelectionOutline (marching ants) and its element `photo.canvas.selection`,
// "Selection". Nothing without a selection.
import PhotoModel
import SuiteUI
import SwiftUI

struct SelectionOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double

    /// The selection's element; nil without one.
    var mark: PhotoCanvasMark? { model.selection.map { PhotoCanvasMark.selection($0.cgRect) } }

    var body: some View {
        if let selection = model.selection, let mark = mark {
            ZStack(alignment: .topLeading) {
                SelectionOutline(rect: selection.cgRect, zoom: zoom)
                PhotoCanvasMarkElement(mark: mark, zoom: zoom)
            }
        }
    }
}
