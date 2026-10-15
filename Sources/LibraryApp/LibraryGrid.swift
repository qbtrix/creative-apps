// LibraryGrid.swift: the photo grid, SuiteUI's ThumbnailGrid of the sorted
// photos at the catalog's cell size, and the ThumbnailItem a photo becomes
// (its flat color, file name, and rating, flag and label badges). Values in,
// closures out; LibraryCatalog holds the state.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryGrid: View {
    let model: LibraryCatalog
    /// The window's menu; the thumbnails feature calls `menu.thumbnails` from here.
    var menu = LibraryMenu()
    var onSelect: @MainActor (Set<String>) -> Void = { _ in }
    var onOpen: @MainActor (String) -> Void = { _ in }

    var body: some View {
        let side = CGFloat(model.cellSize)
        ThumbnailGrid(
            model.sortedItems.map { ThumbnailItem<String>(photo: $0) }, cellSize: CGSize(width: side, height: side * 3 / 4),
            selection: model.selection, onSelectionChange: onSelect, onOpen: onOpen)
    }
}

extension ThumbnailItem where ID == String {
    /// A grid cell for a photo: its flat color, file name, and rating, flag and label badges.
    init(photo: PhotoItem) {
        self.init(
            id: photo.id, image: Self.image(rgba: photo.pixel), caption: photo.name,
            badges: ThumbnailBadges(
                rating: photo.rating, isFlagged: photo.isFlagged,
                colorLabel: photo.label.map { (name: $0.rawValue, color: $0.color) }))
    }

    /// A one-pixel sRGB image from RGBA8 bytes; the cell and the loupe stretch it to fill.
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
