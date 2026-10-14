// LibraryLoupe.swift: one photo fitted in SuiteUI's CanvasSurface at the
// photo's size, with its name and "12 of 60" position in a glass readout.
// Left and Right step through the sort; Escape or G go back to the grid. The
// view reads values and calls closures; LibraryCatalog holds the state.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryLoupe: View {
    let photo: PhotoItem
    let position: String
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
                        .padding(SuiteSize.canvasInset)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .bottom) {
                GlassPanel {
                    Text("\(photo.name)  ·  \(position)")
                        .font(SuiteFont.monospacedDigits)
                        .accessibilityIdentifier("library.loupe.position")
                }
                .padding(SuiteSpacing.l)
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
            // Focusable, it is one accessibility element; with no role it reads
            // as static text, and the app audit measured the photo as its ink.
            // A labelled container keeps the position readout inside it.
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Loupe")
            .accessibilityIdentifier("library.loupe")
    }
}
