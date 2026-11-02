// FlarePlace+Menu.swift (svg-place PF-3): File > Place… (built on `placeMenuSpec`) is on when `place.image` can run.
// A place (menu or drop) runs each file centred; the status line shows its report or refusal. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension FlareWorkspace {
    /// The tooltip of File > Place… when it can run.
    public static let placeMenuSummary = "Choose an SVG file to place as layers."
    /// The status line's words for a file Flare can't place.
    public static let placeFormatHelp = "Flare places SVG files."

    /// Why File > Place… can't run now: `place.image`'s reason; nil when it can.
    public var placeMenuHelp: String? { Self.catalog.availability("place.image", on: self).why }

    /// File > Place…'s spec over the window's `placeMenuHelp`: on exactly while it is nil; the window does the place.
    public static let placeMenuSpec: CommandSpec<String?> = .typed(
        "place.image", title: "Place…", summary: placeMenuSummary, kind: .edit, params: JSONValue.self,
        example: .object([:]), availability: { $0.map(Availability.unavailable) ?? .available }
    ) { (_: inout String?, _: JSONValue) throws -> JSONValue in
        throw CatalogError.unavailable(id: "place.image", why: "Run Place… from its window.")
    }

    /// Runs `place.image` on each file, centred in the scene. The status line then reads the place's report, or
    /// the first refusal, and the files after a refusal aren't placed.
    public mutating func place(_ files: [(name: String, data: Data)]) {
        for file in files {
            let command = PlaceIntent.place(name: file.name, data: file.data, at: nil).command
            do throws(CatalogError) {
                _ = try Self.catalog.run(command.id, params: command.params, on: &self)
            } catch {
                placeStatus = Self.placeRefusal(error)
                return
            }
            placeStatus = placeReport ?? "Placed \(file.name)."
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
}
