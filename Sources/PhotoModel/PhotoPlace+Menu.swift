// PhotoPlace+Menu.swift (place-image PP-3): what File > Place… and the canvas drop read and run. The menu item is
// built from `place.image`'s spec (`placeMenuSpec`): on when it can run, else off with its reason. A place runs each file
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
    /// The spec File > Place… is built from: `place.image` in the place catalog. Its availability turns the item
    /// on or off with the reason, and its summary is the tooltip when it can run.
    public static var placeMenuSpec: CommandSpec<PhotoWorkspace> { placeMenuSpec(in: placeCatalog) }

    /// `place.image` in `catalog`, else the kernel's place spec of that id, else one that never runs and says so.
    static func placeMenuSpec(in catalog: CommandCatalog<PhotoWorkspace>) -> CommandSpec<PhotoWorkspace> {
        catalog.spec("place.image") ?? PlaceCommands.specs(PhotoWorkspace.self).first { $0.id == "place.image" }
            ?? .typed("place.image", title: "Place Image", summary: placeMissing, kind: .edit, params: JSONValue.self,
                      example: .object([:]), availability: { _ in .unavailable(placeMissing) }) { _, _ in JSONValue.object([:]) }
    }

    /// Why Place can't run when no catalog has `place.image`.
    static let placeMissing = "Photo has no place.image command."

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
