// DesignPlace+Inspector.swift (placed-images PD-u, PD-4): what File > Place…, a drop and the Picture section decide:
// whether a place fills the selection or adds a new layer (`placeFills`, `placeSteps`: only the first file fills),
// Reset Size's own reason (`resetSizeHelp`) and the section's note, each reason once (`placeNote`). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension DesignWorkspace {
    /// Why Reset Size has nothing to do.
    static let naturalShape = "The picture already has its own shape."

    /// Whether a Place… with Fill `fill` fills the selection: Fill is on and one unlocked frame or rectangle is selected.
    public func placeFills(fill: Bool) -> Bool {
        guard fill, let node = selectedNode, node.kind.holdsPicture else { return false }
        return lockHelp(node.id) == nil
    }

    /// The place steps for `files`: the first fills the selection when `fills`, and the rest (or every file without
    /// it) are new layers at `at`, or fitted to the page with no point.
    public static func placeSteps(
        _ files: [(name: String, data: Data)], fills: Bool, at: Point?
    ) -> [(intent: PlaceIntent, fill: Bool)] {
        files.enumerated().map { index, file in
            let filling = fills && index == 0
            return (.place(name: file.name, data: file.data, at: filling ? nil : at), filling)
        }
    }

    /// Why Reset Size can't run on the selected picture: it already has its own shape, or the command's reason.
    public var resetSizeHelp: String? {
        if let selection = placedSelection,
           PlaceRules.resetBox(selection.image, natural: selection.asset.natural) == selection.image.box {
            return Self.naturalShape
        }
        return placeActionHelp("place.reset-size")
    }

    /// The Picture section's note: Place…'s reason, then on a picture Replace…'s and Reset Size's, each named by
    /// its control and only when it differs from Place…'s; nil when everything can run.
    public var placeNote: String? {
        let place = placeActionHelp()
        var notes = place.map { [$0] } ?? []
        if placedSelection != nil {
            for (title, help) in [("Replace…", placeActionHelp("place.replace")), ("Reset Size", resetSizeHelp)] {
                if let help, help != place { notes.append("\(title): \(help)") }
            }
        }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }
}
