// PlacePanel.swift: the Place… file panel (placed-images PL-3): SuiteFilePanels' Open panel limited to `formats`, several files
// at once, read off the main actor through `PlaceReader` with the drop's format and size checks.
import AppKit
import Foundation
import SuiteKernel

/// The Place… panel: the files the person chose, each as its name and bytes.
public enum PlacePanel {
    /// Why Place… can't choose a file yet; nil now the panel is built.
    public static let unbuiltHelp: String? = nil

    /// The chosen files of `formats`; none when cancelled or when none could be read.
    @MainActor public static func choose(formats: Set<PlacedFormat>) async -> [(name: String, data: Data)] {
        let urls = SuiteFilePanels.chooseFiles(types: PlaceReader.types(for: formats), multiple: true, prompt: "Place")
        guard !urls.isEmpty else { return [] }
        return await PlaceReader.read(urls.map(PlaceItem.file), formats: formats).taken
    }
}
