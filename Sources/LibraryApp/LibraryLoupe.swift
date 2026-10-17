// LibraryLoupe.swift: one photo fitted in SuiteUI's CanvasSurface at the
// photo's size, with its name, "12 of 60" position and cull summary ("3 stars,
// Picked, Red label") in a glass readout.
// Left and Right step through the sort; Escape, G or the glass Grid button at
// the top leading corner (`library.loupe.grid`, so nobody needs the keys) go
// back to the grid. The button and the readout sit outside the focusable
// part, so neither takes the keys. The view reads values and calls closures;
// LibraryCatalog holds the state.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryLoupe: View {
    let photo: PhotoItem
    let position: String
    /// The window's menu; the loupe-viewport feature calls `menu.view` from here.
    var menu = LibraryMenu()
    /// The model's `loupeValue`, which the UI journeys read as the photo's value.
    var value: String? = nil
    /// While set, LibraryCropOverlay draws over the photo.
    var cropDraft: CropSettings? = nil
    var onStep: @MainActor (Int) -> Void = { _ in }
    var onGrid: @MainActor () -> Void = {}
    @FocusState private var isFocused: Bool

    private let artboard = CGSize(width: LibraryCatalog.loupeArtboard.width, height: LibraryCatalog.loupeArtboard.height)

    var body: some View {
        CanvasSurface(artboard: artboard)
            // CanvasSurface draws a flat artboard; until it takes content, the
            // photo covers the artboard's fitted frame, matching its layout.
            .overlay {
                if let image = ThumbnailItem<String>.image(rgba: photo.pixel) {
                    image.resizable()
                        .interpolation(.none)
                        .aspectRatio(artboard, contentMode: .fit)
                        .frame(maxWidth: artboard.width, maxHeight: artboard.height)
                        .overlay {
                            if let cropDraft { LibraryCropOverlay(cropDraft: cropDraft) }
                        }
                        .padding(SuiteSize.canvasInset)
                        .accessibilityLabel(photo.name)
                        .accessibilityValue(value ?? "")
                        .accessibilityIdentifier("library.loupe.photo")
                }
            }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onAppear { isFocused = true }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .escape, "g"]) { press in
                switch press.key {
                case .leftArrow: onStep(-1)
                case .rightArrow: onStep(1)
                default: onGrid()
                }
                return .handled
            }
            // After the focus modifiers, so the readout is never the focusable element.
            .overlay(alignment: .bottom) {
                GlassPanel {
                    Text(LibraryCatalog.loupeReadout(for: photo, position: position))
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
            // A focusable view whose only element was the readout turned it into
            // static text the size of the whole loupe, and the app audit read
            // the photo as its ink. Now the photo is an image element and the
            // readout sits outside the focusable part, so this is a group and
            // the readout keeps its own frame.
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Loupe")
            .accessibilityIdentifier("library.loupe")
    }
}
