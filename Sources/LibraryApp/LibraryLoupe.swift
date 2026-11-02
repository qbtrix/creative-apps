// LibraryLoupe.swift: the loupe's photo on SuiteUI's CanvasViewport at the
// photo's own pixel size (a portrait photo stands taller than wide), drawn
// at `loupeZoom` against the fit the viewport measured. It reads as a photo
// viewer, not a design canvas: no rulers, and the whole loupe is in the dark
// scheme in both appearances, so the surround is the dark canvasSurround
// (docs/design.md allows a fixed dark surround for a media app). It shows the latest
// render (the grid thumbnail as a preview, then the full render, swapped
// with no animation), or a placeholder until one arrives: the photo's frame
// in a card tone with its name and size. A GPU frame (suite-imaging IM-11)
// is drawn by the window's `\.libraryLoupeGPU` into a canvas host: the base
// through the frame's develop steps, written on the GPU. Its help says
// why the file can't be read or the render failed. The name, "12 of 60" position and cull summary sit in a glass
// readout. Left and Right step through the sort; Escape, G or the glass
// Grid button at the top leading corner (`library.loupe.grid`) go back to
// the grid. The canvas pans on the other arrows, scroll and Space-drag, and
// a click on it gives it the keys. Pinch and its zoom keys go through
// `menu.view.zoomTo`, the measured fit through `menu.view.fitMeasured`
// (the loupe area fills both). While a crop draft is open (crop CR-6) the
// artboard is the straightened photo (`crop.canvas`): the unturned render
// turned by the draft's angle with `.rotationEffect` (a compositor transform,
// so a straighten step never waits for a render), under the crop frame
// overlay; a canvas drag moves the handle under its press (or the whole
// frame), Escape cancels and the arrows nudge the frame 1 px (Shift 10);
// otherwise the artboard is the photo at its stored crop (`crop.artboard`).
// The crop controls come from the window through `\.libraryCrop`. The photo
// carries Photo's Rotate Left and Rotate Right as accessibility actions
// (orientation-crop OC-9). Values in, closures out; LibraryCatalog holds the state.
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
    /// The crop handle the drag under way holds; nil between drags.
    @State private var grabbed: CropHandle?
    @Environment(\.libraryCrop) private var crop
    @Environment(\.libraryLoupeGPU) private var gpu

    var body: some View {
        let size = (crop.draft == nil ? nil : crop.canvas) ?? crop.artboard ?? model.loupePhotoSize
            ?? PixelSize(width: 1, height: 1)
        let document = CGSize(width: size.width, height: size.height)
        let fit = ZoomMath.fit(document: document, in: viewport)
        let zoom = model.loupeZoom.scale(fit: fit)
        CanvasViewport(
            documentSize: document, zoom: zoom, checkerboard: false, showsRulers: false, holdsRulerBand: false,
            onSize: { viewport = $0 }, onZoom: menu.view.zoomTo,
            // Outside crop mode a drag only gives the canvas focus, so its keys reach it.
            onDrag: { from, to in cropDrag(from: from, to: to, zoom: zoom) }, onDragEnd: { grabbed = nil }, onKey: key
        ) {
            if let draft = crop.draft, let canvas = crop.canvas, let photo = model.loupePhotoSize {
                // The unturned picture turned by the draft's angle on the GPU, centred
                // on the straightened canvas: a straighten step renders nothing.
                picture
                    .frame(width: Double(photo.width) * zoom, height: Double(photo.height) * zoom)
                    .rotationEffect(.degrees(draft.angle))
                    .frame(width: Double(canvas.width) * zoom, height: Double(canvas.height) * zoom)
            } else {
                picture
            }
        } overlay: {
            if crop.draft != nil { LibraryCropOverlay(crop: crop, zoom: zoom) }
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
        }
        // A photo viewer, not a design canvas: dark in both appearances, so the photo is the brightest thing.
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Loupe")
        .accessibilityIdentifier("library.loupe")
    }

    /// The latest render filling the artboard, or the placeholder: the photo's
    /// name and size on a card-toned frame of the photo's shape. One element
    /// either way, carrying `loupeValue` (`preview`, `full`, `loading`, …) and the help.
    private var picture: some View {
        Group {
            if let render = model.loupeRender, let program = model.loupeSteps, let gpu {
                EmbeddedCanvasHost(rendering: gpu.preference) {
                    gpu.draw(render.image, program: program, token: model.loupeShownToken, photoID: model.loupeItem?.id, into: $0)
                }
            } else if let render = model.loupeRender {
                Image(display: render.image).resizable()
            } else {
                ZStack {
                    // A card tone, not the surround, so the photo's frame shows before its pixels do.
                    SuiteColor.card
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
        .accessibilityAction(named: "Rotate Left") { menu.photo.rotateLeft?() }
        .accessibilityAction(named: "Rotate Right") { menu.photo.rotateRight?() }
    }

    /// A drag sample while cropping: the handle under the press (held until
    /// the drag ends) moves by the sample's step, in photo pixels.
    private func cropDrag(from: CGPoint, to: CGPoint, zoom: Double) {
        guard let drag = crop.drag, let frame = crop.frame else { return }
        let handle = grabbed ?? LibraryCropOverlay.handle(
            at: from, frame: CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height),
            radius: Double(SuiteSize.selectionHandleHit) / 2 / max(zoom, 0.001))
        if grabbed == nil { grabbed = handle }
        if to != from { drag(handle, to.x - from.x, to.y - from.y) }
    }

    /// While cropping, Escape cancels and the arrows nudge the frame 1 px
    /// (Shift 10). Otherwise Left and Right step photos (before the canvas
    /// pans on them); Escape and G go to the grid. Anything else, or with a
    /// command key, passes on.
    private func key(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return .ignored }
        if let drag = crop.drag {
            let step = press.modifiers.contains(.shift) ? 10.0 : 1.0
            switch press.key {
            case .escape: crop.cancel?()
            case .leftArrow: drag(.inside, -step, 0)
            case .rightArrow: drag(.inside, step, 0)
            case .upArrow: drag(.inside, 0, -step)
            case .downArrow: drag(.inside, 0, step)
            default: return .ignored
            }
            return .handled
        }
        switch press.key {
        case .leftArrow: onStep(-1)
        case .rightArrow: onStep(1)
        case .escape, "g", "G": onGrid()
        default: return .ignored
        }
        return .handled
    }
}
