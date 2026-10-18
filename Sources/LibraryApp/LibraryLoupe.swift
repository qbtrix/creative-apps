// LibraryLoupe.swift: the loupe's photo on SuiteUI's CanvasViewport at the
// photo's own pixel size (a portrait photo stands taller than wide), drawn
// at `loupeZoom` against the fit the viewport measured. It shows the latest
// render (the grid thumbnail as a preview, then the full render, swapped
// with no animation), or a placeholder with the photo's name and size until
// one arrives. Its help says why the file can't be read or the render
// failed. The name, "12 of 60" position and cull summary sit in a glass
// readout. Left and Right step through the sort; Escape, G or the glass
// Grid button at the top leading corner (`library.loupe.grid`) go back to
// the grid. The canvas pans on the other arrows, scroll and Space-drag, and
// a click on it gives it the keys. Pinch and its zoom keys go through
// `menu.view.zoomTo`, the measured fit through `menu.view.fitMeasured`
// (the loupe area fills both). Values in, closures out; LibraryCatalog
// holds the state.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryLoupe: View {
    let model: LibraryCatalog
    /// The window's menu: its View items zoom and keep the measured fit.
    var menu = LibraryMenu()
    var onStep: @MainActor (Int) -> Void = { _ in }
    var onGrid: @MainActor () -> Void = {}
    /// The viewport's size in points, which the fit is measured against.
    @State private var viewport: CGSize = .zero

    var body: some View {
        let size = model.loupePhotoSize ?? PixelSize(width: 1, height: 1)
        let document = CGSize(width: size.width, height: size.height)
        let fit = ZoomMath.fit(document: document, in: viewport)
        CanvasViewport(
            documentSize: document, zoom: model.loupeZoom.scale(fit: fit), checkerboard: false,
            onSize: { viewport = $0 }, onZoom: menu.view.zoomTo,
            // No tool draws here: a drag only gives the canvas focus, so its keys reach it.
            onDrag: { _, _ in }, onKey: key
        ) {
            picture
        } overlay: {
            if let cropDraft = model.cropDraft { LibraryCropOverlay(cropDraft: cropDraft) }
        }
        .onChange(of: fit, initial: true) { _, measured in menu.view.fitMeasured?(measured) }
        .overlay(alignment: .bottom) {
            GlassPanel {
                Text(model.loupeReadout ?? "")
                    .font(SuiteFont.monospacedDigits)
                    .accessibilityIdentifier("library.loupe.position")
            }
            .padding(SuiteSpacing.l)
        }
        .overlay(alignment: .topLeading) {
            Button(action: onGrid) {
                GlassPanel { Label("Grid", systemImage: "chevron.left") }
                    .frame(minHeight: SuiteSize.toolButton)
                    .contentShape(.rect)
            }
            .buttonStyle(HoverButtonStyle())
            .help("Back to the grid (Esc or G)")
            .accessibilityLabel("Grid")
            .libraryControl(id: "library.loupe.grid", enabled: true, help: nil)
            .padding(SuiteSpacing.l)
            // Clear of the rulers.
            .padding([.top, .leading], SuiteSize.ruler)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Loupe")
        .accessibilityIdentifier("library.loupe")
    }

    /// The latest render filling the artboard, or the placeholder: the photo's
    /// name and size on the surround color. One element either way, carrying
    /// `loupeValue` (`preview`, `full`, `loading`, …) and the help.
    private var picture: some View {
        Group {
            if let render = model.loupeRender {
                Image(display: render.image).resizable()
            } else {
                ZStack {
                    SuiteColor.canvasSurround
                    Text(model.loupePlaceholder ?? "")
                        .font(SuiteFont.monospacedDigits)
                        .foregroundStyle(SuiteColor.secondaryText)
                }
            }
        }
        // The preview-to-full swap never animates (Reduce Motion included).
        .transaction { $0.animation = nil }
        .help(model.loupeHelp ?? "")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.loupeItem?.name ?? "")
        .accessibilityValue(model.loupeValue ?? "")
        .accessibilityHint(model.loupeHelp ?? "")
        .accessibilityIdentifier("library.loupe.photo")
    }

    /// Left and Right step photos (before the canvas pans on them); Escape and
    /// G go to the grid. Anything else, or with a command key, passes on.
    private func key(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return .ignored }
        switch press.key {
        case .leftArrow: onStep(-1)
        case .rightArrow: onStep(1)
        case .escape, "g", "G": onGrid()
        default: return .ignored
        }
        return .handled
    }
}
