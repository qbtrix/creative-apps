// PhotoPlace+Menu.swift (place-image PP-3): what File > Place… and the canvas drop read and run. The menu item is
// on when `place.image` can run and the panel can choose, else off with the first reason. A place runs each file
// through `place.image` (the catalog's once PP-6 registers it, else the place specs on their own), centred or at
// the drop point, and a refusal goes to the status line. A drop's point comes in the artboard's points at the
// canvas zoom. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension PhotoWorkspace {
    /// The tooltip of File > Place… when it can run.
    public static let placeMenuSummary = "Choose a PNG or JPEG to place as a new layer."

    /// Why File > Place… can't run now: `place.image`'s reason, else the panel's (`panelHelp`); nil when it can.
    public func placeMenuHelp(panelHelp: String?) -> String? {
        Self.placeCatalog.availability("place.image", on: self).why ?? panelHelp
    }

    /// The document point under a drop at (`x`, `y`) in the artboard drawn at `zoom`; a zoom that isn't a
    /// positive finite number is 1, as the canvas layout takes it.
    public static func placePoint(x: Double, y: Double, zoom: Double) -> Point {
        let scale = zoom.isFinite && zoom > 0 ? zoom : 1
        return Point(x: x / scale, y: y / scale)
    }

    /// Runs `place.image` on each file, centred or at `at`; the first refusal goes to the status line and the
    /// files after it aren't placed.
    public mutating func place(_ files: [(name: String, data: Data)], at: Point?) {
        for file in files {
            let command = PlaceIntent.place(name: file.name, data: file.data, at: at).command
            do throws(CatalogError) {
                _ = try Self.placeCatalog.run(command.id, params: command.params, on: &self)
            } catch {
                statusMessage = Self.placeRefusal(error)
                return
            }
        }
    }

    /// A refusal in the status line's words: the reason alone, not the command's id.
    static func placeRefusal(_ error: CatalogError) -> String {
        switch error {
        case .unavailable(_, let why): why
        case .failed(_, let message): message
        default: error.description
        }
    }

    /// The catalog `place.image` runs through: Photo's once it registers the place specs (PP-6), else those specs alone.
    static let placeCatalog = catalog.spec("place.image") != nil ? catalog
        : (try? CommandCatalog<PhotoWorkspace>(app: "photo", PlaceCommands.specs(PhotoWorkspace.self),
                                               history: { $0.history.kernel })) ?? .empty(app: "photo")
}
