// PlacePanel.swift: the Place… file panel (placed-images PL-2 placeholder; PL-3 opens an `NSOpenPanel` limited to
// `formats` and reads the chosen files off the main actor). Until then it chooses nothing, and `unbuiltHelp` says why,
// so a Place… button disables itself with it instead of doing nothing.
import Foundation
import SuiteKernel

/// The Place… panel: the files the person chose, each as its name and bytes.
public enum PlacePanel {
    /// Why Place… can't choose a file yet; nil once PL-3 builds the panel.
    public static let unbuiltHelp: String? = "Choosing a file to place lands with placed-images PL-3."

    /// The chosen files of `formats`; none while the panel is a placeholder.
    @MainActor public static func choose(formats: Set<PlacedFormat>) async -> [(name: String, data: Data)] { [] }
}
