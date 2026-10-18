// LibraryGrid.swift: the photo grid, SuiteUI's ThumbnailGrid of the sorted
// photos at the catalog's cell size, and the ThumbnailItem a photo becomes:
// its held thumbnail (drawn through `Image(display:)`, aspect-fit by the
// grid; the placeholder fill while it loads), file name, and rating, flag
// and label badges. A reject is dimmed under SuiteUI's "Rejected" badge; a
// file that can't be read shows SuiteUI's unreadable mark. A cell's value is
// the catalog's `cellValue(for:)` ("ready 256×171 3 stars"), and its tooltip
// names the photo and its cull state ("IMG_0040: 1 star, Picked"), or why its
// file can't be read, so the flag glyph never stands alone. Each cell is
// identified `library.grid.cell.<photo id>` on the cell itself, never on the
// grid, so journeys and the app audit can find it. The cells on screen go to
// `menu.thumbnails.visibleChanged`, which requests their thumbnails. On
// appear and whenever the cell size or the display scale changes, the grid
// reports both to `menu.thumbnails.cellSizeChanged` (the scale a whole number
// ≥ 1, `LibraryCatalog.thumbnailScale`), which picks the thumbnail bucket.
// Values in, closures out; LibraryCatalog holds the state.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryGrid: View {
    let model: LibraryCatalog
    /// The window's menu; the cells on screen go to `menu.thumbnails.visibleChanged`.
    var menu = LibraryMenu()
    var onSelect: @MainActor (Set<String>) -> Void = { _ in }
    var onOpen: @MainActor (String) -> Void = { _ in }
    @Environment(\.displayScale) private var displayScale

    /// Each cell's identifier is this plus the photo's id.
    static let cellIdentifierPrefix = "library.grid.cell."

    var body: some View {
        let side = CGFloat(model.cellSize)
        let visibleChanged = menu.thumbnails.visibleChanged
        let cellSizeChanged = menu.thumbnails.cellSizeChanged
        let cell = [model.cellSize, LibraryCatalog.thumbnailScale(forDisplayScale: Double(displayScale))]
        ThumbnailGrid(
            model.sortedItems.map {
                ThumbnailItem<String>(
                    photo: $0, thumbnail: model.thumbnails[$0.id], value: model.cellValue(for: $0.id))
            },
            cellSize: CGSize(width: side, height: side * 3 / 4),
            selection: model.selection, onSelectionChange: onSelect, onOpen: onOpen,
            cellIdentifierPrefix: Self.cellIdentifierPrefix,
            onVisibleChange: { visibleChanged?($0) }
        )
        .onChange(of: cell, initial: true) { _, cell in
            guard cell.count == 2 else { return }
            cellSizeChanged?(cell[0], cell[1])
        }
    }
}

extension ThumbnailItem where ID == String {
    /// A grid cell for a photo: its thumbnail (nil draws the placeholder fill),
    /// file name, and rating, flag and label badges, dimmed for a reject and
    /// marked when its file can't be read, with `value` as its accessibility
    /// value and the photo's cull state as its help.
    init(photo: PhotoItem, thumbnail: DisplayImage? = nil, value: String? = nil) {
        self.init(
            id: photo.id, image: thumbnail.map(Image.init(display:)), caption: photo.name,
            badges: ThumbnailBadges(
                rating: photo.rating, isFlagged: photo.isFlagged,
                colorLabel: photo.label.map { (name: $0.rawValue, color: $0.color) },
                dimmed: photo.flag == .reject),
            accessibilityValue: value, help: Self.help(photo: photo),
            isUnreadable: photo.availability != .available)
    }

    /// "IMG_0040: 1 star, Picked"; why the file can't be read when it can't
    /// (the catalog's `cellHelp(for:)`, from the same `availability.help`).
    static func help(photo: PhotoItem) -> String {
        photo.availability.help ?? "\(photo.name): \(photo.cullSummary)"
    }

    /// A one-pixel sRGB image from RGBA8 bytes; the loupe stretches it to fill.
    static func image(rgba: [UInt8]) -> Image? {
        guard rgba.count == 4, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(rgba) as CFData),
              let pixel = CGImage(
                  width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: space,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return Image(decorative: pixel, scale: 1)
    }
}
